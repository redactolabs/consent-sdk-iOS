import XCTest
@testable import RedactoConsentSDK

/// One request the SDK sent: what the route contract compares.
struct SentRequest: Equatable, Comparable, CustomStringConvertible {
    let method: String
    let url: String

    var description: String { "\(method) \(url)" }

    static func < (lhs: SentRequest, rhs: SentRequest) -> Bool {
        (lhs.url, lhs.method) < (rhs.url, rhs.method)
    }
}

/// Runs SDK calls against stubbed transports and returns every request they
/// sent, sorted. The notice APIs go through `URLSession.shared`
/// (`TransportStubProtocol`); the Privacy Center through its own session
/// (`PCMockURLProtocol`).
enum RouteHarness {
    static let host = "https://api.test"
    /// A ledger passed alongside the API host, which the SDK ignores.
    static let ignoredLedger = "http://localhost:8090/consent-ledger"
    static let org = PCFixtures.org
    static let ws = PCFixtures.ws
    static let notice = "ntc-1"
    static let token = TransportFixtures.token(org: org, workspace: ws)
    /// The identity is a UCIC alone, so a sandbox URL carries one query item.
    static let sandbox = SandboxConfig(token: "sandbox-token", ucic: "ucic-1", organisationUuid: org, workspaceUuid: ws)

    static func purposes() -> [Purpose] {
        [TransportFixtures.purpose()]
    }

