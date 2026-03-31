import XCTest
@testable import RedactoConsentSDK

final class JWTDecoderTests: XCTestCase {
    func testDecodeValidToken() {
        // JWT with payload: {"organisation_uuid":"org-123","workspace_uuid":"ws-456","user_uuid":"user-789","exp":1700000000,"iat":1699990000}
        // Header: {"alg":"HS256","typ":"JWT"}
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJvcmdhbmlzYXRpb25fdXVpZCI6Im9yZy0xMjMiLCJ3b3Jrc3BhY2VfdXVpZCI6IndzLTQ1NiIsInVzZXJfdXVpZCI6InVzZXItNzg5IiwiZXhwIjoxNzAwMDAwMDAwLCJpYXQiOjE2OTk5OTAwMDB9"
        let signature = "test_signature"
        let token = "\(header).\(payload).\(signature)"

        let decoded = JWTDecoder.decode(token)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.organisationUuid, "org-123")
        XCTAssertEqual(decoded?.workspaceUuid, "ws-456")
        XCTAssertEqual(decoded?.userUuid, "user-789")
        XCTAssertEqual(decoded?.exp, 1700000000)
        XCTAssertEqual(decoded?.iat, 1699990000)
    }

    func testDecodeInvalidToken() {
        let decoded = JWTDecoder.decode("not-a-jwt")
        XCTAssertNil(decoded)
    }

    func testDecodeEmptyToken() {
        let decoded = JWTDecoder.decode("")
        XCTAssertNil(decoded)
    }

    func testDecodeTokenWithoutUserUuid() {
        // Payload: {"organisation_uuid":"org-abc","workspace_uuid":"ws-def"}
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJvcmdhbmlzYXRpb25fdXVpZCI6Im9yZy1hYmMiLCJ3b3Jrc3BhY2VfdXVpZCI6IndzLWRlZiJ9"
        let token = "\(header).\(payload).sig"

        let decoded = JWTDecoder.decode(token)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.organisationUuid, "org-abc")
        XCTAssertEqual(decoded?.workspaceUuid, "ws-def")
        XCTAssertNil(decoded?.userUuid)
    }
}
