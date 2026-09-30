import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterSandboxLedgerTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
    }

    private func revoke(_ api: PrivacyCenterAPI, contact: String = F.contact) async throws {
        try await api.manageConsent(ManageConsentRequest(
            purposeUuid: F.purpose,
            contact: contact,
            action: .revoke,
            productUuid: F.productA,
            noticeUuid: F.notice,
            dataElements: [F.element("e-1", selected: true)]
        ))
    }

    func testASandboxRevokeGoesToTheLedgerWithTheIdentityAndCredential() async throws {
        try await revoke(F.api(ledger: F.ledger, sandbox: F.sandbox))

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.url.absoluteString, "\(F.ledgerPrefix)/submit-consent")
        XCTAssertEqual(request.json["org_user_id"] as? String, "UCIC-9")
        XCTAssertEqual(request.json["primary_email"] as? String, "tester@example.test")
        XCTAssertEqual(request.json["primary_mobile"] as? String, "+919999999999")
        XCTAssertEqual(request.json["notice_uuid"] as? String, F.notice)
        XCTAssertEqual(request.json["product_uuid"] as? String, F.productA)
        XCTAssertEqual(request.firstPurpose["selected"] as? Bool, false)
        XCTAssertEqual(request.header(SandboxConfig.tokenHeader), "sandbox-token")
        XCTAssertNil(request.header("Authorization"))
        XCTAssertNotNil(request.header(IdempotencyKeys.header))
    }

    func testASandboxReceiptDownloadGoesToTheLedgerWithTheIdentityInTheQuery() async throws {
        _ = try await F.api(ledger: F.ledger, sandbox: F.sandbox).getReceiptPdf(receiptUuid: F.receipt)

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.urlWithoutQuery, "\(F.ledgerPrefix)/receipts/\(F.receipt)/download")
        XCTAssertEqual(request.query("org_user_id"), "UCIC-9")
        XCTAssertEqual(request.query("primary_email"), "tester@example.test")
        XCTAssertEqual(request.query("primary_mobile"), "+919999999999")
        XCTAssertEqual(request.header(SandboxConfig.tokenHeader), "sandbox-token")
    }

    func testSandboxLedgerReadsCarryTheIdentityInTheQuery() async throws {
        let api = F.api(ledger: F.ledger, sandbox: F.sandbox)
        _ = try await api.getUserConsents()
        PCMockURLProtocol.enqueue(.json(200, ["purposes": [] as [Any]]))
        _ = try await api.getGroupPurposes(productUuid: F.productA)
        _ = try await api.getReceipts()

        let requests = PCMockURLProtocol.requests
        XCTAssertEqual(requests.map { $0.urlWithoutQuery }, [
            "\(F.ledgerPrefix)/user-consents",
            "\(F.ledgerPrefix)/user-consents/\(F.productA)/purposes",
            "\(F.ledgerPrefix)/receipts",
        ])
        for request in requests {
            XCTAssertEqual(request.query("org_user_id"), "UCIC-9")
            XCTAssertEqual(request.query("primary_email"), "tester@example.test")
            XCTAssertEqual(request.query("primary_mobile"), "+919999999999")
            XCTAssertNil(request.header("Authorization"))
        }
    }

    func testSandboxWithoutALedgerStaysOnPythonWithTheSandboxContact() async throws {
        try await revoke(F.api(ledger: nil, sandbox: F.sandbox), contact: F.sandbox.contact)

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/manage-consent")
        XCTAssertEqual(request.json["contact"] as? String, "UCIC-9")
        XCTAssertNil(request.json["org_user_id"])
        XCTAssertNil(request.header(IdempotencyKeys.header))
    }

    func testALiveLedgerRevokeSendsNoSandboxIdentity() async throws {
        try await revoke(F.api(ledger: F.ledger))

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertNil(request.json["org_user_id"])
        XCTAssertNil(request.json["primary_email"])
        XCTAssertNil(request.json["primary_mobile"])
        XCTAssertEqual(request.header("Authorization"), "Bearer \(F.liveToken)")
        XCTAssertNil(request.header(SandboxConfig.tokenHeader))
    }

    func testALiveLedgerReceiptDownloadHasNoIdentityQuery() async throws {
        _ = try await F.api(ledger: F.ledger).getReceiptPdf(receiptUuid: F.receipt)
        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.url.absoluteString, "\(F.ledgerPrefix)/receipts/\(F.receipt)/download")
    }

    func testASandboxLedgerBodyIsStableAcrossRetriesSoTheKeyHolds() async throws {
        PCMockURLProtocol.enqueue(.json(503), .json(200))
        let api = F.api(ledger: F.ledger, sandbox: F.sandbox)
        do {
            try await revoke(api)
            XCTFail("expected the 503 to throw")
        } catch {}
        try await revoke(api)

        let submits = PCMockURLProtocol.requests(pathSuffix: "/submit-consent")
        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(submits[0].body, submits[1].body)
        XCTAssertEqual(submits[0].header(IdempotencyKeys.header), submits[1].header(IdempotencyKeys.header))
    }
}
