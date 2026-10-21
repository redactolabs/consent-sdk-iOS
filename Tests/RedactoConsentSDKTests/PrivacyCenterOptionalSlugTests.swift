import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterOptionalSlugTests: XCTestCase {
    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    @MainActor
    func testThePrivacyCenterTakesNoSlug() async {
        let sent = await RouteHarness.capture {
            let center = RedactoPrivacyCenter(baseUrl: RouteHarness.host, accessToken: PCFixtures.liveToken, onError: { _ in false })
            _ = center
            await RouteHarness.store(slug: "").loadBranding()
        }

        XCTAssertEqual(sent, [
            SentRequest(method: "GET", url: "\(RouteHarness.host)/user/api/0/public/org-branding/\(RouteHarness.org)"),
        ])
    }

    @MainActor
    func testNoBrandingIsRequestedWhenNothingNamesTheOrganisation() async {
        let sent = await RouteHarness.capture {
            await RouteHarness.store(slug: "", accessToken: "").loadBranding()
        }

        XCTAssertEqual(sent, [])
    }

    @MainActor
    func testASlugBesideATokenReadsTheBrandingByOrganisationOnly() async {
        let sent = await RouteHarness.capture {
            await RouteHarness.store(slug: "acme").loadBranding()
        }

        XCTAssertEqual(sent, [
            SentRequest(method: "GET", url: "\(RouteHarness.host)/user/api/0/public/org-branding/\(RouteHarness.org)"),
        ])
    }

    @MainActor
    func testASlugAloneSendsNoRequest() async {
        let sent = await RouteHarness.capture {
            await RouteHarness.store(slug: "acme", accessToken: "").loadBranding()
        }

        XCTAssertEqual(sent, [])
    }

    @MainActor
    func testTheBrandingLoadsOnceALateTokenNamesTheOrganisation() async {
        let sent = await RouteHarness.capture {
            let store = RouteHarness.store(slug: "acme", accessToken: "")
            await store.loadBranding()
            await store.syncHostTokens(accessToken: PCFixtures.liveToken, refreshToken: "refresh-1")
            await store.awaitBranding()
            await store.awaitSettings()
        }

        XCTAssertEqual(sent, [
            SentRequest(method: "GET", url: "\(RouteHarness.host)/consent/public/organisations/\(RouteHarness.org)/privacy-center-settings/?lang=en"),
            SentRequest(method: "GET", url: "\(RouteHarness.host)/user/api/0/public/org-branding/\(RouteHarness.org)"),
        ])
    }

    @MainActor
    func testATokenForAnotherOrganisationReplacesTheBranding() async {
        var store: PrivacyCenterStore?
        var firstBrand: String?
        let otherOrganisation = PCFixtures.jwt([
            "organisation_uuid": "org-2", "workspace_uuid": "ws-2", "email": PCFixtures.contact,
        ])
        let sent = await RouteHarness.capture {
            PCMockURLProtocol.route(
                pathSuffix: "/public/org-branding/\(RouteHarness.org)",
                .json(200, ["brand_name": "Acme Bank", "hide_platform_branding": false])
            )
            PCMockURLProtocol.route(pathSuffix: "/public/org-branding/org-2", .json(500, ["detail": "down"]))
            let centre = RouteHarness.store(slug: "")
            store = centre
            await centre.loadBranding()
            firstBrand = centre.branding?.brandName
            await centre.syncHostTokens(accessToken: otherOrganisation, refreshToken: "refresh-2")
            await centre.awaitBranding()
            await centre.awaitSettings()
        }

        XCTAssertEqual(firstBrand, "Acme Bank")
        XCTAssertTrue(sent.contains(SentRequest(method: "GET", url: "\(RouteHarness.host)/user/api/0/public/org-branding/org-2")))
        XCTAssertNil(store?.branding)
    }

    @MainActor
    func testTheNameComesFromTheTokenTheSignInIssues() async {
        var name: String?
        let issued = PCFixtures.jwt([
            "organisation_uuid": RouteHarness.org, "workspace_uuid": RouteHarness.ws,
            "organisation_name": "Acme Bank", "email": PCFixtures.contact,
        ])
        _ = await RouteHarness.capture {
            PCMockURLProtocol.route(
                pathSuffix: "/public/org-branding/\(RouteHarness.org)",
                .json(200, ["hide_platform_branding": false])
            )
            let signIn = RouteHarness.store(
                slug: "", accessToken: "", builtInSignIn: true,
                organisationUuid: RouteHarness.org, workspaceUuid: RouteHarness.ws
            )
            await signIn.loadBranding()
            await signIn.completeSignIn(PrivacyCenterSignInTokens(accessToken: issued, refreshToken: "refresh-1"), contact: PCFixtures.contact)
            await signIn.loadBranding()
            name = signIn.displayOrgName
        }

        XCTAssertEqual(name, "Acme Bank")
    }

    @MainActor
    func testSyncingTokensDoesNotWaitForTheBranding() async {
        let otherOrganisation = PCFixtures.jwt([
            "organisation_uuid": "org-2", "workspace_uuid": "ws-2", "email": PCFixtures.contact,
        ])
        _ = await RouteHarness.capture {
            let centre = RouteHarness.store(slug: "")
            PCMockURLProtocol.hold(pathSuffix: "/public/org-branding/org-2")
            let synced = expectation(description: "syncHostTokens returned while the branding was held")
            Task { @MainActor in
                await centre.syncHostTokens(accessToken: otherOrganisation, refreshToken: "refresh-2")
                synced.fulfill()
            }
            await fulfillment(of: [synced], timeout: 2)
            PCMockURLProtocol.releaseHeld()
            await centre.awaitBranding()
            await centre.awaitSettings()
        }
    }

    @MainActor
    func testTheBuiltInSignInNeverLooksTheSlugUp() async {
        var store: PrivacyCenterStore?
        let sent = await RouteHarness.capture {
            let signIn = RouteHarness.store(slug: "acme", accessToken: "", builtInSignIn: true)
            store = signIn
            await signIn.refreshSettings()
            await signIn.loadBranding()
        }

        XCTAssertEqual(sent, [])
        XCTAssertNil(store?.organisationUuid)
        XCTAssertNil(store?.workspaceUuid)
        XCTAssertEqual(store?.organisationLookupFailed, true)
    }

    @MainActor
    func testTheBuiltInSignInWorksFromTheOrganisationAndWorkspace() async {
        var store: PrivacyCenterStore?
        let sent = await RouteHarness.capture {
            let signIn = RouteHarness.store(
                slug: "acme", accessToken: "", builtInSignIn: true,
                organisationUuid: RouteHarness.org, workspaceUuid: RouteHarness.ws
            )
            store = signIn
            await signIn.refreshSettings()
            let viewModel = PCSignInViewModel(store: signIn)
            viewModel.contactInput = "jane@example.com"
            await viewModel.submitContact()
        }

        XCTAssertEqual(store?.organisationLookupFailed, false)
        XCTAssertEqual(sent, [
            SentRequest(method: "GET", url: "\(RouteHarness.host)/consent/public/organisations/\(RouteHarness.org)/privacy-center-settings/?lang=en"),
            SentRequest(method: "POST", url: "\(RouteHarness.host)/consent/public/organisations/\(RouteHarness.org)/workspaces/\(RouteHarness.ws)/otp/create"),
        ])
    }

    @MainActor
    func testTheNameNeverComesFromTheSlug() async {
        let unnamed = PCFixtures.jwt([
            "organisation_uuid": PCFixtures.org, "workspace_uuid": PCFixtures.ws, "organisation_slug": "acme-co",
        ])
        let named = PCFixtures.jwt([
            "organisation_uuid": PCFixtures.org, "workspace_uuid": PCFixtures.ws,
            "organisation_slug": "acme-co", "organisation_name": "Acme Bank",
        ])
        var names: [String] = []
        _ = await RouteHarness.capture {
            for token in [unnamed, named] {
                let store = RouteHarness.store(slug: "acme-co", accessToken: token)
                await store.loadBranding()
                names.append(store.displayOrgName)
            }
        }

        XCTAssertEqual(names, ["", "Acme Bank"])
    }
}
