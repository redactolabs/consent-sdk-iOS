import SwiftUI
import XCTest
@testable import RedactoConsentSDK

/// Legacy mode: a `baseUrl` that is the consent server URL (`…/consent`), as
/// earlier releases documented, or blank. Every request is the one the SDK
/// sent for the same values before it took the API host, except the branding:
/// it is read for the organisation, never by slug. `LastRelease` writes down
/// that routing.
final class EarlierReleaseCompatibilityTests: XCTestCase {
    private typealias H = RouteHarness

    private static let ledger = "https://ledger.test/consent-ledger"
    private static let consentServers = ["https://api.test/consent", "https://api.test/consent/"]
    private static let ledgers: [String?] = [nil, "   ", ledger, "\(ledger)/"]

    /// The routing before the API host, for one `baseUrl` and `ledgerBaseUrl`.
    private struct LastRelease {
        let baseUrl: String?
        let ledgerBaseUrl: String?

        /// Trimmed, blank as unset, one trailing `/` dropped.
        private static func configured(_ value: String?) -> String? {
            guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            if trimmed.hasSuffix("/") { trimmed.removeLast() }
            return trimmed.isEmpty ? nil : trimmed
        }

        var consent: String? { Self.configured(baseUrl) }
        var ledger: String? { Self.configured(ledgerBaseUrl) }
        var ledgerOrConsent: String? { ledger ?? consent }
        /// The Privacy Center appends its paths to `baseUrl` as passed.
        var privacyCenterConsent: String { baseUrl ?? "" }
        var dsar: String { "\(privacyCenterConsent)/organisations/\(H.org)/workspaces/\(H.ws)/dsar/privacy-center" }
        /// The public Privacy Center routes drop trailing `/`.
        var privacyCenterPublic: String {
            var base = privacyCenterConsent
            while base.hasSuffix("/") { base.removeLast() }
            return "\(base)/public/organisations/\(H.org)"
        }
        /// The user service on the consent server URL's origin.
        var userServer: String {
            let trimmed = privacyCenterConsent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let scheme = trimmed.range(of: "://") else { return "https://api.redacto.io/user/api/0" }
            let end = trimmed[scheme.upperBound...].firstIndex { "/?#".contains($0) } ?? trimmed.endIndex
            return "\(trimmed[..<end])/user/api/0"
        }

        func publicScope(_ root: String?, org: String = H.org, ws: String = H.ws) -> String? {
            root.map { "\($0)/public/organisations/\(org)/workspaces/\(ws)" }
        }

        func request(_ method: String, _ root: String?, _ path: String) -> [SentRequest] {
            publicScope(root).map { [SentRequest(method: method, url: $0 + path)] } ?? []
        }

        /// User consents and receipts: on the ledger when one is set, else the
        /// consent server's DSAR routes.
        func consents(_ method: String, _ path: String, query: String = "", legacyPath: String? = nil) -> [SentRequest] {
            if let scope = publicScope(ledger) {
                return [SentRequest(method: method, url: scope + path + query)]
            }
            return [SentRequest(method: method, url: dsar + (legacyPath ?? path) + query)]
        }
    }

