import XCTest
@testable import RedactoConsentSDK

final class NoticeTransportRoutingTests: XCTestCase {
    private typealias F = TransportFixtures

    override func setUp() async throws {
        try await super.setUp()
        await APICache.shared.clear()
        IdempotencyKeys.shared.reset()
        TransportStubProtocol.install { request in
            if request.path.hasSuffix("/submit-consent") {
                return .empty(201)
            }
            if request.path.hasSuffix("/check-consent") {
                return .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: true))
            }
            if request.path.contains("/audio/") {
                return .json(404, ["message": "no audio"])
            }
            return .json(200, F.noticeJSON())
        }
    }

    override func tearDown() async throws {
        TransportStubProtocol.uninstall()
        IdempotencyKeys.shared.reset()
        await APICache.shared.clear()
        try await super.tearDown()
    }

    private func read(
        ledgerBaseUrl: String?,
        specificUuid: String? = nil,
        sandbox: SandboxConfig? = nil
    ) async throws -> TransportStubRequest {
        _ = try await ConsentAPI.fetchConsentContent(.init(
            noticeId: F.notice,
            accessToken: sandbox == nil ? F.token() : "",
            baseUrl: F.python,
            ledgerBaseUrl: ledgerBaseUrl,
            specificUuid: specificUuid,
            sandbox: sandbox
        ))
        return try XCTUnwrap(TransportStubProtocol.requests.last)
    }

    private func submit(
        ledgerBaseUrl: String?,
        sandbox: SandboxConfig? = nil,
        purposes: [Purpose] = [F.purpose()],
        orgUuid: String? = nil,
        workspaceUuid: String? = nil
    ) async throws -> TransportStubRequest {
        try await ConsentAPI.submitConsentEvent(.init(
            accessToken: sandbox == nil ? F.token() : "",
            baseUrl: F.python,
            ledgerBaseUrl: ledgerBaseUrl,
            noticeUuid: F.notice,
            purposes: purposes,
            declined: false,
            orgUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            sandbox: sandbox
        ))
        return try XCTUnwrap(TransportStubProtocol.requests(pathSuffix: "/submit-consent").last)
    }

    func testNoticeReadGoesToTheLedgerWhenOneIsConfigured() async throws {
        let request = try await read(ledgerBaseUrl: F.ledger)
        XCTAssertEqual(request.path, URL(string: "\(F.scope(F.ledger))/notices/\(F.notice)")!.path)
        XCTAssertEqual(request.url.host, "ledger.example.test")
        XCTAssertEqual(request.header("Authorization"), "Bearer \(F.token())")
        XCTAssertEqual(request.query("validate_against"), "all")
    }

    func testNoticeReadStaysOnTheConsentServerWithoutALedger() async throws {
        let request = try await read(ledgerBaseUrl: nil)
        XCTAssertEqual(request.url.host, "api.example.test")
        XCTAssertTrue(request.path.hasPrefix("/consent/public/organisations/\(F.org)/workspaces/\(F.workspace)/notices/"))
    }

    func testBlankLedgerIsTreatedAsUnsetForTheRead() async throws {
        let request = try await read(ledgerBaseUrl: "   ")
        XCTAssertEqual(request.url.host, "api.example.test")
    }

    func testMagicLinkReadStaysOnTheConsentServer() async throws {
        let request = try await read(ledgerBaseUrl: F.ledger, specificUuid: "app-1")
        XCTAssertEqual(request.url.host, "api.example.test")
        XCTAssertEqual(request.query("specific_uuid"), "app-1")
    }

    func testSandboxReadStaysOnTheConsentServerAndCarriesEveryIdentifier() async throws {
        let request = try await read(ledgerBaseUrl: F.ledger, sandbox: F.sandbox)
        XCTAssertEqual(request.url.host, "api.example.test")
        XCTAssertEqual(request.header(SandboxConfig.tokenHeader), "sandbox-token")
        XCTAssertNil(request.header("Authorization"))
        XCTAssertEqual(request.query("org_user_id"), "ucic-1")
        XCTAssertEqual(request.query("primary_email"), "tester@example.test")
        XCTAssertEqual(request.query("primary_mobile"), "+919999999999")
    }

    func testNoticeReadCarriesNoIdempotencyKey() async throws {
        let request = try await read(ledgerBaseUrl: F.ledger)
        XCTAssertNil(request.header(IdempotencyKeys.header))
    }

    func testLiveSubmitGoesToTheLedgerWhenOneIsConfigured() async throws {
        let request = try await submit(ledgerBaseUrl: F.ledger)
        XCTAssertEqual(request.url.absoluteString, "\(F.scope(F.ledger))/submit-consent")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.header("Authorization"), "Bearer \(F.token())")
        XCTAssertNotNil(request.header(IdempotencyKeys.header))
    }

    func testLiveSubmitStaysOnTheConsentServerWithoutALedger() async throws {
        let request = try await submit(ledgerBaseUrl: nil)
        XCTAssertEqual(request.url.absoluteString, "\(F.scope(F.python))/submit-consent")
        XCTAssertNotNil(request.header(IdempotencyKeys.header))
    }

    func testBlankLedgerIsTreatedAsUnsetForTheSubmit() async throws {
        let request = try await submit(ledgerBaseUrl: "")
        XCTAssertEqual(request.url.host, "api.example.test")
    }

    func testSandboxSubmitGoesToTheLedgerWithTheSandboxCredentialAndEveryIdentifier() async throws {
        let request = try await submit(ledgerBaseUrl: F.ledger, sandbox: F.sandbox)
        XCTAssertEqual(request.url.absoluteString, "\(F.scope(F.ledger))/submit-consent")
        XCTAssertEqual(request.header(SandboxConfig.tokenHeader), "sandbox-token")
        XCTAssertNil(request.header("Authorization"))
        XCTAssertNotNil(request.header(IdempotencyKeys.header))
        let body = try XCTUnwrap(request.jsonBody)
        XCTAssertEqual(body["org_user_id"] as? String, "ucic-1")
        XCTAssertEqual(body["primary_email"] as? String, "tester@example.test")
        XCTAssertEqual(body["primary_mobile"] as? String, "+919999999999")
        XCTAssertEqual(body["notice_uuid"] as? String, F.notice)
    }

    func testSandboxSubmitStaysOnTheConsentServerWithoutALedger() async throws {
        let request = try await submit(ledgerBaseUrl: nil, sandbox: F.sandbox)
        XCTAssertEqual(request.url.host, "api.example.test")
        XCTAssertEqual(request.header(SandboxConfig.tokenHeader), "sandbox-token")
    }

    func testInlineSubmitGoesToTheLedgerWithTheInlineScope() async throws {
        let request = try await submit(
            ledgerBaseUrl: F.ledger,
            orgUuid: "org-inline",
            workspaceUuid: "ws-inline"
        )
        XCTAssertEqual(
            request.url.absoluteString,
            "\(F.ledger)/public/organisations/org-inline/workspaces/ws-inline/submit-consent"
        )
    }

    func testAudioGoesToTheLedgerForALiveSession() async {
        _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(
            accessToken: F.token(),
            baseUrl: F.python,
            ledgerBaseUrl: F.ledger,
            noticeUuid: F.notice,
            language: "English"
        ))
        XCTAssertEqual(TransportStubProtocol.requests.last?.url.host, "ledger.example.test")
    }

    func testAudioStaysOnTheConsentServerForASandboxSession() async {
        _ = try? await ConsentAPI.fetchTTSAudioUrls(.init(
            accessToken: "",
            baseUrl: F.python,
            ledgerBaseUrl: F.ledger,
            noticeUuid: F.notice,
            language: "English",
            sandbox: F.sandbox
        ))
        XCTAssertEqual(TransportStubProtocol.requests.last?.url.host, "api.example.test")
    }

    func testSingleProductSubmitCarriesNoProductUuid() async throws {
        let request = try await submit(ledgerBaseUrl: F.ledger)
        let raw = try XCTUnwrap(request.bodyString)
        XCTAssertFalse(raw.contains("product_uuid"))
        let body = try XCTUnwrap(request.jsonBody)
        let expected: [String: Any] = [
            "notice_uuid": F.notice,
            "select_all_mandatory": false,
            "source": "MOBILE",
            "declined": false,
            "purposes": [
                [
                    "purpose_uuid": "p-1",
                    "selected": true,
                    "data_elements": [
                        ["uuid": "de-1", "selected": true],
                        ["uuid": "de-2", "selected": false],
                    ],
                ] as [String: Any],
            ],
        ]
        XCTAssertEqual(NSDictionary(dictionary: body), NSDictionary(dictionary: expected))
    }

    func testBlankProductUuidIsOmitted() async throws {
        let request = try await submit(ledgerBaseUrl: F.ledger, purposes: [F.purpose(productUuid: "")])
        XCTAssertFalse(try XCTUnwrap(request.bodyString).contains("product_uuid"))
    }

    func testPerPurposeProductUuidIsCarriedOnEachEntry() async throws {
        let request = try await submit(ledgerBaseUrl: F.ledger, purposes: [
            F.purpose(uuid: "p-shared", productUuid: "prod-a"),
            F.purpose(uuid: "p-shared", selected: false, productUuid: "prod-b"),
            F.purpose(uuid: "p-scoped", productUuid: "prod-a"),
        ])
        let entries = try XCTUnwrap(request.jsonBody?["purposes"] as? [[String: Any]])
        XCTAssertEqual(entries.map { $0["purpose_uuid"] as? String }, ["p-shared", "p-shared", "p-scoped"])
        XCTAssertEqual(entries.map { $0["product_uuid"] as? String }, ["prod-a", "prod-b", "prod-a"])
        XCTAssertEqual(entries.map { $0["selected"] as? Bool }, [true, false, true])
    }

    func testCheckConsentPostsToTheLedgerWithTheBearer() async throws {
        let status = await ConsentAPI.fetchNoticeConsentStatus(.init(
            accessToken: F.token(),
            ledgerBaseUrl: F.ledger,
            organisationUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice
        ))
        XCTAssertEqual(status?.isFullyConsented, true)
        let request = try XCTUnwrap(TransportStubProtocol.requests.last)
        XCTAssertEqual(request.url.absoluteString, "\(F.scope(F.ledger))/notices/\(F.notice)/check-consent")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.header("Authorization"), "Bearer \(F.token())")
        XCTAssertEqual(request.bodyString, "{}")
    }

    func testCheckConsentIsSkippedWithoutALedger() async {
        let status = await ConsentAPI.fetchNoticeConsentStatus(.init(
            accessToken: F.token(),
            ledgerBaseUrl: nil,
            organisationUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice
        ))
        XCTAssertNil(status)
        XCTAssertTrue(TransportStubProtocol.requests.isEmpty)
    }

    func testCheckConsentToleratesADetailEnvelope() async {
        TransportStubProtocol.install { _ in
            .json(200, ["detail": F.consentStatusJSON(consented: true, allMandatoryActive: false)])
        }
        let status = await ConsentAPI.fetchNoticeConsentStatus(.init(
            accessToken: F.token(),
            ledgerBaseUrl: F.ledger,
            organisationUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice
        ))
        XCTAssertEqual(status?.consented, true)
        XCTAssertEqual(status?.isFullyConsented, false)
    }

    func testCheckConsentDegradesToNilOnAFailure() async {
        TransportStubProtocol.install { _ in .json(500, ["message": "down"]) }
        let status = await ConsentAPI.fetchNoticeConsentStatus(.init(
            accessToken: F.token(),
            ledgerBaseUrl: F.ledger,
            organisationUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice
        ))
        XCTAssertNil(status)
    }
}
