import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterManageConsentTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
    }

    private func manage(
        _ api: PrivacyCenterAPI,
        _ action: ConsentAction,
        product: String? = nil,
        dataElementUuids: [String]? = nil,
        nominatorContact: String? = nil,
        nominatorUuid: String? = nil,
        language: String? = nil
    ) async throws {
        try await api.manageConsent(ManageConsentRequest(
            purposeUuid: F.purpose,
            contact: F.contact,
            action: action,
            productUuid: product,
            noticeUuid: F.notice,
            dataElements: [F.element("e-1", selected: true), F.element("e-2", selected: false)],
            dataElementUuids: dataElementUuids,
            nominatorContact: nominatorContact,
            nominatorUuid: nominatorUuid,
            language: language
        ))
    }

    private func body(_ index: Int = 0) -> [String: Any] {
        let requests = PCMockURLProtocol.requests
        guard index < requests.count else { return [:] }
        return requests[index].json
    }

    private func purpose(_ index: Int = 0) -> [String: Any] {
        let requests = PCMockURLProtocol.requests
        guard index < requests.count else { return [:] }
        return requests[index].firstPurpose
    }

    private func elements(_ index: Int = 0) -> [String: Bool] {
        let list = purpose(index)["data_elements"] as? [[String: Any]] ?? []
        var result: [String: Bool] = [:]
        for element in list {
            if let uuid = element["uuid"] as? String, let selected = element["selected"] as? Bool {
                result[uuid] = selected
            }
        }
        return result
    }

    func testEachLedgerRevokeIsPinnedToItsOwnCardWhenOnePurposeIsHeldOnTwoProducts() async throws {
        let api = F.api(ledger: F.ledger)
        try await manage(api, .revoke, product: F.productA)
        try await manage(api, .revoke, product: F.productB)

        XCTAssertEqual(body(0)["product_uuid"] as? String, F.productA)
        XCTAssertEqual(purpose(0)["product_uuid"] as? String, F.productA)
        XCTAssertEqual(purpose(0)["purpose_uuid"] as? String, F.purpose)
        XCTAssertEqual(purpose(0)["selected"] as? Bool, false)
        XCTAssertEqual((body(0)["purposes"] as? [Any])?.count, 1)
        XCTAssertEqual(body(0)["partial"] as? Bool, true)

        XCTAssertEqual(body(1)["product_uuid"] as? String, F.productB)
        XCTAssertEqual(purpose(1)["product_uuid"] as? String, F.productB)
    }

    func testALedgerRevokeClearsEveryDataElement() async throws {
        try await manage(F.api(ledger: F.ledger), .revoke, product: F.productA)
        XCTAssertEqual(elements(), ["e-1": false, "e-2": false])
    }

    func testALedgerRegrantIsPinnedAndSelectsOnlyTheChosenElements() async throws {
        try await manage(F.api(ledger: F.ledger), .regrant, product: F.productA, dataElementUuids: ["e-2"])
        XCTAssertEqual(body()["product_uuid"] as? String, F.productA)
        XCTAssertEqual(purpose()["product_uuid"] as? String, F.productA)
        XCTAssertEqual(purpose()["selected"] as? Bool, true)
        XCTAssertEqual(elements(), ["e-1": false, "e-2": true])
    }

    func testALedgerRenewKeepsTheGrantedElements() async throws {
        try await manage(F.api(ledger: F.ledger), .renew, product: F.productA)
        XCTAssertEqual(purpose()["selected"] as? Bool, true)
        XCTAssertEqual(elements(), ["e-1": true, "e-2": false])
    }

    func testTheLedgerBodyOmitsTheProductWhenTheCallerNamesNone() async throws {
        try await manage(F.api(ledger: F.ledger), .revoke)
        XCTAssertNil(body()["product_uuid"])
        XCTAssertNil(purpose()["product_uuid"])
    }

    func testThePythonBodyCarriesTheProduct() async throws {
        try await manage(F.api(ledger: nil), .revoke, product: F.productB)
        XCTAssertTrue(PCMockURLProtocol.requests[0].path.hasSuffix("/manage-consent"))
        XCTAssertEqual(body()["product_uuid"] as? String, F.productB)
    }

    func testThePythonBodyOmitsTheProductWhenTheCallerNamesNone() async throws {
        try await manage(F.api(ledger: nil), .revoke)
        XCTAssertNil(body()["product_uuid"])
        XCTAssertNil(body()["data_element_uuids"])
    }

    func testANomineeLedgerRevokeActsOnTheNominator() async throws {
        try await manage(F.api(ledger: F.ledger), .revoke, product: F.productA, nominatorContact: "nominator@example.test", nominatorUuid: F.nominator)
        XCTAssertEqual(body()["nominator_uuid"] as? String, F.nominator)
        XCTAssertNil(body()["nominator_contact"])
    }

    func testADirectLedgerRevokeSendsNoNominator() async throws {
        try await manage(F.api(ledger: F.ledger), .revoke, product: F.productA)
        XCTAssertNil(body()["nominator_uuid"])
    }

    func testANomineePythonRevokeSendsTheNominatorContact() async throws {
        try await manage(F.api(ledger: nil), .revoke, product: F.productA, nominatorContact: "nominator@example.test", nominatorUuid: F.nominator)
        XCTAssertEqual(body()["nominator_contact"] as? String, "nominator@example.test")
        XCTAssertNil(body()["nominator_uuid"])
    }

    func testLanguageRidesBothManageBodies() async throws {
        try await manage(F.api(ledger: F.ledger), .revoke, language: "hi")
        try await manage(F.api(ledger: nil), .revoke, language: "hi")
        XCTAssertEqual(body(0)["language"] as? String, "hi")
        XCTAssertEqual(body(1)["language"] as? String, "hi")
    }

    func testThePythonEndpointReportingFailureIsAFailure() async throws {
        PCMockURLProtocol.enqueue(.json(200, ["code": 200, "status": "success", "detail": ["success": false]] as [String: Any]))
        do {
            try await manage(F.api(ledger: nil), .revoke)
            XCTFail("expected success=false to throw")
        } catch let error as PrivacyCenterAPIError {
            guard case .consentOperationFailed = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testThePythonEndpointReportingSuccessIsASuccess() async throws {
        PCMockURLProtocol.enqueue(.json(200, ["code": 200, "status": "success", "detail": ["success": true]] as [String: Any]))
        try await manage(F.api(ledger: nil), .revoke)
        PCMockURLProtocol.enqueue(.json(200))
        try await manage(F.api(ledger: nil), .revoke)
    }

    func testTheLedgerRetryAfterA401KeepsLanguageProductAndKey() async throws {
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(200, ["access_token": F.refreshedToken, "refresh_token": "refresh-2"]))
        PCMockURLProtocol.enqueue(.json(401, ["message": "expired"]), .json(200))

        try await manage(F.api(ledger: F.ledger), .revoke, product: F.productB, language: "hi")

        let submits = PCMockURLProtocol.requests(pathSuffix: "/submit-consent")
        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/otp/refresh").count, 1)
        let retry = submits[1].json
        XCTAssertEqual(retry["language"] as? String, "hi")
        XCTAssertEqual(retry["product_uuid"] as? String, F.productB)
        XCTAssertEqual(submits[1].header("Authorization"), "Bearer \(F.refreshedToken)")
        XCTAssertEqual(submits[1].header(IdempotencyKeys.header), submits[0].header(IdempotencyKeys.header))
    }

    func testThePythonRetryAfterA401KeepsLanguageAndProduct() async throws {
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(200, ["access_token": F.refreshedToken, "refresh_token": "refresh-2"]))
        PCMockURLProtocol.enqueue(.json(401, ["message": "expired"]), .json(200))

        try await manage(F.api(ledger: nil), .revoke, product: F.productB, language: "hi")

        let submits = PCMockURLProtocol.requests(pathSuffix: "/manage-consent")
        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(submits[1].json["language"] as? String, "hi")
        XCTAssertEqual(submits[1].json["product_uuid"] as? String, F.productB)
        XCTAssertEqual(submits[1].query("status"), "revoke")
    }

    func testAReadRetriedAfterA401KeepsTheLanguage() async throws {
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(200, ["access_token": F.refreshedToken, "refresh_token": "refresh-2"]))
        PCMockURLProtocol.enqueue(.json(401, ["message": "expired"]), .json(200))

        _ = try await F.api(ledger: F.ledger).getUserConsents(limit: 1, language: "hi")

        let reads = PCMockURLProtocol.requests(pathSuffix: "/user-consents")
        XCTAssertEqual(reads.count, 2)
        XCTAssertEqual(reads[1].query("language"), "hi")
        XCTAssertEqual(reads[1].header("Authorization"), "Bearer \(F.refreshedToken)")
    }
}
