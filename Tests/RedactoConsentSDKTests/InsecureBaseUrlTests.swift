import XCTest
@testable import RedactoConsentSDK

final class InsecureBaseUrlTests: XCTestCase {
    func testAnHttpBaseUrlToARemoteHostIsRefused() {
        XCTAssertThrowsError(try NoticeBaseUrl.consentServer("http://api.redacto.io"))
    }

    func testAnHttpLedgerUrlToARemoteHostIsRefused() {
        XCTAssertThrowsError(try NoticeBaseUrl.write(ledgerBaseUrl: "http://ledger.test/consent-ledger", baseUrl: "https://api.test/consent"))
    }

    func testHttpsAndLoopbackBaseUrlsStillResolve() throws {
        XCTAssertEqual(try NoticeBaseUrl.consentServer("https://api.redacto.io"), "https://api.redacto.io/consent")
        XCTAssertEqual(try NoticeBaseUrl.consentServer("http://localhost:8000"), "http://localhost:8000/consent")
    }
}
