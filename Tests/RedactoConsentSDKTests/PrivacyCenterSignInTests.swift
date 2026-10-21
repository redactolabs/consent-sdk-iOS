import XCTest
@testable import RedactoConsentSDK

/// Port of the React SDK's `SignIn/contact.test.ts`, `otpErrors.test.ts` and
/// `inactivityTimer.test.ts`, plus the public routes behind them.
final class PrivacyCenterSignInTests: XCTestCase {
    private typealias Contact = PrivacyCenterSignInContact

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    // MARK: - Contact

    func testReadsTheChannelWithBothOn() {
        let cases: [(String, Contact.Channel?)] = [
            ("jane@example.com", .email),
            ("Jane", .email),
            ("98765 43210", .sms),
            ("+44 20 7946 0958", .sms),
            ("", nil),
            ("#!", nil),
        ]
        for (value, channel) in cases {
            XCTAssertEqual(Contact.detectChannel(value, channels: .both), channel, value)
        }
    }

    func testIsTheOnlyChannelOnWhenThereIsOne() {
        XCTAssertEqual(Contact.detectChannel("9876543210", channels: .email), .email)
        XCTAssertEqual(Contact.detectChannel("jane@example.com", channels: .sms), .sms)
    }

    func testNormalisesEmailsAndNumbers() {
        XCTAssertEqual(Contact.normalize("  Jane@Example.COM ", channel: .email, countryCode: "+91"), "jane@example.com")
        XCTAssertEqual(Contact.normalize("98765 43210", channel: .sms, countryCode: "+91"), "+919876543210")
        XCTAssertEqual(Contact.normalize("07946 095800", channel: .sms, countryCode: "+44"), "+447946095800")
        XCTAssertEqual(Contact.normalize("+65 9123 4567", channel: .sms, countryCode: "+91"), "+6591234567")
        XCTAssertEqual(Contact.normalize("0065 9123 4567", channel: .sms, countryCode: "+91"), "+6591234567")
    }

    func testValidatesAContact() {
        let cases: [(String, Contact.Channel, Bool)] = [
            ("jane@example.com", .email, true),
            ("jane@example", .email, false),
            ("jane..doe@example.com", .email, false),
            ("+919876543210", .sms, true),
            ("+911234567890", .sms, false),
            ("+9198765", .sms, false),
            ("+6591234567", .sms, true),
            ("12345", .sms, false),
        ]
        for (contact, channel, valid) in cases {
            XCTAssertEqual(Contact.isValid(contact, channel: channel), valid, contact)
        }
    }

    func testMasksAPhoneToItsCodeAndLastFourDigits() {
        XCTAssertEqual(Contact.maskPhone("+919876543210"), "+91XXXXXX3210")
        XCTAssertEqual(Contact.maskPhone("1234"), "1234")
    }

    func testNamesEachOtpFailure() {
        XCTAssertEqual(Contact.errorKey(code: "OTP_EXPIRED", status: 400), "otpErrorExpired")
        XCTAssertEqual(Contact.errorKey(code: "RATE_LIMIT_EXCEEDED", status: 429), "otpErrorRateLimit")
        XCTAssertEqual(Contact.errorKey(code: nil, status: 422), "otpErrorInvalidContact")
        XCTAssertEqual(Contact.errorKey(code: nil, status: 503), "otpErrorSendFailed")
        XCTAssertEqual(Contact.errorKey(code: nil, status: nil), "otpErrorFallback")
        XCTAssertEqual(PCStrings.t("otpErrorExpired"), "Your code has expired. Please request a new one.")
    }

    // MARK: - Inactivity