    static func stub(_ request: TransportStubRequest) -> TransportStubResponse {
        let url = request.url.absoluteString
        if url.contains("/otp/create") {
            return .text(201, #"{"code":201,"status":"success","detail":{"uuid":"otp-1","to":"+919876543210","channel":"sms","expire_at":"2026-06-24T09:55:34Z","success":true}}"#)
        }
        if url.contains("/otp/verify") {
            return .text(200, #"{"code":200,"status":"success","detail":{"access_token":"access-token-1","refresh_token":"refresh-1","success":true}}"#)
        }
        if url.contains("/check-consent") {
            return .json(200, TransportFixtures.consentStatusJSON(consented: false, allMandatoryActive: false))
        }
        if url.contains("/submit-consent") || url.contains("/audio/") {
            return .empty(404)
        }
        return .json(200, TransportFixtures.noticeJSON())
    }

    static func capture(_ perform: () async -> Void) async -> [SentRequest] {
        await APICache.shared.clear()
        await PrivacyCenterSettingsCache.shared.clear()
        IdempotencyKeys.shared.reset()
        PCMockURLProtocol.reset()
        TransportStubProtocol.install(stub)
        await perform()
        let sent = (TransportStubProtocol.requests.map { ($0.method, $0.url) }
            + PCMockURLProtocol.requests.map { ($0.method, $0.url) })
            .map { SentRequest(method: $0.0, url: $0.1.absoluteString) }
        TransportStubProtocol.uninstall()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
        await APICache.shared.clear()
        return sent.sorted()
    }

    static func tokenStore(baseUrl: String, sandbox: SandboxConfig? = nil) -> TokenStore {
        TokenStore(
            baseUrl: baseUrl,
            accessToken: sandbox == nil ? PCFixtures.liveToken : "",
            refreshToken: "refresh-1",
            onError: { _ in false },
            sandbox: sandbox,
            urlSession: PCFixtures.session()
        )
    }

    static func privacyCenter(
        baseUrl: String = host,
        ledgerBaseUrl: String? = nil,
        sandbox: SandboxConfig? = nil
    ) -> PrivacyCenterAPI {
        PrivacyCenterAPI(
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            tokenStore: tokenStore(baseUrl: baseUrl, sandbox: sandbox),
            urlSession: PCFixtures.session()
        )
    }

    @MainActor
    static func store(
        baseUrl: String = host,
        ledgerBaseUrl: String? = nil,
        slug: String = "acme",
        accessToken: String = PCFixtures.liveToken,
        builtInSignIn: Bool = false,
        organisationUuid: String? = nil,
        workspaceUuid: String? = nil
    ) -> PrivacyCenterStore {
        PrivacyCenterStore(
            baseUrl: baseUrl,
            slug: slug,
            accessToken: accessToken,
            refreshToken: accessToken.isEmpty ? "" : "refresh-1",
            themeMode: .light,
            initialPage: .consentManager,
            onBack: nil,
            onError: { _ in false },
            urlSession: PCFixtures.session(),
            ledgerBaseUrl: ledgerBaseUrl,
            builtInSignIn: builtInSignIn,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid
        )
    }

    /// The published settings for the organisation in the token.
    @MainActor
    static func settingsLoad(baseUrl: String = host, ledgerBaseUrl: String? = nil) async {
        await store(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl).refreshSettings()
    }

    /// The built-in sign-in with no token and only a slug, which is ignored.
    @MainActor
    static func signInWithOnlyASlug(baseUrl: String = host, ledgerBaseUrl: String? = nil) async {
        await store(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl, accessToken: "", builtInSignIn: true).refreshSettings()
    }

    /// The built-in sign-in sending a code to the organisation the props name.
    @MainActor
    static func signInSendCode(baseUrl: String = host, ledgerBaseUrl: String? = nil) async {
        let store = store(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl, accessToken: "", builtInSignIn: true, organisationUuid: org, workspaceUuid: ws)
        let viewModel = PCSignInViewModel(store: store)
        viewModel.contactInput = "jane@example.com"
        await viewModel.submitContact()
    }

    /// The inline notice's read and, with a token, its consent check.
    @MainActor
    static func inlineLoad(baseUrl: String = host, ledgerBaseUrl: String? = nil) async {
        let viewModel = ConsentInlineViewModel(
            orgUuid: org,
            workspaceUuid: ws,
            noticeUuid: notice,
            accessToken: token,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl
        )
        await viewModel.fetchNotice().value
        await waitUntil { !viewModel.isCheckingConsent }
    }

    /// The modal's read and, once the notice is shown, its audio.
    @MainActor
    static func modalLoad(baseUrl: String = host, ledgerBaseUrl: String? = nil, sandbox: SandboxConfig?) async {
        let viewModel = ConsentNoticeViewModel(
            noticeId: notice,
            accessToken: sandbox == nil ? token : "",
            refreshToken: "",
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            sandbox: sandbox,
            onAccept: {},
            onDecline: {}
        )
        await viewModel.fetchContent().value
        await waitUntil { TransportStubProtocol.requests.contains { $0.url.path.contains("/audio/") } }
    }

    /// The assisted flow from the notice to the consent write.
    @MainActor
    static func assistedFlow(baseUrl: String = host, ledgerBaseUrl: String? = nil) async {
        let viewModel = AssistedNoticeViewModel(
            organisationUuid: org,
            workspaceUuid: ws,
            noticeUuid: notice,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl
        )
        await viewModel.load().value
        await viewModel.narrationTask?.value
        viewModel.acceptAll()
        viewModel.setMobile("9876543210")
        await viewModel.sendOtp()?.value
        viewModel.setOtpCode("123456")
        await viewModel.confirmOtp()?.value
    }
}

/// Every request the SDK can make, with the exact method and URL it sends
/// for `baseUrl = "https://api.test"` (host mode). Set `ROUTE_DUMP` (through
/// xcodebuild, `TEST_RUNNER_ROUTE_DUMP`) to a file path to write the table as
/// JSON.
final class RouteContractTests: XCTestCase {
    private typealias H = RouteHarness

    private struct Route {
        let name: String
        let expected: [SentRequest]
        let perform: () async -> Void

        init(_ name: String, _ method: String, _ url: String, perform: @escaping () async -> Void) {
            self.name = name
            self.expected = [SentRequest(method: method, url: url)]
            self.perform = perform
        }

        init(_ name: String, expected: [SentRequest], perform: @escaping () async -> Void) {
            self.name = name
            self.expected = expected.sorted()
            self.perform = perform
        }
    }

    private struct DumpEntry {
        let name: String
        let method: String
        let url: String
    }

    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    private static func scope(_ root: String, org: String = H.org, ws: String = H.ws) -> String {
        "\(root)/public/organisations/\(org)/workspaces/\(ws)"
    }

    private static let ledger = scope("\(H.host)/consent-ledger")
    private static let consent = scope("\(H.host)/consent")
    private static let dsar = "\(H.host)/consent/organisations/\(H.org)/workspaces/\(H.ws)/dsar/privacy-center"

    /// Every route for the host. A `ledgerBaseUrl` passed is ignored, so the
    /// same requests are expected with or without it.
    private func hostRoutes(ledgerBaseUrl passed: String? = nil) -> [Route] {
        let ledger = Self.ledger
        let consent = Self.consent
        let dsar = Self.dsar
        let host = H.host
        let notice = H.notice
        let token = H.token
        return [
            // MARK: Modal notice (ConsentAPI)
            Route("ConsentAPI.fetchConsentContent (JWT session)", "GET", "\(ledger)/notices/\(notice)?validate_against=all") {
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: token, baseUrl: host, ledgerBaseUrl: passed))
            },
            Route("ConsentAPI.fetchConsentContent (magic link, specific_uuid)", "GET", "\(consent)/notices/\(notice)?specific_uuid=app-1&validate_against=all") {
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: token, baseUrl: host, ledgerBaseUrl: passed, specificUuid: "app-1"))
            },
            Route("ConsentAPI.fetchConsentContent (sandbox)", "GET", "\(consent)/notices/\(notice)?validate_against=all&org_user_id=ucic-1") {
                _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: notice, accessToken: "", baseUrl: host, ledgerBaseUrl: passed, sandbox: H.sandbox))
            },
            Route("ConsentAPI.submitConsentEvent (JWT session)", "POST", "\(ledger)/submit-consent") {
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: token, baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, purposes: H.purposes(), declined: false))
            },
            Route("ConsentAPI.submitConsentEvent (sandbox)", "POST", "\(ledger)/submit-consent") {
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: "", baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, purposes: H.purposes(), declined: false, sandbox: H.sandbox))
            },
            Route("ConsentAPI.fetchTTSAudioUrls (JWT session)", "GET", "\(ledger)/notices/\(notice)/audio/hi") {
                _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(accessToken: token, baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, language: "hi"))
            },
            Route("ConsentAPI.fetchTTSAudioUrls (sandbox, unified to the ledger)", "GET", "\(ledger)/notices/\(notice)/audio/hi?org_user_id=ucic-1") {
                _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(accessToken: "", baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, language: "hi", sandbox: H.sandbox))
            },
            Route("ConsentAPI.submitGuardianInfo", "POST", "\(consent)/guardian-info") {
                try? await ConsentAPI.submitGuardianInfo(.init(accessToken: token, baseUrl: host, guardianName: "G", guardianContact: "g@example.test", guardianRelationship: "parent"))
            },
            Route("ConsentAPI.initiateGuardianVerification", "POST", "\(consent)/guardian/initiate-verification") {
                _ = try? await ConsentAPI.initiateGuardianVerification(.init(accessToken: token, baseUrl: host, guardianName: "G", guardianContact: "g@example.test", guardianRelationship: "parent"))
            },
            Route("ConsentAPI.verifyGuardianStatus", "POST", "\(consent)/guardian/verify-status") {
                _ = try? await ConsentAPI.verifyGuardianStatus(.init(accessToken: token, baseUrl: host, sessionToken: "session-1"))
            },
            Route("RedactoNoticeConsent (JWT session): notice and audio", expected: [
                SentRequest(method: "GET", url: "\(ledger)/notices/\(notice)?validate_against=all"),
                SentRequest(method: "GET", url: "\(ledger)/notices/\(notice)/audio/English"),
            ]) {
                await H.modalLoad(ledgerBaseUrl: passed, sandbox: nil)
            },
            Route("RedactoNoticeConsent (sandbox): notice, and audio unified to the ledger", expected: [
                SentRequest(method: "GET", url: "\(consent)/notices/\(notice)?validate_against=all&org_user_id=ucic-1"),
                SentRequest(method: "GET", url: "\(ledger)/notices/\(notice)/audio/English?org_user_id=ucic-1"),
            ]) {
                await H.modalLoad(ledgerBaseUrl: passed, sandbox: H.sandbox)
            },

            // MARK: Inline notice
            Route("ConsentAPI.fetchInlineConsentContent (with token)", "GET", "\(ledger)/notices/\(notice)") {
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, accessToken: token, baseUrl: host, ledgerBaseUrl: passed))
            },
            Route("ConsentAPI.fetchInlineConsentContent (with token, magic link)", "GET", "\(consent)/notices/\(notice)?specific_uuid=app-1") {
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, accessToken: token, baseUrl: host, specificUuid: "app-1", ledgerBaseUrl: passed))
            },
            Route("ConsentAPI.fetchInlineConsentContent (no token, get-notice)", "GET", "\(consent)/notices/get-notice/\(notice)") {
                _ = try? await ConsentAPI.fetchInlineConsentContent(.init(orgUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, baseUrl: host, ledgerBaseUrl: passed))
            },
            Route("ConsentAPI.submitConsentEvent (inline org/workspace)", "POST", "\(Self.scope("\(host)/consent-ledger", org: "org-inline", ws: "ws-inline"))/submit-consent") {
                try? await ConsentAPI.submitConsentEvent(.init(accessToken: token, baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, purposes: H.purposes(), declined: false, orgUuid: "org-inline", workspaceUuid: "ws-inline"))
            },
            Route("RedactoNoticeConsentInline (with token): notice and consent check", expected: [
                SentRequest(method: "GET", url: "\(ledger)/notices/\(notice)"),
                SentRequest(method: "POST", url: "\(ledger)/notices/\(notice)/check-consent"),
            ]) {
                await H.inlineLoad(ledgerBaseUrl: passed)
            },

            // MARK: Assisted notice
            Route("AssistedAPI.fetchAssistedNotice", "GET", "\(consent)/notices/get-notice/\(notice)") {
                _ = try? await AssistedAPI.fetchAssistedNotice(organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, baseUrl: host)
            },
            Route("AssistedAPI.createOtp", "POST", "\(consent)/otp/create") {
                _ = try? await AssistedAPI.createOtp(organisationUuid: H.org, workspaceUuid: H.ws, to: "+919876543210", channel: "sms", baseUrl: host)
            },
            Route("AssistedAPI.verifyOtp", "POST", "\(consent)/otp/verify") {
                _ = try? await AssistedAPI.verifyOtp(organisationUuid: H.org, workspaceUuid: H.ws, uuid: "otp-1", otp: "123456", baseUrl: host)
            },
            Route("AssistedAPI.submitAssistedConsent", "POST", "\(ledger)/submit-consent") {
                try? await AssistedAPI.submitAssistedConsent(accessToken: token, organisationUuid: H.org, workspaceUuid: H.ws, baseUrl: host, ledgerBaseUrl: passed, noticeUuid: notice, purposes: H.purposes())
            },
            Route("AssistedAPI.fetchAssistedTTSAudioUrls", "GET", "\(consent)/notices/\(notice)/audio/Hindi") {
                _ = try? await AssistedAPI.fetchAssistedTTSAudioUrls(organisationUuid: H.org, workspaceUuid: H.ws, noticeUuid: notice, language: "Hindi", baseUrl: host)
            },
            Route("RedactoNoticeAssisted: notice, audio, OTP, consent check and write", expected: [
                SentRequest(method: "GET", url: "\(consent)/notices/get-notice/\(notice)"),
                SentRequest(method: "GET", url: "\(consent)/notices/\(notice)/audio/English"),
                SentRequest(method: "POST", url: "\(consent)/otp/create"),
                SentRequest(method: "POST", url: "\(consent)/otp/verify"),
                SentRequest(method: "POST", url: "\(ledger)/notices/\(notice)/check-consent"),
                SentRequest(method: "POST", url: "\(ledger)/submit-consent"),
            ]) {
                await H.assistedFlow(ledgerBaseUrl: passed)
            },

            // MARK: Privacy Center
            Route("PrivacyCenterAPI.getFormData", "POST", "\(dsar)/form/data") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getFormData(contact: "user@example.test")
            },
            Route("PrivacyCenterAPI.createCase", "POST", "\(dsar)/case") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).createCase(UserDataRequest(uuid: "form-1", name: "User", contact: "user@example.test", requestType: .access))
            },
            Route("PrivacyCenterAPI.getUserConsents", "GET", "\(ledger)/user-consents") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getUserConsents()
            },
            Route("PrivacyCenterAPI.getUserConsents (sandbox)", "GET", "\(ledger)/user-consents?org_user_id=ucic-1") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed, sandbox: H.sandbox).getUserConsents()
            },
            Route("PrivacyCenterAPI.getGroupPurposes", "GET", "\(ledger)/user-consents/prod-1/purposes") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getGroupPurposes(productUuid: "prod-1")
            },
            Route("PrivacyCenterAPI.listIdentities", "GET", "\(dsar)/identities") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).listIdentities()
            },
            Route("PrivacyCenterAPI.selectPrincipal", "POST", "\(dsar)/identities/select") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).selectPrincipal(uuid: "principal-1")
            },
            Route("PrivacyCenterAPI.manageConsent", "POST", "\(ledger)/submit-consent") {
                try? await H.privacyCenter(ledgerBaseUrl: passed).manageConsent(ManageConsentRequest(purposeUuid: "p-1", contact: "user@example.test", action: .revoke, noticeUuid: notice))
            },
            Route("PrivacyCenterAPI.manageConsent (sandbox)", "POST", "\(ledger)/submit-consent") {
                try? await H.privacyCenter(ledgerBaseUrl: passed, sandbox: H.sandbox).manageConsent(ManageConsentRequest(purposeUuid: "p-1", contact: "user@example.test", action: .revoke, noticeUuid: notice))
            },
            Route("PrivacyCenterAPI.getActivities", "GET", "\(dsar)/activities?offset=0&limit=15") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getActivities()
            },
            Route("PrivacyCenterAPI.getReceipts", "GET", "\(ledger)/receipts?skip=0&limit=10") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getReceipts()
            },
            Route("PrivacyCenterAPI.getReceiptPdf", "GET", "\(ledger)/receipts/rcpt-1/download") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getReceiptPdf(receiptUuid: "rcpt-1")
            },
            Route("PrivacyCenterAPI.getCaseHistory", "GET", "\(dsar)/cases") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getCaseHistory()
            },
            Route("PrivacyCenterAPI.getCaseHistory (sandbox)", "GET", "\(dsar)/cases?org_user_id=ucic-1") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed, sandbox: H.sandbox).getCaseHistory()
            },
            Route("PrivacyCenterAPI.getCaseMessages", "GET", "\(dsar)/cases/case-1/messages") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getCaseMessages(caseUuid: "case-1")
            },
            Route("PrivacyCenterAPI.sendCaseMessage", "POST", "\(dsar)/cases/case-1/messages") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).sendCaseMessage(caseUuid: "case-1", body: "Hello")
            },
            Route("PrivacyCenterAPI.uploadCaseDocument", "POST", "\(dsar)/cases/case-1/upload-document") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).uploadCaseDocument(caseUuid: "case-1", fileData: Data("pdf".utf8), filename: "a.pdf", mimeType: "application/pdf")
            },
            Route("PrivacyCenterAPI.uploadDocument", "POST", "\(dsar)/upload-document") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).uploadDocument(fileData: Data("pdf".utf8), filename: "a.pdf", mimeType: "application/pdf", principalUuid: "form-1")
            },
            Route("PrivacyCenterAPI.submitDocumentForRequest", "POST", "\(dsar)/cases/case-1/document-requests/event-1/submit") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).submitDocumentForRequest(caseUuid: "case-1", requestEventUuid: "event-1", documentUuid: "doc-1", body: "Attached")
            },
            Route("PrivacyCenterAPI.getCaseDocument", "GET", "\(dsar)/cases/case-1/documents/doc-1") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getCaseDocument(caseUuid: "case-1", documentUuid: "doc-1")
            },
            Route("PrivacyCenterAPI.getNotifications", "GET", "\(dsar)/notifications/") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getNotifications()
            },
            Route("PrivacyCenterAPI.getNotificationSummary", "GET", "\(dsar)/notifications/summary") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getNotificationSummary()
            },
            Route("PrivacyCenterAPI.getUnreadNotificationCount", "GET", "\(dsar)/notifications/unread-count") {
                _ = try? await H.privacyCenter(ledgerBaseUrl: passed).getUnreadNotificationCount()
            },
            Route("PrivacyCenterAPI.markNotificationRead", "PATCH", "\(dsar)/notifications/ntf-1/read") {
                try? await H.privacyCenter(ledgerBaseUrl: passed).markNotificationRead(uuid: "ntf-1")
            },
            Route("PrivacyCenterAPI.markAllNotificationsRead", "POST", "\(dsar)/notifications/mark-all-read") {
                try? await H.privacyCenter(ledgerBaseUrl: passed).markAllNotificationsRead()
            },
            Route("PrivacyCenterAPI.acknowledgeNotification", "POST", "\(dsar)/notifications/ntf-1/acknowledge") {
                try? await H.privacyCenter(ledgerBaseUrl: passed).acknowledgeNotification(uuid: "ntf-1")
            },
            Route("TokenStore OTP refresh", "POST", "\(consent)/otp/refresh") {
                _ = try? await H.tokenStore(baseUrl: host).forceRefresh()
            },
            Route("PrivacyCenterStore.loadBranding with a slug (the token's organisation)", "GET", "\(host)/user/api/0/public/org-branding/\(H.org)") {
                await H.store(ledgerBaseUrl: passed).loadBranding()
            },
            Route("PrivacyCenterStore.loadBranding with only a slug (ignored, no request)", expected: []) {
                await H.store(ledgerBaseUrl: passed, accessToken: "").loadBranding()
            },
            Route("PrivacyCenterStore.loadBranding without a slug (the token's organisation)", "GET", "\(host)/user/api/0/public/org-branding/\(H.org)") {
                await H.store(ledgerBaseUrl: passed, slug: "").loadBranding()
            },
            Route("PrivacyCenterStore.loadBranding without a slug or token (the host's organisation)", "GET", "\(host)/user/api/0/public/org-branding/org-2") {
                await H.store(ledgerBaseUrl: passed, slug: "", accessToken: "", builtInSignIn: true, organisationUuid: "org-2", workspaceUuid: "ws-2").loadBranding()
            },
            Route("PrivacyCenterStore.refreshSettings (published settings)", "GET", "\(host)/consent/public/organisations/\(H.org)/privacy-center-settings/?lang=en") {
                await H.settingsLoad(ledgerBaseUrl: passed)
            },
            Route("PrivacyCenterStore built-in sign-in with only a slug (ignored, no lookup)", expected: []) {
                await H.signInWithOnlyASlug(ledgerBaseUrl: passed)
            },
            Route("PCSignInViewModel.submitContact (built-in sign-in code)", "POST", "\(consent)/otp/create") {
                await H.signInSendCode(ledgerBaseUrl: passed)
            },
        ]
    }

    private func run(_ routes: [Route]) async -> [DumpEntry] {
        var dump: [DumpEntry] = []
        for route in routes {
            let sent = await H.capture(route.perform)
            XCTAssertEqual(sent, route.expected, route.name)
            for (index, request) in sent.enumerated() {
                let name = sent.count == 1 ? route.name : "\(route.name) [\(index + 1)/\(sent.count)]"
                dump.append(DumpEntry(name: name, method: request.method, url: request.url))
            }
        }
        XCTAssertEqual(Set(routes.map(\.name)).count, routes.count, "route names are unique")
        return dump
    }

    func testEveryRequestGoesToTheServiceThatServesItUnderTheHost() async throws {
        let dump = await run(hostRoutes())
        XCTAssertEqual(dump.count, hostRoutes().reduce(0) { $0 + $1.expected.count })

        if let path = ProcessInfo.processInfo.environment["ROUTE_DUMP"], !path.isEmpty {
            try Self.json(dump).write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        }
    }

    func testEveryHostModeRequestStaysOnTheHost() {
        let services = ["/consent/", "/consent-ledger/", "/user/api/0/"]
        for route in hostRoutes() {
            for request in route.expected {
                XCTAssertTrue(
                    services.contains { request.url.hasPrefix("\(H.host)\($0)") },
                    "\(route.name): \(request.url) is under no service of the host"
                )
            }
        }
    }

    /// With the API host, a `ledgerBaseUrl` changes nothing: every surface
    /// sends exactly the request it sends for the host alone.
    func testALedgerBaseUrlPassedWithTheHostIsIgnored() async {
        let hostOnly = await run(hostRoutes())
        let withLedger = await run(hostRoutes(ledgerBaseUrl: H.ignoredLedger))
        XCTAssertEqual(withLedger.map(\.url), hostOnly.map(\.url))
        XCTAssertEqual(withLedger.map(\.method), hostOnly.map(\.method))
        XCTAssertFalse(withLedger.contains { $0.url.contains("localhost:8090") })
    }

    func testTheLedgerUrlFormOfTheHostRoutesTheSame() async {
        let sent = await H.capture {
            _ = try? await ConsentAPI.fetchConsentContent(.init(noticeId: H.notice, accessToken: H.token, baseUrl: "\(H.host)/consent-ledger/"))
        }
        XCTAssertEqual(sent, [SentRequest(method: "GET", url: "\(Self.ledger)/notices/\(H.notice)?validate_against=all")])
    }

    func testTheUserServiceSitsUnderAPathPrefixedHost() async {
        let host = "https://gateway.test/redacto"
        let sent = await H.capture {
            await H.store(baseUrl: host).loadBranding()
            await H.signInWithOnlyASlug(baseUrl: host)
        }
        XCTAssertEqual(sent, [
            SentRequest(method: "GET", url: "\(host)/user/api/0/public/org-branding/\(H.org)"),
        ])
    }

    @MainActor
    func testThePrivacyCenterStoreExposesTheResolvedUrls() {
        let host = H.store()
        XCTAssertEqual(host.baseUrl, "\(H.host)/consent")
        XCTAssertEqual(host.ledgerBaseUrl, "\(H.host)/consent-ledger")

        let ignored = H.store(ledgerBaseUrl: H.ignoredLedger)
        XCTAssertEqual(ignored.baseUrl, "\(H.host)/consent")
        XCTAssertEqual(ignored.ledgerBaseUrl, "\(H.host)/consent-ledger")

        let legacyLedger = "http://localhost:9000/consent-ledger"
        let legacy = H.store(baseUrl: "\(H.host)/consent/", ledgerBaseUrl: " \(legacyLedger)/ ")
        XCTAssertEqual(legacy.baseUrl, "\(H.host)/consent/")
        XCTAssertEqual(legacy.ledgerBaseUrl, legacyLedger)

        let legacyWithoutLedger = H.store(baseUrl: "\(H.host)/consent")
        XCTAssertNil(legacyWithoutLedger.ledgerBaseUrl)
    }

    /// The dump as a JSON array, keys in `name`, `method`, `url` order.
    private static func json(_ entries: [DumpEntry]) throws -> String {
        func string(_ value: String) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])
            return String(decoding: data, as: UTF8.self)
        }
        let objects = try entries.map { entry in
            "  {\"name\": \(try string(entry.name)), \"method\": \(try string(entry.method)), \"url\": \(try string(entry.url))}"
        }
        return "[\n" + objects.joined(separator: ",\n") + "\n]\n"
    }
}
