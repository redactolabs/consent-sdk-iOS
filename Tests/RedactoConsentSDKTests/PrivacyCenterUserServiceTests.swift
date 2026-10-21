import XCTest
@testable import RedactoConsentSDK

/// Port of the React SDK's `orgBranding.test.ts`: the user service lives on
/// the caller's own origin, never on a staging host the SDK picked.
final class PrivacyCenterUserServiceTests: XCTestCase {
    private let staging = "api.redacto.tech"
    private let defaultService = "https://api.redacto.io/user/api/0"

    func testStaysOnTheCallersOwnHost() {
        let cases = [
            ("https://api.redacto.io/consent", "https://api.redacto.io/user/api/0"),
            ("https://\(staging)/consent", "https://\(staging)/user/api/0"),
            ("https://consent.acme.com/consent", "https://consent.acme.com/user/api/0"),
            ("https://gateway.example.co.uk/api/consent", "https://gateway.example.co.uk/user/api/0"),
            ("http://localhost:8000/consent", "http://localhost:8000/user/api/0"),
            ("https://consent.acme.io/consent", "https://consent.acme.io/user/api/0"),
        ]
        for (baseUrl, expected) in cases {
            XCTAssertEqual(PrivacyCenterUserService.baseUrl(for: baseUrl), expected, baseUrl)
        }
    }

    func testDoesNotLeakACustomHostToStaging() {
        for baseUrl in ["https://consent.acme.com/consent", "https://gateway.example.co.uk/api/consent", "http://localhost:8000/consent"] {
            XCTAssertFalse(PrivacyCenterUserService.baseUrl(for: baseUrl).contains(staging), baseUrl)
        }
    }

    func testFallsBackToTheShippedDefaultRatherThanTrustingABadOrigin() {
        for baseUrl in ["https://api.redacto.io:abc/consent", "ftp://api.redacto.io/consent", "api.redacto.io/consent", "not a url", ""] {
            XCTAssertEqual(PrivacyCenterUserService.baseUrl(for: baseUrl), defaultService, baseUrl)
        }
    }

    func testStillAcceptsAPortAnIPv6HostOrNoPath() {
        XCTAssertEqual(PrivacyCenterUserService.baseUrl(for: "https://api.redacto.io:8090/consent"), "https://api.redacto.io:8090/user/api/0")
        XCTAssertEqual(PrivacyCenterUserService.baseUrl(for: "http://[::1]:8000/consent"), "http://[::1]:8000/user/api/0")
        XCTAssertEqual(PrivacyCenterUserService.baseUrl(for: "https://consent.acme.com"), "https://consent.acme.com/user/api/0")
    }
}