    private struct Flow {
        let name: String
        let perform: (String?, String?) async -> Void
        let expected: (LastRelease) -> [SentRequest]
    }

    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    /// The notice APIs, which take an optional `baseUrl`.
    private var noticeFlows: [Flow] {
        let notice = H.notice
        let token = H.token
        let sandbox = H.sandbox
        return [
            Flow(name: "fetchConsentContent (JWT)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: token, baseUrl: base, ledgerBaseUrl: ledger))
            }, expected: { $0.request("GET", $0.ledgerOrConsent, "/notices/\(notice)?validate_against=all") }),
            Flow(name: "fetchConsentContent (magic link)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: token, baseUrl: base, ledgerBaseUrl: ledger, specificUuid: "app-1"))
            }, expected: { $0.request("GET", $0.consent, "/notices/\(notice)?specific_uuid=app-1&validate_against=all") }),
            Flow(name: "fetchConsentContent (sandbox)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: "", baseUrl: base, ledgerBaseUrl: ledger, sandbox: sandbox))
            }, expected: { $0.request("GET", $0.consent, "/notices/\(notice)?validate_against=all&org_user_id=ucic-1") }),
            Flow(name: "submitConsentEvent (JWT)", perform: { base, ledger in
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: token, baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, purposes: H.purposes(), declined: false))
            }, expected: { $0.request("POST", $0.ledgerOrConsent, "/submit-consent") }),
            Flow(name: "submitConsentEvent (sandbox)", perform: { base, ledger in
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: "", baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, purposes: H.purposes(), declined: false, sandbox: sandbox))
            }, expected: { $0.request("POST", $0.ledgerOrConsent, "/submit-consent") }),
            Flow(name: "submitConsentEvent (inline org/workspace)", perform: { base, ledger in
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: token, baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, purposes: H.purposes(), declined: false, orgUuid: "org-inline", workspaceUuid: "ws-inline"))
            }, expected: { last in
                last.publicScope(last.ledgerOrConsent, org: "org-inline", ws: "ws-inline").map { [SentRequest(method: "POST", url: "\($0)/submit-consent")] } ?? []
            }),
            Flow(name: "fetchTTSAudioUrls (JWT)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(accessToken: token, baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, language: "hi"))
            }, expected: { $0.request("GET", $0.ledgerOrConsent, "/notices/\(notice)/audio/hi") }),
            Flow(name: "fetchTTSAudioUrls (sandbox)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(accessToken: "", baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, language: "hi", sandbox: sandbox))
            }, expected: { $0.request("GET", $0.consent, "/notices/\(notice)/audio/hi?org_user_id=ucic-1") }),
            Flow(name: "submitGuardianInfo", perform: { base, _ in
                try? await ConsentAPI.submitGuardianInfo(.init(accessToken: token, baseUrl: base, guardianName: "G", guardianContact: "g@example.test", guardianRelationship: "parent"))
            }, expected: { $0.request("POST", $0.consent, "/guardian-info") }),
            Flow(name: "initiateGuardianVerification", perform: { base, _ in
                _ = try? await ConsentAPI.initiateGuardianVerification(.init(accessToken: token, baseUrl: base, guardianName: "G", guardianContact: "g@example.test", guardianRelationship: "parent"))
            }, expected: { $0.request("POST", $0.consent, "/guardian/initiate-verification") }),
            Flow(name: "verifyGuardianStatus", perform: { base, _ in
                _ = try? await ConsentAPI.verifyGuardianStatus(.init(accessToken: token, baseUrl: base, sessionToken: "session-1"))
            }, expected: { $0.request("POST", $0.consent, "/guardian/verify-status") }),
            Flow(name: "fetchNoticeConsentStatus", perform: { _, ledger in
                _ = await ConsentAPI.fetchNoticeConsentStatus(.init(accessToken: token, ledgerBaseUrl: ledger, organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice))
            }, expected: { $0.request("POST", $0.ledger, "/notices/\(notice)/check-consent") }),
            Flow(name: "fetchInlineConsentContent (with token)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, accessToken: token, baseUrl: base, ledgerBaseUrl: ledger))
            }, expected: { $0.request("GET", $0.ledgerOrConsent, "/notices/\(notice)") }),
            Flow(name: "fetchInlineConsentContent (with token, magic link)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, accessToken: token, baseUrl: base, specificUuid: "app-1", ledgerBaseUrl: ledger))
            }, expected: { $0.request("GET", $0.consent, "/notices/\(notice)?specific_uuid=app-1") }),
            Flow(name: "fetchInlineConsentContent (no token)", perform: { base, ledger in
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, baseUrl: base, ledgerBaseUrl: ledger))
            }, expected: { $0.request("GET", $0.consent, "/notices/get-notice/\(notice)") }),
            Flow(name: "AssistedAPI.fetchAssistedNotice", perform: { base, _ in
                _ = try? await AssistedAPI.fetchAssistedNotice(organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, baseUrl: base)
            }, expected: { $0.request("GET", $0.consent, "/notices/get-notice/\(notice)") }),
            Flow(name: "AssistedAPI.createOtp", perform: { base, _ in
                _ = try? await AssistedAPI.createOtp(organisationUuid: H.org, workspaceUuid: H.ws, to: "+919876543210", channel: "sms", baseUrl: base)
            }, expected: { $0.request("POST", $0.consent, "/otp/create") }),
            Flow(name: "AssistedAPI.verifyOtp", perform: { base, _ in
                _ = try? await AssistedAPI.verifyOtp(organisationUuid: H.org, workspaceUuid: H.ws, uuid: "otp-1", otp: "123456", baseUrl: base)
            }, expected: { $0.request("POST", $0.consent, "/otp/verify") }),
            Flow(name: "AssistedAPI.submitAssistedConsent", perform: { base, ledger in
                try? await AssistedAPI.submitAssistedConsent(accessToken: token, organisationUuid: H.org, workspaceUuid: H.ws, baseUrl: base, ledgerBaseUrl: ledger, noticeUuid: notice, purposes: H.purposes())
            }, expected: { $0.request("POST", $0.ledgerOrConsent, "/submit-consent") }),
            Flow(name: "AssistedAPI.fetchAssistedTTSAudioUrls", perform: { base, _ in
                _ = try? await AssistedAPI.fetchAssistedTTSAudioUrls(organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, language: "Hindi", baseUrl: base)
            }, expected: { $0.request("GET", $0.consent, "/notices/\(notice)/audio/Hindi") }),
        ]
    }

    /// The views' models, which take a `baseUrl` that is never nil.
    private var viewFlows: [Flow] {
        let notice = H.notice
        return [
            Flow(name: "RedactoNoticeConsent (JWT)", perform: { base, ledger in
                await Self.modalLoad(baseUrl: base ?? "", ledgerBaseUrl: ledger, sandbox: nil)
            }, expected: { last in
                last.request("GET", last.ledgerOrConsent, "/notices/\(notice)?validate_against=all")
                    + last.request("GET", last.ledgerOrConsent, "/notices/\(notice)/audio/English")
            }),
            Flow(name: "RedactoNoticeConsent (sandbox)", perform: { base, ledger in
                await Self.modalLoad(baseUrl: base ?? "", ledgerBaseUrl: ledger, sandbox: H.sandbox)
            }, expected: { last in
                last.request("GET", last.consent, "/notices/\(notice)?validate_against=all&org_user_id=ucic-1")
                    + last.request("GET", last.consent, "/notices/\(notice)/audio/English?org_user_id=ucic-1")
            }),
            Flow(name: "RedactoNoticeConsentInline (with token)", perform: { base, ledger in
                await H.inlineLoad(baseUrl: base ?? "", ledgerBaseUrl: ledger)
            }, expected: { last in
                last.request("GET", last.ledgerOrConsent, "/notices/\(notice)")
                    + last.request("POST", last.ledger, "/notices/\(notice)/check-consent")
            }),
            Flow(name: "RedactoNoticeAssisted", perform: { base, ledger in
                await Self.assistedFlow(baseUrl: base ?? "", ledgerBaseUrl: ledger)
            }, expected: { last in
                // The flow stops when the notice cannot be read.
                guard last.consent != nil else { return [] }
                return last.request("GET", last.consent, "/notices/get-notice/\(notice)")
                    + last.request("GET", last.consent, "/notices/\(notice)/audio/English")
                    + last.request("POST", last.consent, "/otp/create")
                    + last.request("POST", last.consent, "/otp/verify")
                    + last.request("POST", last.ledger, "/notices/\(notice)/check-consent")
                    + last.request("POST", last.ledgerOrConsent, "/submit-consent")
            }),
        ]
    }

    /// The Privacy Center, whose `baseUrl` is never nil.
    private var privacyCenterFlows: [Flow] {
        let notice = H.notice
        let api = { (base: String?, ledger: String?, sandbox: SandboxConfig?) in
            H.privacyCenter(baseUrl: base ?? "", ledgerBaseUrl: ledger, sandbox: sandbox)
        }
        return [
            Flow(name: "getFormData", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getFormData(contact: "user@example.test")
            }, expected: { [SentRequest(method: "POST", url: "\($0.dsar)/form/data")] }),
            Flow(name: "getUserConsents", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getUserConsents()
            }, expected: { $0.consents("GET", "/user-consents") }),
            Flow(name: "getUserConsents (sandbox)", perform: { base, ledger in
                _ = try? await api(base, ledger, H.sandbox).getUserConsents()
            }, expected: { $0.consents("GET", "/user-consents", query: "?org_user_id=ucic-1") }),
            Flow(name: "getGroupPurposes", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getGroupPurposes(productUuid: "prod-1")
            }, expected: { $0.consents("GET", "/user-consents/prod-1/purposes") }),
            Flow(name: "manageConsent", perform: { base, ledger in
                try? await api(base, ledger, nil).manageConsent(ManageConsentRequest(purposeUuid: "p-1", contact: "user@example.test", action: .revoke, noticeUuid: notice))
            }, expected: { last in
                last.ledger == nil
                    ? [SentRequest(method: "POST", url: "\(last.dsar)/manage-consent?status=revoke")]
                    : last.consents("POST", "/submit-consent")
            }),
            Flow(name: "getReceipts", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getReceipts()
            }, expected: { $0.consents("GET", "/receipts", query: "?skip=0&limit=10") }),
            Flow(name: "getReceiptPdf", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getReceiptPdf(receiptUuid: "rcpt-1")
            }, expected: { $0.consents("GET", "/receipts/rcpt-1/download", legacyPath: "/receipts/rcpt-1/pdf") }),
            Flow(name: "getActivities", perform: { base, ledger in
                _ = try? await api(base, ledger, nil).getActivities()
            }, expected: { [SentRequest(method: "GET", url: "\($0.dsar)/activities?offset=0&limit=15")] }),
            Flow(name: "getCaseHistory (sandbox)", perform: { base, ledger in
                _ = try? await api(base, ledger, H.sandbox).getCaseHistory()
            }, expected: { [SentRequest(method: "GET", url: "\($0.dsar)/cases?org_user_id=ucic-1")] }),
            Flow(name: "markNotificationRead", perform: { base, ledger in
                try? await api(base, ledger, nil).markNotificationRead(uuid: "ntf-1")
            }, expected: { [SentRequest(method: "PATCH", url: "\($0.dsar)/notifications/ntf-1/read")] }),
            Flow(name: "TokenStore OTP refresh", perform: { base, _ in
                _ = try? await H.tokenStore(baseUrl: base ?? "").forceRefresh()
            }, expected: { [SentRequest(method: "POST", url: "\($0.privacyCenterConsent)/public/organisations/\(H.org)/workspaces/\(H.ws)/otp/refresh")] }),
            Flow(name: "PrivacyCenterStore.loadBranding, the token's organisation over the slug", perform: { base, ledger in
                await H.store(baseUrl: base ?? "", ledgerBaseUrl: ledger).loadBranding()
            }, expected: { [SentRequest(method: "GET", url: "\($0.userServer)/public/org-branding/\(H.org)")] }),
            Flow(name: "PrivacyCenterStore.loadBranding, only a slug (ignored)", perform: { base, ledger in
                await H.store(baseUrl: base ?? "", ledgerBaseUrl: ledger, accessToken: "").loadBranding()
            }, expected: { _ in [] }),
            Flow(name: "PrivacyCenterStore.refreshSettings", perform: { base, ledger in
                await H.settingsLoad(baseUrl: base ?? "", ledgerBaseUrl: ledger)
            }, expected: { [SentRequest(method: "GET", url: "\($0.privacyCenterPublic)/privacy-center-settings/?lang=en")] }),
            Flow(name: "built-in sign-in, only a slug (ignored, no lookup)", perform: { base, ledger in
                await H.signInWithOnlyASlug(baseUrl: base ?? "", ledgerBaseUrl: ledger)
            }, expected: { _ in [] }),
            Flow(name: "built-in sign-in code", perform: { base, ledger in
                await H.signInSendCode(baseUrl: base ?? "", ledgerBaseUrl: ledger)
            }, expected: { [SentRequest(method: "POST", url: "\($0.privacyCenterPublic)/workspaces/\(H.ws)/otp/create")] }),
        ]
    }

    private func check(_ flows: [Flow], bases: [String?]) async -> Int {
        var scenarios = 0
        for flow in flows {
            for base in bases {
                for ledger in Self.ledgers {
                    let last = LastRelease(baseUrl: base, ledgerBaseUrl: ledger)
                    let sent = await H.capture { await flow.perform(base, ledger) }
                    XCTAssertEqual(
                        sent,
                        flow.expected(last).sorted(),
                        "\(flow.name), baseUrl \(String(describing: base)), ledgerBaseUrl \(String(describing: ledger))"
                    )
                    scenarios += 1
                }
            }
        }
        return scenarios
    }

    func testTheNoticeApisSendWhatTheLastReleaseSent() async {
        let scenarios = await check(noticeFlows, bases: [nil, "", "  "] + Self.consentServers)
        XCTAssertEqual(scenarios, noticeFlows.count * 5 * Self.ledgers.count)
    }

    func testTheViewModelsSendWhatTheLastReleaseSent() async {
        let scenarios = await check(viewFlows, bases: [""] + Self.consentServers)
        XCTAssertEqual(scenarios, viewFlows.count * 3 * Self.ledgers.count)
    }

    func testThePrivacyCenterSendsWhatTheLastReleaseSent() async {
        let scenarios = await check(privacyCenterFlows, bases: Self.consentServers)
        XCTAssertEqual(scenarios, privacyCenterFlows.count * 2 * Self.ledgers.count)
    }

    @MainActor
    func testThePrivacyCenterStoreKeepsTheValuesAsTheLastReleaseDid() {
        for base in Self.consentServers {
            for ledger in Self.ledgers {
                let store = H.store(baseUrl: base, ledgerBaseUrl: ledger)
                XCTAssertEqual(store.baseUrl, base)
                XCTAssertEqual(store.ledgerBaseUrl, LastRelease(baseUrl: base, ledgerBaseUrl: ledger).ledger)
            }
        }
    }

    @MainActor
    func testTheViewsTakeBothValuesAsTheyDid() {
        let views: [any View] = [
            RedactoNoticeConsent(noticeId: H.notice, baseUrl: Self.consentServers[0], ledgerBaseUrl: Self.ledger, onAccept: {}, onDecline: {}),
            RedactoNoticeConsentInline(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: H.notice, baseUrl: Self.consentServers[0], ledgerBaseUrl: Self.ledger),
            RedactoNoticeAssisted(organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: H.notice, baseUrl: Self.consentServers[0], ledgerBaseUrl: Self.ledger),
            RedactoPrivacyCenter(baseUrl: Self.consentServers[0], slug: "acme", onError: { _ in false }, ledgerBaseUrl: Self.ledger),
        ]
        XCTAssertEqual(views.count, 4)
    }

    // MARK: - View model drivers

    @MainActor
    private static func modalLoad(baseUrl: String, ledgerBaseUrl: String?, sandbox: SandboxConfig?) async {
        let viewModel = ConsentNoticeViewModel(
            noticeId: H.notice,
            accessToken: sandbox == nil ? H.token : "",
            refreshToken: "",
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            sandbox: sandbox,
            onAccept: {},
            onDecline: {}
        )
        await viewModel.fetchContent().value
        if viewModel.content != nil {
            await waitUntil { TransportStubProtocol.requests.contains { $0.url.path.contains("/audio/") } }
        }
    }

    @MainActor
    private static func assistedFlow(baseUrl: String, ledgerBaseUrl: String?) async {
        let viewModel = AssistedNoticeViewModel(
            organisationUuid: H.org,
            workspaceUuid: H.ws,
            noticeUuid: H.notice,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl
        )
        await viewModel.load().value
        guard viewModel.activeConfig != nil else { return }
        await viewModel.narrationTask?.value
        viewModel.acceptAll()
        viewModel.setMobile("9876543210")
        await viewModel.sendOtp()?.value
        viewModel.setOtpCode("123456")
        await viewModel.confirmOtp()?.value
    }
}
