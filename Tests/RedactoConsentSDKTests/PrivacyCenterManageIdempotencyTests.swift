import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterManageIdempotencyTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
    }

    private func revoke(_ ledger: String?) async throws {
        try await F.api(ledger: ledger).manageConsent(ManageConsentRequest(
            purposeUuid: F.purpose,
            contact: F.contact,
            action: .revoke,
            productUuid: F.productA,
            noticeUuid: F.notice,
            dataElements: [F.element("e-1", selected: true)]
        ))
    }

    private func key(_ index: Int) -> String? {
        let requests = PCMockURLProtocol.requests
        guard index < requests.count else { return nil }
        return requests[index].header(IdempotencyKeys.header)
    }

    func testTheLedgerRevokeReusesItsKeyAfterA5xx() async throws {
        PCMockURLProtocol.enqueue(.json(503, ["detail": "unavailable"]), .json(200))
        do {
            try await revoke(F.ledger)
            XCTFail("expected the 503 to throw")
        } catch {}
        try await revoke(F.ledger)
        XCTAssertNotNil(key(0))
        XCTAssertEqual(key(1), key(0))
    }

    func testTheLedgerRevokeReusesItsKeyAfterADroppedConnection() async throws {
        PCMockURLProtocol.enqueue(.failure(.networkConnectionLost), .json(200))
        do {
            try await revoke(F.ledger)
            XCTFail("expected the dropped connection to throw")
        } catch {}
        try await revoke(F.ledger)
        XCTAssertEqual(key(1), key(0))
    }

    func testTheLedgerRevokeMintsAFreshKeyAfterA4xx() async throws {
        PCMockURLProtocol.enqueue(.json(422, ["detail": "invalid"]), .json(200))
        do {
            try await revoke(F.ledger)
            XCTFail("expected the 422 to throw")
        } catch let error as PrivacyCenterAPIError {
            XCTAssertEqual(error.httpStatus, 422)
        }
        try await revoke(F.ledger)
        XCTAssertNotNil(key(1))
        XCTAssertNotEqual(key(1), key(0))
    }

    func testTheNextLedgerRevokeAfterASuccessGetsAFreshKey() async throws {
        try await revoke(F.ledger)
        try await revoke(F.ledger)
        XCTAssertNotEqual(key(1), key(0))
    }

    func testThePythonManageConsentSendsNoKey() async throws {
        try await revoke(nil)
        XCTAssertNil(key(0))
    }

    func testTheSharedStoreReleasesAKeyWhenThePrivacyCenterThrowsA4xx() async {
        let keys = IdempotencyKeys()
        var seen: [String] = []
        for _ in 0..<2 {
            _ = try? await keys.withKey(url: F.ledger, body: Data("{}".utf8)) { headers -> (Data, URLResponse) in
                seen.append(headers[IdempotencyKeys.header] ?? "")
                throw PrivacyCenterAPIError.validationError(nil)
            }
        }
        XCTAssertEqual(seen.count, 2)
        XCTAssertNotEqual(seen[0], seen[1])
    }

    func testTheSharedStoreKeepsAKeyWhenThePrivacyCenterThrowsA5xx() async {
        let keys = IdempotencyKeys()
        var seen: [String] = []
        for _ in 0..<2 {
            _ = try? await keys.withKey(url: F.ledger, body: Data("{}".utf8)) { headers -> (Data, URLResponse) in
                seen.append(headers[IdempotencyKeys.header] ?? "")
                throw PrivacyCenterAPIError.serverError(503, nil)
            }
        }
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(seen[0], seen[1])
    }
}
