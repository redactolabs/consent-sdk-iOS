import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterLedgerRoutingTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
    }

    private func revoke(_ api: PrivacyCenterAPI, product: String? = nil) async throws {
        try await api.manageConsent(ManageConsentRequest(
            purposeUuid: F.purpose,
            contact: F.contact,
            action: .revoke,
            productUuid: product,
            noticeUuid: F.notice,
            dataElements: [F.element("e-1", selected: true)]
        ))
    }

    private func onlyRequest() throws -> PCCapturedRequest {
        let requests = PCMockURLProtocol.requests
        XCTAssertEqual(requests.count, 1)
        return try XCTUnwrap(requests.first)
    }

    func testUserConsentsGoToTheLedgerWhenConfigured() async throws {
        _ = try await F.api(ledger: F.ledger).getUserConsents(limit: 1, language: "hi")
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.ledgerPrefix)/user-consents")
        XCTAssertEqual(request.query("language"), "hi")
        XCTAssertEqual(request.header("Authorization"), "Bearer \(F.liveToken)")
    }

    func testUserConsentsStayOnTheConsentServerWithoutALedger() async throws {
        _ = try await F.api(ledger: nil).getUserConsents(limit: 1)
        XCTAssertEqual(try onlyRequest().urlWithoutQuery, "\(F.consentPrefix)/user-consents")
    }

    func testGroupPurposesGoToTheLedgerWithTheNominator() async throws {
        PCMockURLProtocol.enqueue(.json(200, ["purposes": [] as [Any]]))
        _ = try await F.api(ledger: F.ledger).getGroupPurposes(
            productUuid: F.productA,
            offset: 1,
            limit: 50,
            language: "hi",
            nominatorUuid: F.nominator
        )
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.ledgerPrefix)/user-consents/\(F.productA)/purposes")
        XCTAssertEqual(request.query("offset"), "1")
        XCTAssertEqual(request.query("limit"), "50")
        XCTAssertEqual(request.query("language"), "hi")
        XCTAssertEqual(request.query("nominator_uuid"), F.nominator)
    }

    func testGroupPurposesStayOnTheConsentServerWithoutALedger() async throws {
        PCMockURLProtocol.enqueue(.json(200, ["purposes": [] as [Any]]))
        _ = try await F.api(ledger: nil).getGroupPurposes(productUuid: F.productA)
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/user-consents/\(F.productA)/purposes")
        XCTAssertNil(request.query("nominator_uuid"))
    }

    func testReceiptsGoToTheLedgerWhenConfigured() async throws {
        _ = try await F.api(ledger: F.ledger).getReceipts(language: "hi")
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.ledgerPrefix)/receipts")
        XCTAssertEqual(request.query("language"), "hi")
    }

    func testReceiptsStayOnTheConsentServerWithoutALedger() async throws {
        _ = try await F.api(ledger: nil).getReceipts()
        XCTAssertEqual(try onlyRequest().urlWithoutQuery, "\(F.consentPrefix)/receipts")
    }

    func testReceiptDownloadUsesTheLedgerDownloadRoute() async throws {
        _ = try await F.api(ledger: F.ledger).getReceiptPdf(receiptUuid: F.receipt)
        let request = try onlyRequest()
        XCTAssertEqual(request.url.absoluteString, "\(F.ledgerPrefix)/receipts/\(F.receipt)/download")
        XCTAssertEqual(request.header("Accept"), "application/pdf")
    }

    func testReceiptDownloadUsesThePdfRouteWithoutALedger() async throws {
        _ = try await F.api(ledger: nil).getReceiptPdf(receiptUuid: F.receipt)
        XCTAssertEqual(try onlyRequest().url.absoluteString, "\(F.consentPrefix)/receipts/\(F.receipt)/pdf")
    }

    func testActivitiesStayOnTheConsentServerBecauseTheLedgerHasNoRoute() async throws {
        _ = try await F.api(ledger: F.ledger).getActivities(language: "hi")
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/activities")
        XCTAssertEqual(request.query("language"), "hi")
    }

    func testCaseHistoryStaysOnTheConsentServerWithALedger() async throws {
        _ = try await F.api(ledger: F.ledger).getCaseHistory()
        XCTAssertEqual(try onlyRequest().urlWithoutQuery, "\(F.consentPrefix)/cases")
    }

    func testManageConsentSubmitsToTheLedgerWhenConfigured() async throws {
        try await revoke(F.api(ledger: F.ledger))
        let request = try onlyRequest()
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "\(F.ledgerPrefix)/submit-consent")
        XCTAssertEqual(request.json["notice_uuid"] as? String, F.notice)
        XCTAssertEqual(request.json["partial"] as? Bool, true)
        XCTAssertEqual(request.json["declined"] as? Bool, false)
        XCTAssertNil(request.json["contact"])
    }

    func testManageConsentUsesThePythonEndpointWithoutALedger() async throws {
        try await revoke(F.api(ledger: nil))
        let request = try onlyRequest()
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/manage-consent")
        XCTAssertEqual(request.query("status"), "revoke")
        XCTAssertEqual(request.json["purpose_uuid"] as? String, F.purpose)
        XCTAssertEqual(request.json["contact"] as? String, F.contact)
        XCTAssertNil(request.json["notice_uuid"])
    }

    func testATrailingSlashOnTheLedgerUrlIsDropped() async throws {
        _ = try await F.api(ledger: F.ledger + "/").getUserConsents()
        XCTAssertEqual(try onlyRequest().urlWithoutQuery, "\(F.ledgerPrefix)/user-consents")
    }

    func testABlankLedgerUrlKeepsEveryRouteOnTheConsentServer() async throws {
        let api = F.api(ledger: "  ")
        _ = try await api.getUserConsents()
        try await revoke(api)
        let urls = PCMockURLProtocol.requests.map { $0.urlWithoutQuery }
        XCTAssertEqual(urls, ["\(F.consentPrefix)/user-consents", "\(F.consentPrefix)/manage-consent"])
    }

    func testTheLedgerRevokeFailsWithoutANoticeInsteadOfPostingAnInvalidBody() async throws {
        let api = F.api(ledger: F.ledger)
        do {
            try await api.manageConsent(ManageConsentRequest(purposeUuid: F.purpose, contact: F.contact, action: .revoke))
            XCTFail("expected the revoke to fail without a notice")
        } catch {
            XCTAssertTrue(PCMockURLProtocol.requests.isEmpty)
        }
    }

    func testALedgerErrorSurfacesAsTheStatusItCarries() async throws {
        PCMockURLProtocol.enqueue(.json(409, ["message": "conflict"]))
        do {
            try await revoke(F.api(ledger: F.ledger))
            XCTFail("expected the 409 to throw")
        } catch let error as PrivacyCenterAPIError {
            XCTAssertEqual(error.httpStatus, 409)
        }
    }

    func testAServerMessageIsSurfaced() {
        let data = Data("{\"message\":\"Consent already withdrawn\"}".utf8)
        XCTAssertEqual(PrivacyCenterHTTPClient.extractMessage(from: data, status: 409), "Consent already withdrawn")
    }

    func testANestedDetailMessageIsSurfaced() {
        let data = Data("{\"detail\":{\"message\":\"Nominator not found\",\"error_code\":\"NOMINATOR_NOT_FOUND\"}}".utf8)
        XCTAssertEqual(PrivacyCenterHTTPClient.extractMessage(from: data, status: 400), "Nominator not found")
    }

    func testRawUpstreamTextIsNeverSurfaced() {
        let html = Data("<html><body>502 Bad Gateway nginx</body></html>".utf8)
        XCTAssertNil(PrivacyCenterHTTPClient.extractMessage(from: html, status: 502))
        XCTAssertNil(PrivacyCenterHTTPClient.extractMessage(from: Data("upstream connect error".utf8), status: 400))
    }

    func testAJsonBodyWithoutAMessageFallsBackToTheStatusCopy() {
        let data = Data("{\"error\":\"x\"}".utf8)
        XCTAssertEqual(PrivacyCenterHTTPClient.extractMessage(from: data, status: 503), APIStatusFallback.serverFailure)
        XCTAssertNil(PrivacyCenterHTTPClient.extractMessage(from: data, status: 400))
    }

    func testANonJsonGatewayErrorReachesTheCallerAsTheEndpointFallback() async throws {
        PCMockURLProtocol.enqueue(.raw(502, "<html>Bad Gateway</html>"))
        do {
            _ = try await F.api(ledger: F.ledger).getUserConsents()
            XCTFail("expected the 502 to throw")
        } catch let error as PrivacyCenterAPIError {
            XCTAssertEqual(error.httpStatus, 502)
            XCTAssertFalse((error.errorDescription ?? "").contains("html"))
        }
    }
}
