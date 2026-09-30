import XCTest
@testable import RedactoConsentSDK

final class APIErrorParserTests: XCTestCase {
    private let fallback = "Could not submit your consent. Please try again."

    private func parse(_ status: Int, _ body: String) -> RedactoAPIError {
        APIErrorParser.error(status: status, data: Data(body.utf8), fallback: fallback)
    }

    func testPassesThroughATopLevelMessageAndCode() {
        let error = parse(422, #"{"message":"Purpose p-9 is not on this notice.","error_code":"INVALID_PURPOSE"}"#)
        XCTAssertEqual(error.errorDescription, "Purpose p-9 is not on this notice.")
        XCTAssertEqual(error.errorCode, "INVALID_PURPOSE")
        XCTAssertEqual(error.statusCode, 422)
    }

    func testPassesThroughAMessageNestedInDetail() {
        let error = parse(409, #"{"detail":{"message":"Consent already provided.","error_code":"CONSENT_ALREADY_PROVIDED"}}"#)
        XCTAssertEqual(error.errorDescription, "Consent already provided.")
        XCTAssertEqual(error.errorCode, "CONSENT_ALREADY_PROVIDED")
        XCTAssertEqual(error.statusCode, 409)
    }

    func testPassesThroughAStringDetail() {
        let error = parse(404, #"{"code":404,"status":"NOT_FOUND","detail":"notice not found"}"#)
        XCTAssertEqual(error.errorDescription, "notice not found")
        XCTAssertNil(error.errorCode)
    }

    func testReadsTheNestedDetailOfAnAuthPipeline401() {
        let error = parse(401, #"{"detail":{"detail":"Unauthorized"}}"#)
        XCTAssertEqual(error.errorDescription, "Unauthorized")
        XCTAssertEqual(error.statusCode, 401)
    }

    func testPrefersTheTopLevelMessageOverDetail() {
        let error = parse(400, #"{"message":"top","detail":{"message":"nested"}}"#)
        XCTAssertEqual(error.errorDescription, "top")
    }

    func testFieldErrorArrayFallsBackToTheEndpointMessage() {
        let error = parse(422, #"{"code":422,"status":"UNPROCESSABLE_ENTITY","detail":[{"field":"purposes","message":"required"}]}"#)
        XCTAssertEqual(error.errorDescription, fallback)
        XCTAssertEqual(error.statusCode, 422)
    }

    func testParsedBodyWithoutAMessageUsesTheStatusHint() {
        XCTAssertEqual(parse(401, #"{"code":401}"#).errorDescription, APIStatusFallback.unauthorized)
        XCTAssertEqual(parse(403, #"{}"#).errorDescription, APIStatusFallback.forbidden)
        XCTAssertEqual(parse(502, #"{"detail":[]}"#).errorDescription, APIStatusFallback.serverFailure)
    }

    func testNonJSONBodyUsesTheEndpointFallbackAndNeverTheRawText() {
        let html = "<html><body><h1>502 Bad Gateway</h1>nginx/1.25.3 upstream crashed</body></html>"
        let error = parse(502, html)
        XCTAssertEqual(error.errorDescription, fallback)
        XCTAssertFalse(error.errorDescription?.contains("nginx") ?? true)
        XCTAssertEqual(error.statusCode, 502)
    }

    func testNonJSON401UsesTheEndpointFallbackNotTheSessionHint() {
        let error = parse(401, "Unauthorized by proxy")
        XCTAssertEqual(error.errorDescription, fallback)
    }

    func testEmptyBodyUsesTheEndpointFallback() {
        XCTAssertEqual(parse(500, "").errorDescription, fallback)
    }

    func testAServerMessageIsUsedAsSentEvenWhenEmpty() {
        XCTAssertEqual(parse(400, #"{"message":"","detail":{"message":"nested"}}"#).errorDescription, "")
        XCTAssertEqual(parse(400, #"{"message":null,"detail":{"message":"nested"}}"#).errorDescription, "nested")
        XCTAssertEqual(parse(404, #"{"detail":""}"#).errorDescription, "")
    }

    func testKeepsShouldRequestNew() {
        let expired = APIErrorParser.parse(status: 400, data: Data(#"{"message":"Expired","should_request_new":true}"#.utf8), fallback: fallback)
        XCTAssertEqual(expired.shouldRequestNew, true)
        XCTAssertEqual(expired.message, "Expired")
        XCTAssertNil(APIErrorParser.parse(status: 400, data: Data(#"{"message":"Wrong"}"#.utf8), fallback: fallback).shouldRequestNew)
    }

    func testStatusCodeIsKeptForAStatusTheSDKNeverMapped() {
        let error = parse(410, #"{"message":"Session gone."}"#)
        XCTAssertEqual(error.statusCode, 410)
        XCTAssertEqual(error.errorDescription, "Session gone.")
    }
}
