import XCTest
@testable import RedactoConsentSDK

final class AssistedNoticeViewModelTests: XCTestCase {
    private typealias F = InlineFixtures
    private let base = "https://api.example.test/consent"
    private let ledger = "https://ledger.example.test/consent-ledger"

    private let created = TransportStubResponse.text(
        201,
        #"{"code":201,"status":"success","detail":{"uuid":"otp-1","to":"+919876543210","channel":"sms","expire_at":"2026-06-24T09:55:34Z","success":true,"message":"OTP created successfully"}}"#
    )
    private let verified = TransportStubResponse.text(
        200,
        #"{"code":200,"status":"success","detail":{"token":null,"access_token":"access-token-1","refresh_token":"refresh-1","expires_in":3600,"token_type":"Bearer","success":true,"message":"OTP verified successfully"}}"#
    )

    private var singleProduct: ActiveConfig {
        F.config(products: nil, purposes: [
            F.purpose("p-account", nil, [F.element("e-email", required: true), F.element("e-phone")]),
            F.purpose("p-identity", nil, [F.element("e-govid", required: true)]),
        ])
    }

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    private func install(
        _ config: ActiveConfig,
        create: TransportStubResponse? = nil,
        verify: TransportStubResponse? = nil,
        check: TransportStubResponse = .text(404, "{}"),
        submit: TransportStubResponse = .text(201, "{}")
    ) {
        RouteStub.install([
            "get-notice": [F.noticeResponse(config)],
            "otp/create": [create ?? created],
            "otp/verify": [verify ?? verified],
            "check-consent": [check],
            "submit-consent": [submit],
        ])
    }

    @MainActor
    private func loaded(ledgerBaseUrl: String? = nil, counter: FlowCounter) async -> AssistedNoticeViewModel {
        let viewModel = AssistedNoticeViewModel(
            organisationUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            baseUrl: base,
            ledgerBaseUrl: ledgerBaseUrl,
            onComplete: { counter.completes += 1 },
            onDecline: { counter.declines += 1 },
            onError: { _ in counter.errors += 1 }
        )
        await viewModel.load().value
        return viewModel
    }

    @MainActor
    private func tickEveryRequired(_ viewModel: AssistedNoticeViewModel) {
        viewModel.handlePurposeToggle("p-account")
        viewModel.handlePurposeToggle("p-identity")
    }

    @MainActor
    private func reachCodeEntry(_ viewModel: AssistedNoticeViewModel) async {
        viewModel.setMobile("9876543210")
        await viewModel.sendOtp()?.value
    }

    @MainActor
    private func confirm(_ viewModel: AssistedNoticeViewModel) async {
        viewModel.setOtpCode("123456")
        await viewModel.confirmOtp()?.value
    }

    private func submittedPurposes() -> [[String: Any]] {
        (RouteStub.requests(matching: "submit-consent").first?.json["purposes"] as? [[String: Any]]) ?? []
    }

