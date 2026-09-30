import XCTest
@testable import RedactoConsentSDK

final class AssistedFlowTests: XCTestCase {
    func testAcceptsATenDigitMobileOnly() {
        XCTAssertTrue(AssistedFlow.isValidMobile("9876543210"))
        XCTAssertFalse(AssistedFlow.isValidMobile("987654321"))
        XCTAssertFalse(AssistedFlow.isValidMobile("98765432101"))
        XCTAssertFalse(AssistedFlow.isValidMobile("98765 4321"))
    }

    func testSanitizesAMobileToItsFirstTenDigits() {
        XCTAssertEqual(AssistedFlow.sanitizeMobile("+91 98765-43210 9"), "9198765432")
        XCTAssertEqual(AssistedFlow.sanitizeMobile("98765-43210"), "9876543210")
        XCTAssertEqual(AssistedFlow.sanitizeMobile("abc"), "")
    }

    func testAcceptsADottedDomainEmailOnly() {
        XCTAssertTrue(AssistedFlow.isValidEmail("user@example.com"))
        XCTAssertTrue(AssistedFlow.isValidEmail("  user@example.com "))
        XCTAssertFalse(AssistedFlow.isValidEmail("not-an-email"))
        XCTAssertFalse(AssistedFlow.isValidEmail("user@example"))
        XCTAssertFalse(AssistedFlow.isValidEmail("us er@example.com"))
    }

    func testNeedsAFullNumericCode() {
        XCTAssertEqual(AssistedFlow.sanitizeOtp("12-34 56 78"), "123456")
        XCTAssertEqual(AssistedFlow.digits(of: "1234"), ["1", "2", "3", "4", "", ""])
        XCTAssertTrue(OtpCodeEntry.isComplete(AssistedFlow.digits(of: "123456")))
        XCTAssertFalse(OtpCodeEntry.isComplete(AssistedFlow.digits(of: "12345")))
    }

    func testRecipientAndChannelFollowTheMethod() {
        XCTAssertEqual(AssistedFlow.otpRecipient(.mobile, mobile: "9876543210", email: "x@y.z"), "+919876543210")
        XCTAssertEqual(AssistedFlow.otpRecipient(.email, mobile: "9876543210", email: " user@example.com "), "user@example.com")
        XCTAssertEqual(AssistedFlow.otpChannel(.mobile), "sms")
        XCTAssertEqual(AssistedFlow.otpChannel(.email), "email")
    }

    func testLocalizesVerifyFailuresByStatusNotServerText() {
        let incorrect = AssistedAPIError(status: 400, code: "OTP_INVALID", message: "server copy", shouldRequestNew: false)
        let expired = AssistedAPIError(status: 400, code: "OTP_EXPIRED", message: "server copy", shouldRequestNew: true)
        let missing = AssistedAPIError(status: 404, code: "OTP_NOT_FOUND", message: "server copy", shouldRequestNew: true)
        let broken = AssistedAPIError(status: 500, code: nil, message: "server copy", shouldRequestNew: false)
        XCTAssertEqual(AssistedFlow.verifyErrorMessage(incorrect), AssistedI18n(language: "English")(.otpIncorrect))
        XCTAssertEqual(AssistedFlow.verifyErrorMessage(expired), AssistedI18n(language: "English")(.otpExpired))
        XCTAssertEqual(AssistedFlow.verifyErrorMessage(missing), AssistedI18n(language: "English")(.otpNotFound))
        XCTAssertEqual(AssistedFlow.verifyErrorMessage(broken), AssistedI18n(language: "English")(.otpVerifyFailed))
        XCTAssertEqual(AssistedFlow.verifyErrorMessage(URLError(.notConnectedToInternet)), AssistedI18n(language: "English")(.otpVerifyFailed))
    }

    func testTreatsOnlyAnAlreadyProvidedConflictAsDone() {
        XCTAssertTrue(AssistedFlow.isConsentAlreadyProvided(RedactoAPIError.alreadyConsented))
        XCTAssertTrue(AssistedFlow.isConsentAlreadyProvided(RedactoAPIError.api(status: 409, code: nil, message: "")))
        XCTAssertTrue(AssistedFlow.isConsentAlreadyProvided(RedactoAPIError.api(status: 400, code: "CONSENT_ALREADY_PROVIDED", message: "")))
        XCTAssertFalse(AssistedFlow.isConsentAlreadyProvided(AssistedAPIError(status: 409, code: nil, message: "", shouldRequestNew: false)))
        XCTAssertFalse(AssistedFlow.isConsentAlreadyProvided(RedactoAPIError.serverError))
        XCTAssertFalse(AssistedFlow.isConsentAlreadyProvided(RedactoAPIError.validationError("no")))
    }

    func testParsesTheServerErrorBody() {
        let otp = AssistedAPI.parseError(
            status: 400,
            data: Data(#"{"message":"Expired","should_request_new":true,"error_code":"OTP_EXPIRED"}"#.utf8),
            fallback: "fallback"
        )
        XCTAssertEqual(otp, AssistedAPIError(status: 400, code: "OTP_EXPIRED", message: "Expired", shouldRequestNew: true))

        let nested = AssistedAPI.parseError(
            status: 409,
            data: Data(#"{"detail":{"message":"Already","error_code":"CONSENT_ALREADY_PROVIDED"}}"#.utf8),
            fallback: "fallback"
        )
        XCTAssertEqual(nested.message, "Already")
        XCTAssertEqual(nested.code, "CONSENT_ALREADY_PROVIDED")

        let plain = AssistedAPI.parseError(status: 422, data: Data(#"{"detail":"Bad input"}"#.utf8), fallback: "fallback")
        XCTAssertEqual(plain.message, "Bad input")
    }

    func testNeverSurfacesARawNonJSONBody() {
        let error = AssistedAPI.parseError(status: 502, data: Data("<html>Bad gateway</html>".utf8), fallback: "fallback")
        XCTAssertEqual(error.message, "fallback")
        XCTAssertEqual(error.status, 502)
    }

    func testFallsBackToTheStatusCopyForAJSONBodyWithoutAMessage() {
        XCTAssertEqual(AssistedAPI.parseError(status: 503, data: Data("{}".utf8), fallback: "fallback").message, APIStatusFallback.serverFailure)
        XCTAssertEqual(AssistedAPI.parseError(status: 401, data: Data("{}".utf8), fallback: "fallback").message, APIStatusFallback.unauthorized)
        XCTAssertEqual(AssistedAPI.parseError(status: 400, data: Data("{}".utf8), fallback: "fallback").message, "fallback")
    }
}
