import XCTest
@testable import RedactoConsentSDK

final class SafeLinkTests: XCTestCase {
    func testWebAcceptsHttpAndHttpsWithAHost() {
        XCTAssertEqual(SafeLink.web("https://acme.test/privacy")?.absoluteString, "https://acme.test/privacy")
        XCTAssertEqual(SafeLink.web(" HTTP://acme.test/p ")?.host, "acme.test")
    }

    func testWebRefusesOtherSchemesAndHostlessValues() {
        for value in ["javascript:alert(1)", "myapp://open", "file:///etc/passwd", "mailto:dpo@acme.test", "tel:+911234", "https:", "", "   ", "not a url"] {
            XCTAssertNil(SafeLink.web(value), value)
        }
        XCTAssertNil(SafeLink.web(nil))
    }

    func testPlaintextRemoteIsHttpToANonLoopbackHost() {
        XCTAssertTrue(SafeLink.isPlaintextRemote("http://api.redacto.io/consent"))
        XCTAssertFalse(SafeLink.isPlaintextRemote("https://api.redacto.io/consent"))
        XCTAssertFalse(SafeLink.isPlaintextRemote("http://localhost:8000/consent"))
        XCTAssertFalse(SafeLink.isPlaintextRemote("http://127.0.0.1:8000"))
        XCTAssertFalse(SafeLink.isPlaintextRemote("http://[::1]:8000/consent"))
        XCTAssertFalse(SafeLink.isPlaintextRemote("/relative"))
    }
}
