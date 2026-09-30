import XCTest
@testable import RedactoConsentSDK

/// URLSession drops the credential on a redirect; the server redirects some
/// paths to their trailing-slash form, which then answered 401.
final class SameHostRedirectTests: XCTestCase {
    private func request(_ url: String, headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    func testASameHostRedirectKeepsTheBearerAndSandboxToken() {
        let original = request("https://api.example.test/consent/notifications", headers: [
            "Authorization": "Bearer t",
            SandboxConfig.tokenHeader: "sandbox",
        ])

        let next = SameHostRedirect.carryingCredentials(from: original, to: request("https://api.example.test/consent/notifications/"))

        XCTAssertEqual(next.value(forHTTPHeaderField: "Authorization"), "Bearer t")
        XCTAssertEqual(next.value(forHTTPHeaderField: SandboxConfig.tokenHeader), "sandbox")
    }

    func testARedirectToAnotherHostCarriesNoCredential() {
        let original = request("https://api.example.test/consent/notifications", headers: ["Authorization": "Bearer t"])

        let next = SameHostRedirect.carryingCredentials(from: original, to: request("https://elsewhere.test/notifications/"))

        XCTAssertNil(next.value(forHTTPHeaderField: "Authorization"))
    }

    func testADowngradeToHttpCarriesNoCredential() {
        let original = request("https://api.example.test/consent/notifications", headers: ["Authorization": "Bearer t"])

        let next = SameHostRedirect.carryingCredentials(from: original, to: request("http://api.example.test/consent/notifications/"))

        XCTAssertNil(next.value(forHTTPHeaderField: "Authorization"))
    }

    func testARedirectToAnotherPortCarriesNoCredential() {
        let original = request("https://api.example.test/consent/notifications", headers: ["Authorization": "Bearer t"])

        let next = SameHostRedirect.carryingCredentials(from: original, to: request("https://api.example.test:8443/notifications/"))

        XCTAssertNil(next.value(forHTTPHeaderField: "Authorization"))
    }
}
