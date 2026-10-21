import XCTest
@testable import RedactoConsentSDK

/// The published settings, the lifecycle callbacks, the inactivity sign-out
/// and the built-in sign-in on the Privacy Center store (React
/// `PrivacyCenterSettingsContext`, `EventsContext`, `AuthContext` and
/// `RedactoPrivacyCenter.settings` tests).
final class PrivacyCenterSettingsStoreTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() async throws {
        try await super.setUp()
        PCMockURLProtocol.reset()
        PCStrings.currentLanguage = "en"
        await PrivacyCenterSettingsCache.shared.clear()
    }

    override func tearDown() async throws {
        PCStrings.currentLanguage = "en"
        await PrivacyCenterSettingsCache.shared.clear()
        try await super.tearDown()
    }

    private final class Recorder {
        var ready: [Bool] = []
        var changes: [PrivacyCenterConsentChange] = []
        var submissions: [PrivacyCenterRequestSubmission] = []
        var signOuts: [PrivacyCenterSignOutReason] = []
        var dismissals = 0

        var handlers: PrivacyCenterEventHandlers {
            PrivacyCenterEventHandlers(
                onReady: { self.ready.append($0.signedIn) },
                onConsentChange: { self.changes.append($0) },
                onRequestSubmit: { self.submissions.append($0) },
                onSignOut: { self.signOuts.append($0.reason) }
            )
        }
    }

    private func publish(_ settings: [String: Any], version: Int = 2) {
        PCMockURLProtocol.route(
            pathSuffix: "/privacy-center-settings",
            .json(200, ["code": 200, "status": "success", "detail": [
                "settings": settings, "version": version, "published_at": "2026-10-01T10:00:00Z", "language": "en",
                "brand_contact": ["legal_entity_name": "Acme Holdings Ltd"],
            ] as [String: Any]])
        )
    }

    @MainActor
    private func makeStore(
        accessToken: String = F.liveToken,
        language: String = "en",
        initialPage: PrivacyCenterStore.InternalPage = .consentManager,
        onBack: PrivacyCenterStore.OnBackBehavior? = nil,
        settings: PrivacyCenterSettings? = nil,
        builtInSignIn: Bool = false,
        sandbox: SandboxConfig? = nil,
        organisationUuid: String? = nil,
        workspaceUuid: String? = nil,
        recorder: Recorder = Recorder(),
        onDismiss: (() -> Void)? = nil
    ) -> PrivacyCenterStore {
        PrivacyCenterStore(
            baseUrl: F.base,
            slug: "acme",
            accessToken: accessToken,
            refreshToken: accessToken.isEmpty ? "" : "refresh-1",
            themeMode: .light,
            initialPage: initialPage,
            onBack: onBack,
            onError: { _ in false },
            onDismiss: onDismiss,
            language: language,
            sandbox: sandbox,
            urlSession: F.session(),
            settings: settings,
            builtInSignIn: builtInSignIn,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            events: recorder.handlers
        )
    }

    // MARK: - Fetching

    @MainActor
    func testRendersWithTheDefaultsThenSwapsInThePublishedSettings() async throws {
        publish(["portal": ["welcome_enabled": true]])
        let store = makeStore()
        XCTAssertEqual(store.settings, .defaults)
        XCTAssertFalse(store.isSettingsCustomised)

        await store.refreshSettings()

        XCTAssertTrue(store.settings.portal.welcomeEnabled)
        XCTAssertTrue(store.isSettingsCustomised)
        XCTAssertEqual(store.brandContact.legalEntityName, "Acme Holdings Ltd")
        let read = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").first)
        XCTAssertEqual(read.urlWithoutQuery, "\(F.base)/public/organisations/\(F.org)/privacy-center-settings/")
        XCTAssertEqual(read.query("lang"), "en")
        XCTAssertNil(read.header("Authorization"))
    }

    @MainActor
    func testKeepsTheDefaultsWhenTheFetchFails() async {
        PCMockURLProtocol.route(pathSuffix: "/privacy-center-settings", .json(500, ["detail": "boom"]))
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertEqual(store.settings, .defaults)
        XCTAssertFalse(store.isSettingsCustomised)
    }

    @MainActor
    func testANeverPublishedPayloadIsNotCustomised() async {
        publish(["portal": ["welcome_enabled": false]], version: 0)
        PCMockURLProtocol.reset()
        PCMockURLProtocol.route(
            pathSuffix: "/privacy-center-settings",
            .json(200, ["settings": [String: Any](), "version": 0, "published_at": NSNull(), "language": "en"])
        )
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertFalse(store.isSettingsCustomised)
    }

    @MainActor
    func testRefetchesInTheNewLanguage() async {
        publish([:])
        let store = makeStore()

        store.chooseLanguage("ta")
        await store.settingsTask?.value

        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").last?.query("lang"), "ta")
    }

    @MainActor
    func testDropsAResponseForALanguageLeftBehind() async {
        publish(["portal": ["welcome_enabled": true]])
        PCMockURLProtocol.hold(pathSuffix: "/privacy-center-settings")
        let store = makeStore()
        let stale = Task { await store.refreshSettings() }
        await waitUntil { !PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").isEmpty }

        store.language = "ta"
        PCMockURLProtocol.releaseHeld()
        await stale.value

        XCTAssertEqual(store.settings, .defaults)
        XCTAssertFalse(store.isSettingsCustomised)
    }

    @MainActor
    func testStartsOverWithTheSettingsOfANewOrganisation() async {
        PCMockURLProtocol.route(pathSuffix: "org-2/privacy-center-settings", .json(404, ["detail": "Not Found"]))
        publish(["portal": ["welcome_enabled": true]])
        let store = makeStore()
        await store.refreshSettings()
        XCTAssertTrue(store.settings.portal.welcomeEnabled)

        let otherOrganisation = F.jwt(["organisation_uuid": "org-2", "workspace_uuid": "ws-2", "email": F.contact])
        await store.syncHostTokens(accessToken: otherOrganisation, refreshToken: "refresh-2")
        await store.awaitSettings()

        XCTAssertEqual(store.organisationUuid, "org-2")
        XCTAssertEqual(store.settings, .defaults)
        XCTAssertFalse(store.isSettingsCustomised)
        XCTAssertEqual(store.brandContact, .empty)
        XCTAssertNil(store.publishedSettingsOrganisation)
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "org-2/privacy-center-settings").count, 1)
    }

    @MainActor
    func testAddsNoRequestWithoutATokenOrTheBuiltInSignIn() async {
        let store = makeStore(accessToken: "", organisationUuid: F.org, workspaceUuid: F.ws)

        await store.refreshSettings()

        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").isEmpty)
    }

    @MainActor
    func testHostOverridesAloneCustomiseTheCentre() {
        let store = makeStore(settings: PrivacyCenterSettings(portal: .init(welcomeEnabled: true)))
        XCTAssertTrue(store.isSettingsCustomised)
        XCTAssertTrue(store.settings.portal.welcomeEnabled)
        XCTAssertFalse(makeStore(settings: PrivacyCenterSettings(theme: "glass")).isSettingsCustomised)
        XCTAssertTrue(makeStore(settings: PrivacyCenterSettings(theme: "glass")).theme.isGlass)
    }

    // MARK: - Branding

    @MainActor
    func testPaintsThePublishedColoursStyleAndRadius() async {
        publish(["branding": ["inherit_colors": false, "primary_color": "#112233", "accent_color": "#AA5500", "style": "glass", "corner_radius": 10]])
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertEqual(store.theme.primary, AppearanceColor.parse("#112233")!.color)
        XCTAssertEqual(store.theme.primaryText, AppearanceColor.parse("#FFFFFF")!.color)
        XCTAssertEqual(store.theme.link, AppearanceColor.parse("#AA5500")!.color)
        XCTAssertTrue(store.theme.isGlass)
        XCTAssertEqual(store.theme.buttonRadius, 10)
        XCTAssertEqual(store.theme.panelRadius, 14)
    }

    @MainActor
    func testTakesTheSettingsIdentityOnceItStopsInheriting() async {
        publish(["branding": ["inherit_identity": false, "display_name": "Acme Bank", "logo_url": "https://acme.test/logo.png"]])
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertEqual(store.displayOrgName, "Acme Bank")
        XCTAssertEqual(store.logoUrl, "https://acme.test/logo.png")
        XCTAssertNil(store.iconUrl)
    }

    // MARK: - Sections

    @MainActor
    func testFollowsThePublishedMenuAndRefusesADisabledSection() async {
        publish(["portal": ["sections": [
            ["key": "activity", "label": "History", "enabled": true],
            ["key": "consent-manager", "label": NSNull(), "enabled": false],
            ["key": "form", "label": NSNull(), "enabled": true],
            ["key": "receipts", "label": NSNull(), "enabled": true],
            ["key": "notifications", "label": NSNull(), "enabled": false],
        ]]])
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertEqual(store.tabSections.map(\.key), [.activity, .form, .receipts])
        XCTAssertEqual(store.sectionLabel(.activity), "History")
        XCTAssertEqual(store.visiblePage, .activity)
        XCTAssertEqual(store.homePage, .activity)
        store.navigate(to: .consentManager)
        XCTAssertEqual(store.visiblePage, .activity)
        store.navigate(to: .receipts)
        XCTAssertEqual(store.visiblePage, .receipts)
        store.openNotifications()
        XCTAssertFalse(store.isNotificationsOpen)
    }

    @MainActor
    func testKeepsEveryPageReachableByDefault() {
        let store = makeStore(initialPage: .receipts)
        XCTAssertEqual(store.visiblePage, .receipts)
        XCTAssertEqual(store.tabSections.map(\.key), [.consentManager, .form, .activity, .receipts])
        store.openNotifications()
        XCTAssertTrue(store.isNotificationsOpen)
    }

    // MARK: - Languages

    @MainActor
    func testMovesTheVisitorOntoAnEnabledLanguage() async {
        publish(["languages": ["enabled": ["en", "ta"], "default": "ta", "auto_detect": false]])
        let store = makeStore(language: "hi")

        await store.refreshSettings()
        await store.settingsTask?.value

        XCTAssertEqual(store.language, "ta")
        XCTAssertEqual(store.languageOptions.map(\.code), ["en", "ta"])
        XCTAssertTrue(store.showsLanguageSwitcher)
    }

    private var hostLanguages: PrivacyCenterSettings {
        PrivacyCenterSettings(languages: .init(enabled: ["en", "ta"], defaultLanguage: "ta", autoDetect: false))
    }

    @MainActor
    func testAppliesTheHostsLanguagesBeforeAnythingIsPublished() {
        let store = makeStore(language: "hi", settings: hostLanguages)

        XCTAssertEqual(store.language, "ta")
        XCTAssertEqual(PCStrings.currentLanguage, "ta")
        XCTAssertEqual(store.languageOptions.map(\.code), ["en", "ta"])
    }

    @MainActor
    func testAsksInTheHostsLanguageAndKeepsItOncePublished() async {
        publish(["languages": ["enabled": ["en", "hi", "ta"], "default": "hi"]])
        let store = makeStore(language: "hi", settings: hostLanguages)

        await store.start()

        XCTAssertEqual(store.language, "ta")
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").map { $0.query("lang") }, ["ta"])
    }

    @MainActor
    func testKeepsTheHostsLanguagesWhenTheFetchFails() async {
        PCMockURLProtocol.route(pathSuffix: "/privacy-center-settings", .json(404, ["detail": "Not Found"]))
        let store = makeStore(language: "hi", settings: hostLanguages)

        await store.start()

        XCTAssertEqual(store.language, "ta")
        XCTAssertTrue(store.isSettingsCustomised)
    }

    @MainActor
    func testNeverUndoesALaterSwitchOnTheNextFetch() async {
        publish([:])
        let store = makeStore(language: "hi", settings: hostLanguages)

        store.setLanguage("en")
        await store.awaitSettings()

        XCTAssertEqual(store.language, "en")
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/privacy-center-settings").last?.query("lang"), "en")
    }

    @MainActor
    func testLeavesTheLanguageAloneWhileNothingIsPublished() async {
        let store = makeStore(language: "hi")

        await store.refreshSettings()

        XCTAssertEqual(store.language, "hi")
    }

    @MainActor
    func testHidesTheSwitcherWithOneLanguage() async {
        publish(["languages": ["enabled": ["en"]]])
        let store = makeStore()

        await store.refreshSettings()

        XCTAssertFalse(store.showsLanguageSwitcher)
    }

    @MainActor
    func testRunsRightToLeftInUrduOnceSettingsArePublished() async {
        let unpublished = makeStore(language: "ur")
        XCTAssertFalse(unpublished.isRightToLeft)

        publish([:])
        let store = makeStore(language: "ur")
        await store.refreshSettings()

        XCTAssertTrue(store.isRightToLeft)
    }

    // MARK: - Copy

    @MainActor
    func testFillsTheWelcomeAndWithdrawCopy() async {
        publish(["portal": ["welcome_enabled": true, "withdraw_warning": "Withdrawing ends {brand} offers."]])
        let store = makeStore(accessToken: F.jwt(["organisation_uuid": F.org, "workspace_uuid": F.ws, "email": F.contact, "organisation_name": "Acme"]))

        await store.loadBranding()
        await store.refreshSettings()

        XCTAssertEqual(store.copy(store.settings.portal.welcomeTitle), "Welcome to the Acme Privacy Center")
        XCTAssertEqual(store.organisationWithdrawWarning, "Withdrawing ends Acme offers.")
        XCTAssertEqual(store.placeholderContext.legal, "Acme Holdings Ltd")
    }

    // MARK: - Lifecycle callbacks

    @MainActor
    func testReportsReadyOnceForASignedInVisitor() async {
        let recorder = Recorder()
        let store = makeStore(recorder: recorder)

        await store.start()
        await store.start()

        XCTAssertEqual(recorder.ready, [true])
    }

    @MainActor
    func testReportsReadyOnlyOnceTheHostHandsOverAToken() async {
        let recorder = Recorder()
        let store = makeStore(accessToken: "", organisationUuid: F.org, workspaceUuid: F.ws, recorder: recorder)

        await store.start()
        XCTAssertEqual(recorder.ready, [])

        await store.syncHostTokens(accessToken: F.liveToken, refreshToken: "refresh-1")

        XCTAssertTrue(store.hasSession)
        XCTAssertEqual(recorder.ready, [true])
    }

    @MainActor
    func testReportsTheSignOutTheHostExitPerforms() {
        let recorder = Recorder()
        var dismissed = 0
        let store = makeStore(onBack: .signout, recorder: recorder, onDismiss: { dismissed += 1 })

        store.performExitAction()

        XCTAssertEqual(recorder.signOuts, [.user])
        XCTAssertEqual(dismissed, 1)
    }

    @MainActor
    func testReportsAnExpiredSessionOnce() {
        let recorder = Recorder()
        let store = makeStore(recorder: recorder)

        store.markSessionExpired()
        store.markSessionExpired()

        XCTAssertEqual(recorder.signOuts, [.sessionExpired])
        XCTAssertTrue(store.isSessionExpired)
    }

    @MainActor
    func testHandlersAlwaysSeeTheLatestOnesPassed() {
        let first = Recorder()
        let second = Recorder()
        let store = makeStore(recorder: first)

        store.events.handlers = second.handlers
        store.markSessionExpired()

        XCTAssertTrue(first.signOuts.isEmpty)
        XCTAssertEqual(second.signOuts, [.sessionExpired])
    }

    @MainActor
    func testReportsAConsentTheVisitorWithdrew() async {
        PCMockURLProtocol.route(pathSuffix: "/manage-consent", .json(200, ["status": "success"]))
        let recorder = Recorder()
        let store = makeStore(recorder: recorder)
        let vm = ConsentManagerViewModel(store: store)

        await vm.performAction(purposeId: F.purpose, action: .revoke, dataElementUuids: ["e-1"], productUuid: F.productA, nominatorUuid: F.nominator)

        XCTAssertEqual(recorder.changes, [PrivacyCenterConsentChange(
            action: .revoke, purposeUuid: F.purpose, productUuid: F.productA, dataElementUuids: ["e-1"], nominatorUuid: F.nominator
        )])
    }

    @MainActor
    func testStaysQuietWhenTheChangeFailed() async {
        PCMockURLProtocol.route(pathSuffix: "/manage-consent", .json(500, ["message": "down"]))
        let recorder = Recorder()
        let store = makeStore(recorder: recorder)
        let vm = ConsentManagerViewModel(store: store)

        await vm.performAction(purposeId: F.purpose, action: .revoke)

        XCTAssertTrue(recorder.changes.isEmpty)
    }

    // MARK: - Inactivity

    @MainActor
    func testSignsOutAfterTheConfiguredMinutesWithoutActivity() async {
        publish(["portal": ["session_timeout_minutes": 15]])
        let recorder = Recorder()
        let store = makeStore(recorder: recorder)
        var now = Date(timeIntervalSince1970: 1_000)
        store.now = { now }
        await store.refreshSettings()
        XCTAssertNotNil(store.inactivityClock)

        now = now.addingTimeInterval(10 * 60)
        store.recordActivity()
        now = now.addingTimeInterval(10 * 60)
        store.checkInactivity()
        XCTAssertFalse(store.isSessionExpired)

        now = now.addingTimeInterval(5 * 60)
        store.checkInactivity()

        XCTAssertTrue(store.isSessionExpired)
        XCTAssertEqual(recorder.signOuts, [.timeout])
        XCTAssertNil(store.inactivityClock)
    }

    @MainActor
    func testSignsOutOnReturnWhenTheAppSleptPastTheDeadline() async {
        publish(["portal": ["session_timeout_minutes": 15]])
        let store = makeStore()
        var now = Date(timeIntervalSince1970: 1_000)
        store.now = { now }
        await store.refreshSettings()

        now = now.addingTimeInterval(20 * 60)
        store.resumeFromBackground()

        XCTAssertTrue(store.isSessionExpired)
    }

    @MainActor
    func testTimesAgainOnceTheHostBringsTheSessionBack() async {
        let recorder = Recorder()
        let store = makeStore(settings: PrivacyCenterSettings(portal: .init(sessionTimeoutMinutes: 15)), recorder: recorder)
        var now = Date(timeIntervalSince1970: 1_000)
        store.now = { now }
        store.restartInactivityTimerIfNeeded()
        now = now.addingTimeInterval(15 * 60)
        store.checkInactivity()
        XCTAssertTrue(store.isSessionExpired)
        XCTAssertNil(store.inactivityClock)
        // The sign-out clears the old tokens on a task of its own: let it land.
        let deadline = Date().addingTimeInterval(3)
        while !(await store.tokenStore.currentRawToken()).isEmpty, Date() < deadline {
            await Task.yield()
        }

        await store.syncHostTokens(accessToken: F.refreshedToken, refreshToken: "refresh-2")

        XCTAssertFalse(store.isSessionExpired)
        XCTAssertNotNil(store.inactivityClock)
        now = now.addingTimeInterval(15 * 60)
        store.checkInactivity()
        XCTAssertTrue(store.isSessionExpired)
        XCTAssertEqual(recorder.signOuts, [.timeout, .timeout])
    }

    @MainActor
    func testATimeoutThatRoundsToZeroNeverSignsOut() async {
        publish(["portal": ["session_timeout_minutes": 0.4]])
        let store = makeStore()

        await store.refreshSettings()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(store.settings.portal.sessionTimeoutMinutes, 0)
        XCTAssertNil(store.inactivityClock)
        XCTAssertFalse(store.isSessionExpired)
    }

    @MainActor
    func testNeverTimesOutWithoutASettingOrInSandbox() async {
        let store = makeStore()
        await store.refreshSettings()
        XCTAssertNil(store.inactivityClock)

        publish(["portal": ["session_timeout_minutes": 15]])
        let sandboxed = makeStore(accessToken: "", sandbox: F.sandbox)
        await sandboxed.refreshSettings()
        XCTAssertNil(sandboxed.inactivityClock)
    }

    // MARK: - Built-in sign-in

    @MainActor
    func testKeepsTheOldBehaviourByDefaultWhenThereIsNoToken() {
        XCTAssertFalse(makeStore(accessToken: "").showsSignIn)
    }

    @MainActor
    func testShowsTheSignInWhenTheHostTurnsItOn() async {
        let recorder = Recorder()
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org, workspaceUuid: F.ws, recorder: recorder)
        XCTAssertTrue(store.showsSignIn)

        await store.start()

        XCTAssertEqual(recorder.ready, [false])
        XCTAssertFalse(makeStore(accessToken: "", builtInSignIn: true, sandbox: F.sandbox).showsSignIn)
    }

    @MainActor
    func testTheSignInTakesTheOrganisationFromTheProps() async {
        publish([:])
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org, workspaceUuid: F.ws)

        await store.refreshSettings()

        XCTAssertEqual(store.organisationUuid, F.org)
        XCTAssertEqual(store.workspaceUuid, F.ws)
        XCTAssertFalse(store.organisationLookupFailed)
        XCTAssertEqual(PCMockURLProtocol.requests.map(\.urlWithoutQuery), ["\(F.base)/public/organisations/\(F.org)/privacy-center-settings/"])
    }

    @MainActor
    func testSaysWhenNothingNamesTheOrganisationWithoutLookingTheSlugUp() async {
        let store = makeStore(accessToken: "", builtInSignIn: true)

        await store.refreshSettings()

        XCTAssertTrue(store.organisationLookupFailed)
        XCTAssertNil(store.organisationUuid)
        XCTAssertNil(store.workspaceUuid)
        XCTAssertEqual(PCMockURLProtocol.requests.count, 0)
    }

    @MainActor
    func testSaysWhenTheWorkspaceIsMissing() async {
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org)

        await store.refreshSettings()

        XCTAssertTrue(store.organisationLookupFailed)
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/organizations/exists").isEmpty)
    }

    @MainActor
    func testSignsInWithAOneTimeCodeAndOpensTheCentre() async {
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org, workspaceUuid: F.ws)
        let vm = PCSignInViewModel(store: store)
        var sent: [String] = []
        vm.sendCode = { _, _, contact, channel in
            sent.append("\(channel.rawValue):\(contact)")
            return "otp-1"
        }
        vm.verifyCode = { _, _, otpId, code in
            XCTAssertEqual(otpId, "otp-1")
            XCTAssertEqual(code, "123456")
            return PrivacyCenterSignInTokens(accessToken: F.liveToken, refreshToken: "refresh-9")
        }

        vm.contactInput = "98765 43210"
        await vm.submitContact()
        XCTAssertEqual(sent, ["sms:+919876543210"])
        XCTAssertEqual(vm.step, .otp)
        XCTAssertEqual(vm.resendIn, PCSignInViewModel.resendSeconds)
        XCTAssertEqual(vm.contactDisplay, "+91XXXXXX3210")

        vm.updateDigits(["1", "2", "3", "4", "5", "6"])
        await vm.verify()

        XCTAssertTrue(store.hasSession)
        XCTAssertFalse(store.showsSignIn)
        let refresh = await store.tokenStore.currentRefreshToken()
        XCTAssertEqual(refresh, "refresh-9")
        XCTAssertEqual(store.contact, F.contact)
    }

    @MainActor
    func testRefusesAContactThatCannotReceiveACode() async {
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org, workspaceUuid: F.ws)
        let vm = PCSignInViewModel(store: store)
        var calls = 0
        vm.sendCode = { _, _, _, _ in
            calls += 1
            return "otp-1"
        }

        vm.contactInput = "12345"
        await vm.submitContact()

        XCTAssertEqual(vm.error, "Enter a valid mobile number or email address.")
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(vm.step, .contact)
    }

    @MainActor
    func testSaysWhyACodeCouldNotBeSent() async {
        let store = makeStore(accessToken: "", builtInSignIn: true, organisationUuid: F.org, workspaceUuid: F.ws)
        let vm = PCSignInViewModel(store: store)
        vm.sendCode = { _, _, _, _ in throw PrivacyCenterSignInError(status: 429, code: "RATE_LIMIT_EXCEEDED") }

        vm.contactInput = "jane@example.com"
        await vm.submitContact()

        XCTAssertEqual(vm.error, "Too many code requests. Please wait a minute and try again.")
    }

    @MainActor
    func testOffersSigningInAgainOnlyWhenTheHostGaveNoWayOut() {
        XCTAssertTrue(makeStore(builtInSignIn: true).canSignInAgain)
        XCTAssertFalse(makeStore(onBack: .back, builtInSignIn: true).canSignInAgain)
        XCTAssertFalse(makeStore().canSignInAgain)
    }

    @MainActor
    func testSigningInAgainGoesBackToTheSignIn() {
        let store = makeStore(builtInSignIn: true)
        store.markSessionExpired()

        store.restartSignIn()

        XCTAssertTrue(store.showsSignIn)
        XCTAssertFalse(store.isSessionExpired)
    }

    // MARK: - Request form

    @MainActor
    func testTheFormFollowsThePublishedRequestTypes() async {
        publish(["portal": ["request_types": [
            ["key": "grievance", "label": "Complaint", "enabled": true],
            ["key": "access", "label": NSNull(), "enabled": true],
            ["key": "correction", "label": NSNull(), "enabled": false],
            ["key": "erasure", "label": NSNull(), "enabled": false],
            ["key": "nomination", "label": NSNull(), "enabled": false],
        ], "grievance_categories": ["data_breach"]]])
        let store = makeStore()
        await store.refreshSettings()
        let vm = DSRFormViewModel(store: store)

        XCTAssertEqual(vm.requestTypeOptions.map(\.type), [.grievance, .access])
        XCTAssertEqual(vm.requestTypeOptions.first?.label, "Complaint")

        vm.requestType = .erasure
        vm.dropUnofferedRequestType()
        XCTAssertNil(vm.requestType)
    }

    @MainActor
    func testTheFormKeepsTheBuiltInOrderWhenNothingIsPublished() {
        let vm = DSRFormViewModel(store: makeStore())
        XCTAssertEqual(vm.requestTypeOptions.map(\.type), RequestType.allCases)
    }
}