    private let minute: TimeInterval = 60
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFiresOnceAfterTheTimeoutWithNoActivity() {
        var clock = PrivacyCenterInactivityClock(timeout: 15 * minute, now: start)
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(15 * minute - 1)), .wait(1))
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(15 * minute)), .fire)
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(75 * minute)), .done)
    }

    func testCountsTheIdleTimeFromTheLastActivity() {
        var clock = PrivacyCenterInactivityClock(timeout: 15 * minute, now: start)
        clock.activity(at: start.addingTimeInterval(10 * minute))
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(20 * minute)), .wait(5 * minute))
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(25 * minute)), .fire)
    }

    func testSignsOutAtOnceOnReturnWhenTheAppSleptPastTheDeadline() {
        var clock = PrivacyCenterInactivityClock(timeout: 15 * minute, now: start)
        XCTAssertEqual(clock.resume(at: start.addingTimeInterval(20 * minute)), .fire)
    }

    func testTreatsComingBackInTimeAsActivity() {
        var clock = PrivacyCenterInactivityClock(timeout: 15 * minute, now: start)
        XCTAssertEqual(clock.resume(at: start.addingTimeInterval(14 * minute)), .wait(15 * minute))
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(28 * minute)), .wait(minute))
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(29 * minute)), .fire)
    }

    func testActivityAfterTheSignOutChangesNothing() {
        var clock = PrivacyCenterInactivityClock(timeout: minute, now: start)
        XCTAssertEqual(clock.check(at: start.addingTimeInterval(minute)), .fire)
        clock.activity(at: start.addingTimeInterval(2 * minute))
        XCTAssertEqual(clock.resume(at: start.addingTimeInterval(3 * minute)), .done)
    }

    // MARK: - Public routes

    func testCreatesACodeBySmsAndVerifiesItForLogin() async throws {
        TransportStubProtocol.install { request in
            if request.path.hasSuffix("/otp/create") {
                return .json(200, ["code": 200, "status": "success", "detail": ["uuid": "otp-1", "success": true]])
            }
            return .json(200, ["access_token": "access", "refresh_token": "refresh", "success": true])
        }
        let otpId = try await PrivacyCenterPublicAPI.createOtp(
            baseUrl: "https://api.test/consent/", organisationUuid: "org-1", workspaceUuid: "ws-1", to: "+919876543210", channel: .sms
        )
        let tokens = try await PrivacyCenterPublicAPI.verifyOtp(
            baseUrl: "https://api.test/consent", organisationUuid: "org-1", workspaceUuid: "ws-1", otpId: otpId, code: "123456"
        )

        XCTAssertEqual(otpId, "otp-1")
        XCTAssertEqual(tokens, PrivacyCenterSignInTokens(accessToken: "access", refreshToken: "refresh"))
        let requests = TransportStubProtocol.requests
        XCTAssertEqual(requests[0].url.absoluteString, "https://api.test/consent/public/organisations/org-1/workspaces/ws-1/otp/create")
        XCTAssertEqual(requests[0].jsonBody?["to"] as? String, "+919876543210")
        XCTAssertEqual(requests[0].jsonBody?["channel"] as? String, "sms")
        XCTAssertEqual(requests[1].jsonBody?["purpose"] as? String, "login")
        XCTAssertEqual(requests[1].jsonBody?["uuid"] as? String, "otp-1")
        XCTAssertNil(requests[1].header("Authorization"))
    }

    func testKeepsTheOtpRoutesErrorCode() async {
        TransportStubProtocol.install { _ in .json(429, ["error_code": "RATE_LIMIT_EXCEEDED", "message": "slow down"]) }
        do {
            _ = try await PrivacyCenterPublicAPI.createOtp(
                baseUrl: "https://api.test/consent", organisationUuid: "org-1", workspaceUuid: "ws-1", to: "a@b.co", channel: .email
            )
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? PrivacyCenterSignInError, PrivacyCenterSignInError(status: 429, code: "RATE_LIMIT_EXCEEDED"))
        }
    }

    func testRefusesAVerifyWithoutATokenOrMarkedUnsuccessful() async {
        TransportStubProtocol.install { _ in .json(200, ["success": false, "access_token": "x"]) }
        do {
            _ = try await PrivacyCenterPublicAPI.verifyOtp(
                baseUrl: "https://api.test/consent", organisationUuid: "org-1", workspaceUuid: "ws-1", otpId: "otp-1", code: "123456"
            )
            XCTFail("expected a failure")
        } catch {
            XCTAssertTrue(error is PrivacyCenterSignInError)
        }
    }
}