    @MainActor
    func testFetchesThePublicNoticeWithNoAuthorization() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())

        let request = RouteStub.requests(matching: "get-notice").first
        XCTAssertEqual(request?.url.absoluteString, "\(base)/public/organisations/org-1/workspaces/ws-1/notices/get-notice/ntc-1")
        XCTAssertNil(request?.header("Authorization"))
        XCTAssertNotNil(viewModel.activeConfig)
        XCTAssertEqual(viewModel.step, .notice)
    }

    @MainActor
    func testAcceptSelectedStaysBlockedUntilEveryRequiredElementIsTicked() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())

        XCTAssertTrue(viewModel.isPrimaryDisabled)
        viewModel.handlePurposeToggle("p-account")
        viewModel.acceptSelected()
        XCTAssertEqual(viewModel.step, .notice)

        viewModel.handlePurposeToggle("p-identity")
        XCTAssertFalse(viewModel.isPrimaryDisabled)
        viewModel.acceptSelected()
        XCTAssertEqual(viewModel.step, .verify)
    }

    @MainActor
    func testADisabledRequiredElementHoldsAcceptUntilItsPurposeIsTicked() async {
        install(F.config(products: nil, purposes: [
            F.purpose("p-legacy", nil, [F.element("e-legacy", required: true, enabled: false), F.element("e-segment")]),
        ]))
        let viewModel = await loaded(counter: FlowCounter())

        XCTAssertTrue(viewModel.isPrimaryDisabled)
        viewModel.handlePurposeToggle("p-legacy")
        XCTAssertEqual(viewModel.selectedDataElements["p-legacy-e-legacy"], true)
        XCTAssertFalse(viewModel.isPrimaryDisabled)
        viewModel.acceptSelected()
        XCTAssertEqual(viewModel.step, .verify)
    }

    @MainActor
    func testAMultiProductNoticeIsOneFlatListKeyedPerPurposeInProductOrder() async {
        install(F.multiProduct)
        let viewModel = await loaded(counter: FlowCounter())

        XCTAssertEqual(viewModel.displayedPurposes.map(\.uuid), ["pur-shared", "pur-scoped-a", "pur-wide", "pur-only-b"])
        XCTAssertEqual(viewModel.collapsedPurposes["pur-shared"], true)
        XCTAssertNil(viewModel.collapsedPurposes["\(F.productA):pur-shared"])

        viewModel.handlePurposeToggle("pur-shared")
        XCTAssertTrue(viewModel.isPrimaryDisabled)
        viewModel.handlePurposeToggle("pur-scoped-a")
        XCTAssertTrue(viewModel.isPrimaryDisabled, "pur-wide's disabled required element still holds the gate")
        viewModel.handlePurposeToggle("pur-wide")
        XCTAssertFalse(viewModel.isPrimaryDisabled)
        XCTAssertEqual(viewModel.selectedPurposes["pur-shared"], true)
    }

    @MainActor
    func testAPurposeCoveringNoProductIsHiddenAndDoesNotHoldTheGate() async {
        let gone = F.purpose("pur-gone", ["prod-gone"], [F.element("el-gone", required: true)])
        install(F.config(products: F.twoProducts, purposes: [F.onlyB, gone]))
        let viewModel = await loaded(counter: FlowCounter())

        XCTAssertEqual(viewModel.displayedPurposes.map(\.uuid), ["pur-only-b"])
        XCTAssertFalse(viewModel.isPrimaryDisabled)
    }

    @MainActor
    func testSeedsAndReplaysTheNoticesPreselection() async {
        var config = singleProduct
        config.purposePreselection = "MANDATORY"
        install(config)
        let viewModel = AssistedNoticeViewModel(organisationUuid: "org-1", workspaceUuid: "ws-1", noticeUuid: "ntc-1", baseUrl: base)
        await viewModel.load().value

        XCTAssertEqual(viewModel.selectedPurposes["p-account"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-email"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-phone"], false)
        XCTAssertFalse(viewModel.isPrimaryDisabled)

        viewModel.handlePurposeToggle("p-account")
        XCTAssertTrue(viewModel.isPrimaryDisabled)
        viewModel.decline()

        XCTAssertEqual(viewModel.selectedPurposes["p-account"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-email"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-phone"], false)
    }

    @MainActor
    func testAllPreselectionTicksEveryEnabledElement() async {
        var config = F.config(products: nil, purposes: [
            F.purpose("p-account", nil, [F.element("e-email", required: true), F.element("e-fax", enabled: false)]),
        ])
        config.purposePreselection = "ALL"
        install(config)
        let viewModel = await loaded(counter: FlowCounter())

        XCTAssertEqual(viewModel.selectedPurposes["p-account"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-email"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-fax"], false)
    }

    @MainActor
    func testLocksTheSelectionsOnceVerificationOpens() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()

        viewModel.handlePurposeToggle("p-account")
        viewModel.handleDataElementToggle("e-phone", purposeUuid: "p-account")

        XCTAssertEqual(viewModel.selectedPurposes["p-account"], true)
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-phone"], true)
    }

    @MainActor
    func testEditSelectionsReopensTheNoticeAndDropsTheContact() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        viewModel.setMobile("9876543210")

        viewModel.editSelections()

        XCTAssertEqual(viewModel.step, .notice)
        XCTAssertEqual(viewModel.mobile, "")
        viewModel.handleDataElementToggle("e-phone", purposeUuid: "p-account")
        XCTAssertEqual(viewModel.selectedDataElements["p-account-e-phone"], false)
    }

    @MainActor
    func testSendOtpNeedsAValidMobile() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()

        viewModel.setMobile("12345")
        XCTAssertEqual(viewModel.primaryAction, .sendOtp)
        XCTAssertTrue(viewModel.isPrimaryDisabled)
        XCTAssertNil(viewModel.sendOtp())
        XCTAssertTrue(RouteStub.requests(matching: "otp/create").isEmpty)

        viewModel.setMobile("98765-43210")
        XCTAssertEqual(viewModel.mobile, "9876543210")
        XCTAssertFalse(viewModel.isPrimaryDisabled)
        await viewModel.sendOtp()?.value

        let body = RouteStub.requests(matching: "otp/create").first?.json
        XCTAssertEqual(body?["to"] as? String, "+919876543210")
        XCTAssertEqual(body?["channel"] as? String, "sms")
        XCTAssertTrue(viewModel.otpSent)
        XCTAssertEqual(viewModel.otpUuid, "otp-1")
        XCTAssertEqual(viewModel.resendCountdown, AssistedConfig.resendSeconds)
        XCTAssertEqual(viewModel.primaryAction, .confirmOtp)
    }

    @MainActor
    func testSendOtpByEmailNeedsAValidAddress() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        viewModel.selectMethod(.email)

        viewModel.setEmail("not-an-email")
        XCTAssertTrue(viewModel.isPrimaryDisabled)
        XCTAssertNil(viewModel.sendOtp())

        viewModel.setEmail("user@example.com")
        XCTAssertFalse(viewModel.isPrimaryDisabled)
        await viewModel.sendOtp()?.value

        let body = RouteStub.requests(matching: "otp/create").first?.json
        XCTAssertEqual(body?["to"] as? String, "user@example.com")
        XCTAssertEqual(body?["channel"] as? String, "email")
        XCTAssertEqual(viewModel.otpRecipientLabel, "user@example.com")
    }

    @MainActor
    func testAFailedSendShowsTheLocalizedCopyAndStaysOnContactEntry() async {
        install(singleProduct, create: .text(503, #"{"message":"SMS provider down"}"#))
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)

        XCTAssertEqual(viewModel.createError, AssistedI18n(language: "English")(.otpSendFailed))
        XCTAssertFalse(viewModel.otpSent)
    }

    @MainActor
    func testConfirmNeedsAFullCodeThenVerifiesAndSubmitsUnderTheVerifiedToken() async {
        install(singleProduct)
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)

        viewModel.setOtpCode("123")
        XCTAssertTrue(viewModel.isPrimaryDisabled)
        XCTAssertNil(viewModel.confirmOtp())
        XCTAssertTrue(RouteStub.requests(matching: "otp/verify").isEmpty)

        viewModel.setOtpCode("12a3456")
        XCTAssertEqual(viewModel.otpCode, "123456")
        await viewModel.confirmOtp()?.value

        let verify = RouteStub.requests(matching: "otp/verify").first?.json
        XCTAssertEqual(verify?["uuid"] as? String, "otp-1")
        XCTAssertEqual(verify?["otp"] as? String, "123456")
        XCTAssertEqual(verify?["purpose"] as? String, "login")

        let submit = RouteStub.requests(matching: "submit-consent").first
        XCTAssertEqual(submit?.url.absoluteString, "\(base)/public/organisations/org-1/workspaces/ws-1/submit-consent")
        XCTAssertEqual(submit?.header("Authorization"), "Bearer access-token-1")
        XCTAssertEqual(submittedPurposes().map { $0["selected"] as? Bool }, [true, true])
        XCTAssertTrue(submittedPurposes().allSatisfy { $0["product_uuid"] == nil })
        XCTAssertEqual(counter.completes, 1)
        XCTAssertTrue(RouteStub.requests(matching: "check-consent").isEmpty)
    }

    @MainActor
    func testTheCodeCannotBeEnteredBeforeItIsSent() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()

        viewModel.setOtpCode("123456")

        XCTAssertEqual(viewModel.otpCode, "")
        XCTAssertNil(viewModel.confirmOtp())
    }

    @MainActor
    func testAnIncorrectCodeIsLocalizedAndNeverSubmits() async {
        await assertVerifyFailure(.text(400, #"{"message":"incorrect (server copy)","should_request_new":false,"error_code":"OTP_INVALID"}"#), AssistedI18n(language: "English")(.otpIncorrect))
    }

    @MainActor
    func testAnExpiredCodeIsLocalizedAndNeverSubmits() async {
        await assertVerifyFailure(.text(400, #"{"message":"expired (server copy)","should_request_new":true,"error_code":"OTP_EXPIRED"}"#), AssistedI18n(language: "English")(.otpExpired))
    }

    @MainActor
    func testAMissingCodeIsLocalizedAndNeverSubmits() async {
        await assertVerifyFailure(.text(404, #"{"message":"not found (server copy)","should_request_new":true}"#), AssistedI18n(language: "English")(.otpNotFound))
    }

    @MainActor
    private func assertVerifyFailure(_ response: TransportStubResponse, _ expected: String) async {
        install(singleProduct, verify: response)
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(viewModel.otpError, expected)
        XCTAssertTrue(RouteStub.requests(matching: "submit-consent").isEmpty)
        XCTAssertEqual(counter.completes, 0)
        XCTAssertFalse(viewModel.isVerifying)
    }

    @MainActor
    func testAnAlreadyConsentedConflictCompletesWithNoError() async {
        install(singleProduct, submit: .text(409, #"{"message":"You have already provided consent for this notice."}"#))
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(counter.completes, 1)
        XCTAssertNil(viewModel.otpError)
    }

    @MainActor
    func testAFailedSubmitShowsTheLocalizedCopyNotTheServerText() async {
        install(singleProduct, submit: .text(422, #"{"message":"server-side validation text"}"#))
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(viewModel.otpError, AssistedI18n(language: "English")(.otpVerifyFailed))
        XCTAssertEqual(counter.completes, 0)
    }

    @MainActor
    func testAFullyConsentedPrincipalOnTheLedgerCompletesWithoutASubmit() async {
        install(singleProduct, check: .text(200, #"{"consented":true,"all_mandatory_active":true,"purposes":[]}"#))
        let counter = FlowCounter()
        let viewModel = await loaded(ledgerBaseUrl: ledger, counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        let check = RouteStub.requests(matching: "check-consent").first
        XCTAssertEqual(check?.url.absoluteString, "\(ledger)/public/organisations/org-1/workspaces/ws-1/notices/ntc-1/check-consent")
        XCTAssertEqual(check?.header("Authorization"), "Bearer access-token-1")
        XCTAssertTrue(RouteStub.requests(matching: "submit-consent").isEmpty)
        XCTAssertEqual(counter.completes, 1)
    }

    @MainActor
    func testANotYetConsentedPrincipalSubmitsThroughTheLedger() async {
        install(singleProduct, check: .text(200, #"{"consented":true,"all_mandatory_active":false,"purposes":[]}"#))
        let counter = FlowCounter()
        let viewModel = await loaded(ledgerBaseUrl: ledger, counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        let submit = RouteStub.requests(matching: "submit-consent").first
        XCTAssertEqual(submit?.url.absoluteString, "\(ledger)/public/organisations/org-1/workspaces/ws-1/submit-consent")
        XCTAssertEqual(counter.completes, 1)
    }

    private var incorrect: TransportStubResponse {
        .text(400, #"{"message":"incorrect","should_request_new":false,"error_code":"OTP_INVALID"}"#)
    }

    private func installRetry() {
        RouteStub.install([
            "get-notice": [F.noticeResponse(singleProduct)],
            "otp/create": [created],
            "otp/verify": [verified, incorrect],
            "check-consent": [.text(404, "{}")],
            "submit-consent": [.text(503, #"{"message":"busy"}"#), .text(201, "{}")],
        ])
    }

    @MainActor
    func testARetryAfterAFailedSubmitResubmitsUnderTheVerifiedTokenWithoutReverifying() async {
        installRetry()
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)
        XCTAssertEqual(viewModel.otpError, AssistedI18n(language: "English")(.otpVerifyFailed))
        XCTAssertEqual(counter.completes, 0)

        await confirm(viewModel)

        XCTAssertEqual(RouteStub.requests(matching: "otp/verify").count, 1)
        let submits = RouteStub.requests(matching: "submit-consent")
        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(submits.last?.header("Authorization"), "Bearer access-token-1")
        XCTAssertNil(viewModel.otpError)
        XCTAssertEqual(counter.completes, 1)
    }

    @MainActor
    func testANewCodeSessionVerifiesAgainAfterAFailedSubmit() async {
        installRetry()
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        viewModel.changeContact()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(RouteStub.requests(matching: "otp/verify").count, 2)
        XCTAssertEqual(RouteStub.requests(matching: "submit-consent").count, 1)
        XCTAssertEqual(viewModel.otpError, AssistedI18n(language: "English")(.otpIncorrect))
        XCTAssertEqual(counter.completes, 0)
    }

    @MainActor
    func testChangingTheContactDiscardsTheCodeSession() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        viewModel.setOtpCode("12")

        viewModel.changeContact()

        XCTAssertFalse(viewModel.otpSent)
        XCTAssertEqual(viewModel.otpUuid, "")
        XCTAssertEqual(viewModel.otpCode, "")
        XCTAssertEqual(viewModel.resendCountdown, 0)
        XCTAssertEqual(viewModel.primaryAction, .sendOtp)
        XCTAssertNil(viewModel.confirmOtp())
    }

    @MainActor
    func testAcceptAllSkipsTheGateAndSubmitsEveryEnabledElement() async {
        install(F.config(products: nil, purposes: [
            F.purpose("p-account", nil, [F.element("e-email", required: true), F.element("e-phone"), F.element("e-fax", enabled: false)]),
        ]))
        let viewModel = await loaded(counter: FlowCounter())

        viewModel.acceptAll()
        XCTAssertEqual(viewModel.step, .verify)
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(
            sortedJSONObject(submittedPurposes()),
            #"[{"data_elements":[{"selected":true,"uuid":"e-email"},{"selected":true,"uuid":"e-phone"}],"purpose_uuid":"p-account","selected":true}]"#
        )
    }

    @MainActor
    func testAMultiProductSubmitIsFlatInTheConfigsOrderWithNoProduct() async {
        install(F.multiProduct)
        let viewModel = await loaded(counter: FlowCounter())
        viewModel.handlePurposeToggle("pur-shared")
        viewModel.handlePurposeToggle("pur-scoped-a")
        viewModel.handlePurposeToggle("pur-wide")
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        let sent = submittedPurposes()
        XCTAssertEqual(sent.map { $0["purpose_uuid"] as? String }, ["pur-shared", "pur-scoped-a", "pur-only-b", "pur-wide"])
        XCTAssertEqual(sent.map { $0["selected"] as? Bool }, [true, true, false, true])
        XCTAssertTrue(sent.allSatisfy { $0["product_uuid"] == nil })
    }

    @MainActor
    func testTheSubmitCarriesTheNoticeLanguageAsABcp47Code() async {
        install(F.config(products: nil, purposes: singleProduct.purposes, defaultLanguage: "Punjabi"))
        let viewModel = await loaded(counter: FlowCounter())
        XCTAssertEqual(viewModel.selectedLanguage, "Punjabi")
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(RouteStub.requests(matching: "submit-consent").first?.json["language"] as? String, "pa")
    }

    @MainActor
    func testTheSubmitCarriesEnglishByDefault() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        XCTAssertEqual(viewModel.selectedLanguage, "English")
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)
        await confirm(viewModel)

        XCTAssertEqual(RouteStub.requests(matching: "submit-consent").first?.json["language"] as? String, "en")
    }

    @MainActor
    func testFlowCopyFollowsTheNoticeLanguage() async {
        install(singleProduct, create: .text(503, "{}"))
        let viewModel = await loaded(counter: FlowCounter())
        viewModel.selectLanguage("Hindi")
        tickEveryRequired(viewModel)
        viewModel.acceptSelected()
        await reachCodeEntry(viewModel)

        XCTAssertEqual(viewModel.createError, AssistedI18n(language: "hi")(.otpSendFailed))
        XCTAssertNotEqual(viewModel.createError, AssistedI18n(language: "English")(.otpSendFailed))
    }

    @MainActor
    func testANewIdentityReadsTheNewNotice() async {
        install(singleProduct)
        let viewModel = await loaded(counter: FlowCounter())
        XCTAssertNil(viewModel.updateIdentity(viewModel.identity))

        await viewModel.updateIdentity(AssistedNoticeIdentity(
            organisationUuid: "org-2", workspaceUuid: "ws-2", noticeUuid: "ntc-2", baseUrl: base
        ))?.value

        XCTAssertEqual(
            RouteStub.requests(matching: "get-notice").last?.url.absoluteString,
            "\(base)/public/organisations/org-2/workspaces/ws-2/notices/get-notice/ntc-2"
        )
        XCTAssertEqual(RouteStub.requests(matching: "get-notice").count, 2)
    }

    @MainActor
    func testDeclineHandsOffToTheHost() async {
        install(singleProduct)
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        viewModel.decline()

        XCTAssertEqual(counter.declines, 1)
        XCTAssertTrue(RouteStub.requests(matching: "submit-consent").isEmpty)
    }

    @MainActor
    func testALoadFailureSurfacesTheServerMessage() async {
        RouteStub.install(["get-notice": [.text(404, #"{"detail":{"message":"Notice not found","error_code":"NOTICE_NOT_FOUND"}}"#)]])
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        XCTAssertNil(viewModel.activeConfig)
        XCTAssertEqual(viewModel.fetchErrorMessage, "Notice not found")
        XCTAssertEqual(counter.errors, 1)
        XCTAssertFalse(viewModel.isLoading)
    }
}
