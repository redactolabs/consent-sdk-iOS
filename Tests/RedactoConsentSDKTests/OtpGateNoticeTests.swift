import XCTest
@testable import RedactoConsentSDK

final class OtpGateNoticeTests: XCTestCase {
    private let code = "320005"

    override func setUp() {
        super.setUp()
        SubmitRecorder.start()
    }

    override func tearDown() {
        SubmitRecorder.stop()
        super.tearDown()
    }

    @MainActor
    private func verify(_ notice: NoticeUnderTest, code: String? = nil) async {
        notice.vm.updateOtpDigits(digitsOf(code ?? self.code))
        await notice.vm.confirmOtp()
    }

    @MainActor
    private func swapToken(_ notice: NoticeUnderTest, _ token: String) async {
        notice.vm.handleAccessTokenChange(token)
        await waitUntil { !SubmitRecorder.submits.isEmpty }
        await settle()
    }

    @MainActor
    func testAcceptAllSubmitsNothingOpensThePanelAndLocksThePurposes() async {
        let spy = VerifierSpy()
        let notice = makeNotice(otpGate: spy.gate())
        XCTAssertFalse(notice.vm.otpLocked)

        notice.vm.handleAccept(mode: .all)
        await settle()

        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
        XCTAssertEqual(notice.accepts.count, 0)
        XCTAssertTrue(notice.vm.otpLocked)
        XCTAssertEqual(notice.vm.otpPanel.pendingMode, .all)
        XCTAssertEqual(notice.vm.otpPanel.digits.count, 6)
        XCTAssertEqual(notice.vm.otpPanelTitle, OtpGateCopy.title)
        XCTAssertEqual(notice.vm.otpPanelDescription, OtpGateCopy.description)
    }

    @MainActor
    func testALockedPurposeAndElementDoNotToggle() {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handleAccept(mode: .all)

        notice.vm.handlePurposeToggle(NoticeFixtures.orders)
        notice.vm.handleDataElementToggle(NoticeFixtures.phone, purposeUuid: NoticeFixtures.orders)

        XCTAssertNotEqual(notice.vm.selectedPurposes[NoticeFixtures.orders], true)
        XCTAssertNotEqual(notice.vm.selectedDataElements["\(NoticeFixtures.orders)-\(NoticeFixtures.phone)"], true)
    }

    @MainActor
    func testTheLockAlsoHoldsProductSectionCheckboxes() {
        let content = NoticeFixtures.content(
            purposes: [NoticeProductFixtures.shared, NoticeProductFixtures.onlyA, NoticeProductFixtures.onlyB],
            config: ["products": NoticeProductFixtures.twoProducts()]
        )
        let notice = makeNotice(otpGate: VerifierSpy().gate(), content: content)
        notice.vm.handleAccept(mode: .all)

        notice.vm.handleProductCheckboxChange("prod-a")
        notice.vm.handleProductCheckboxChange("prod-b", to: true)
        notice.vm.handlePurposeToggle("purpose-only-a", productUuid: "prod-a")

        XCTAssertTrue(notice.vm.otpLocked)
        XCTAssertFalse(notice.vm.selectedPurposes.values.contains(true))
    }

    @MainActor
    func testTheSoleProductCheckboxIsHeldToo() {
        let content = NoticeFixtures.content(config: ["products": [NoticeProductFixtures.product("prod-a", "Product A", mandatory: nil)]])
        let notice = makeNotice(otpGate: VerifierSpy().gate(), content: content)
        notice.vm.handleAccept(mode: .all)

        notice.vm.handleSoleProductCheckboxChange()

        XCTAssertFalse(notice.vm.selectedPurposes.values.contains(true))
    }

    @MainActor
    func testAcceptSelectedIsHeldToo() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)

        notice.vm.handleAccept(mode: .selected)
        await settle()

        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
        XCTAssertEqual(notice.vm.otpPanel.pendingMode, .selected)
    }

    @MainActor
    func testUsesTheHostCopy() {
        let gate = VerifierSpy().gate(title: "Customer code", description: "Read it off their phone.", submitLabel: "Check code")
        let notice = makeNotice(otpGate: gate)
        notice.vm.handleAccept(mode: .all)

        XCTAssertEqual(notice.vm.otpPanelTitle, "Customer code")
        XCTAssertEqual(notice.vm.otpPanelDescription, "Read it off their phone.")
        XCTAssertEqual(notice.vm.otpPanelSubmitLabel, "Check code")
    }

    @MainActor
    func testSubmitsAcceptAllStraightAwayWithoutAGate() async {
        let notice = makeNotice()

        notice.vm.handleAccept(mode: .all)
        await waitUntil { notice.accepts.count == 1 }

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(notice.accepts.count, 1)
        XCTAssertFalse(notice.vm.otpLocked)
    }

    @MainActor
    func testSubmitsStraightAwayWhenTheGateIsNotRequired() async {
        let spy = VerifierSpy()
        let notice = makeNotice(otpGate: spy.gate(required: false))

        notice.vm.handleAccept(mode: .all)
        await waitUntil { notice.accepts.count == 1 }

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertFalse(notice.vm.otpLocked)
        XCTAssertTrue(spy.calls.isEmpty)
    }

    @MainActor
    func testSubmitsAcceptSelectedStraightAwayWhenTheGateIsNotRequired() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate(required: false))
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)

        notice.vm.handleAccept(mode: .selected)
        await waitUntil { notice.accepts.count == 1 }

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertFalse(notice.vm.otpLocked)
    }

    @MainActor
    func testSubmitsNothingOnTheSameTokenThenOneAcceptAllWithTheNewToken() async {
        let spy = VerifierSpy()
        let notice = makeNotice(otpGate: spy.gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)

        XCTAssertEqual(spy.calls, [code])
        XCTAssertFalse(notice.vm.otpLocked)
        await settle()
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
        XCTAssertEqual(notice.accepts.count, 0)

        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        let submit = SubmitRecorder.submits[0]
        XCTAssertEqual(submit.authorization, "Bearer \(NoticeFixtures.customerToken)")
        XCTAssertEqual(submit.selectedByPurpose, [NoticeFixtures.orders: true, NoticeFixtures.marketing: true])
        XCTAssertEqual(submit.dataElements(of: NoticeFixtures.orders), [NoticeFixtures.email: true, NoticeFixtures.phone: true])
        XCTAssertEqual(notice.accepts.count, 1)
    }

    @MainActor
    func testAStashedAcceptSelectedSendsOnlyWhatWasTicked() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)
        notice.vm.handleDataElementToggle(NoticeFixtures.phone, purposeUuid: NoticeFixtures.orders)

        notice.vm.handleAccept(mode: .selected)
        await verify(notice)
        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        let submit = SubmitRecorder.submits[0]
        XCTAssertEqual(submit.authorization, "Bearer \(NoticeFixtures.customerToken)")
        XCTAssertEqual(submit.selectedByPurpose, [NoticeFixtures.orders: true, NoticeFixtures.marketing: false])
        XCTAssertEqual(submit.dataElements(of: NoticeFixtures.orders), [NoticeFixtures.email: true, NoticeFixtures.phone: false])
    }

    @MainActor
    func testNeverReopensOnceVerifiedAndAManualAcceptSubmitsOnce() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)
        notice.vm.otpGate = VerifierSpy().gate()
        await settle()

        XCTAssertFalse(notice.vm.otpLocked)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)

        notice.vm.handleAccept(mode: .all)
        await waitUntil { notice.accepts.count == 1 }

        XCTAssertFalse(notice.vm.otpLocked)
        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(SubmitRecorder.submits[0].authorization, "Bearer \(NoticeFixtures.agentToken)")
        XCTAssertEqual(notice.accepts.count, 1)
    }

    @MainActor
    func testAManualAcceptDropsTheStashSoALaterTokenSwapSubmitsNothingMore() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)
        notice.vm.handleAccept(mode: .all)
        await waitUntil { SubmitRecorder.submits.count == 1 }

        notice.vm.handleAccessTokenChange(NoticeFixtures.customerToken)
        await settle()

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(notice.accepts.count, 1)
    }

    @MainActor
    func testOneSubmitAndOneOnAcceptAcrossTheVerifyAndRepeatedTokenSwaps() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)
        notice.vm.handleAccessTokenChange(NoticeFixtures.customerToken)
        notice.vm.handleAccessTokenChange(NoticeFixtures.customerToken)
        await waitUntil { notice.accepts.count == 1 }
        notice.vm.handleAccessTokenChange(NoticeFixtures.makeToken(sub: "third"))
        await settle()

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(notice.accepts.count, 1)
        XCTAssertFalse(notice.vm.otpLocked)
    }

    @MainActor
    func testAFailedCodeShowsTheHostMessageAndClearsTheBoxes() async {
        let spy = VerifierSpy(.success(OtpVerifyResult(ok: false, message: "That code has expired.")))
        let notice = makeNotice(otpGate: spy.gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)

        XCTAssertEqual(notice.vm.otpPanel.error, "That code has expired.")
        XCTAssertEqual(notice.vm.otpPanel.digits, OtpCodeEntry.empty())
        XCTAssertFalse(notice.vm.otpConfirmEnabled)
        XCTAssertTrue(notice.vm.otpLocked)
        await settle()
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
    }

    @MainActor
    func testAFailedCodeWithoutAMessageFallsBackToTheDefaultCopy() async {
        let notice = makeNotice(otpGate: VerifierSpy(.success(OtpVerifyResult(ok: false))).gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)

        XCTAssertEqual(notice.vm.otpPanel.error, OtpGateCopy.failed)
        XCTAssertEqual(notice.vm.otpPanel.digits, OtpCodeEntry.empty())
    }

    @MainActor
    func testAThrowingVerifyReadsAsAFailedCodeAndLeavesVerifying() async {
        let pending = PendingVerifier()
        let gate = OtpGate(required: true, onVerify: { code in try await pending.verify(code) })
        let notice = makeNotice(otpGate: gate)

        notice.vm.handleAccept(mode: .all)
        notice.vm.updateOtpDigits(digitsOf(code))
        let confirming = Task { await notice.vm.confirmOtp() }
        await waitUntil { pending.started }

        XCTAssertTrue(notice.vm.otpPanel.busy)
        XCTAssertEqual(notice.vm.otpPanelSubmitLabel, OtpGateCopy.verifying)
        notice.vm.updateOtpDigits(digitsOf("111111"))
        XCTAssertEqual(notice.vm.otpPanel.digits, digitsOf(code))

        pending.fail(VerifyFailure(text: "upstream said: invalid otp for +91 98765 43210"))
        await confirming.value

        XCTAssertFalse(notice.vm.otpPanel.busy)
        XCTAssertEqual(notice.vm.otpPanelSubmitLabel, OtpGateCopy.submit)
        XCTAssertEqual(notice.vm.otpPanel.error, OtpGateCopy.failed)
        XCTAssertEqual(notice.vm.otpPanel.digits, OtpCodeEntry.empty())
        XCTAssertNil(notice.vm.errorMessage)
        XCTAssertEqual(notice.errors.count, 0)
        await settle()
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
    }

    @MainActor
    func testAnImmediatelyThrowingVerifyReadsAsAFailedCode() async {
        let spy = VerifierSpy(.failure(VerifyFailure(text: "boom")))
        let notice = makeNotice(otpGate: spy.gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice)

        XCTAssertEqual(notice.vm.otpPanel.error, OtpGateCopy.failed)
        XCTAssertFalse(notice.vm.otpPanel.busy)
    }

    @MainActor
    func testACorrectCodeStillGoesThroughAfterAFailedOne() async {
        let spy = VerifierSpy(queued: [.failure(VerifyFailure(text: "network down"))])
        let notice = makeNotice(otpGate: spy.gate())

        notice.vm.handleAccept(mode: .all)
        await verify(notice, code: "111111")
        XCTAssertEqual(notice.vm.otpPanel.error, OtpGateCopy.failed)

        await verify(notice)
        XCTAssertFalse(notice.vm.otpLocked)
        XCTAssertNil(notice.vm.otpPanel.error)

        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(spy.calls, ["111111", code])
        XCTAssertEqual(SubmitRecorder.submits.count, 1)
    }

    @MainActor
    func testAcceptAllReplacesAStashedAcceptSelected() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)

        notice.vm.handleAccept(mode: .selected)
        notice.vm.handleAccept(mode: .all)
        await settle()
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)

        await verify(notice)
        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(SubmitRecorder.submits[0].selectedByPurpose, [NoticeFixtures.orders: true, NoticeFixtures.marketing: true])
    }

    @MainActor
    func testAcceptSelectedReplacesAStashedAcceptAll() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)

        notice.vm.handleAccept(mode: .all)
        notice.vm.handleAccept(mode: .selected)
        await verify(notice)
        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(SubmitRecorder.submits[0].selectedByPurpose, [NoticeFixtures.orders: true, NoticeFixtures.marketing: false])
    }

    @MainActor
    func testDecliningWhileThePanelIsOpenSubmitsNothing() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate())

        notice.vm.handleAccept(mode: .all)
        notice.vm.handleDecline()
        await settle()

        XCTAssertEqual(notice.declines.count, 1)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
        XCTAssertEqual(notice.accepts.count, 0)
        XCTAssertFalse(notice.vm.otpLocked)
    }

    @MainActor
    private func startPendingVerify(_ pending: PendingVerifier) async -> (NoticeUnderTest, Task<Void, Never>) {
        let gate = OtpGate(required: true, onVerify: { code in try await pending.verify(code) })
        let notice = makeNotice(otpGate: gate)
        notice.vm.handleAccept(mode: .all)
        notice.vm.updateOtpDigits(digitsOf(code))
        let confirming = Task { await notice.vm.confirmOtp() }
        await waitUntil { pending.started }
        return (notice, confirming)
    }

    @MainActor
    func testACodeThatVerifiesAfterADeclineSubmitsNothing() async {
        let pending = PendingVerifier()
        let (notice, confirming) = await startPendingVerify(pending)

        notice.vm.handleDecline()
        pending.succeed()
        await confirming.value
        notice.vm.handleAccessTokenChange(NoticeFixtures.customerToken)
        await settle()

        XCTAssertEqual(notice.declines.count, 1)
        XCTAssertEqual(notice.accepts.count, 0)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
        XCTAssertFalse(notice.vm.otpLocked)
    }

    @MainActor
    func testACodeThatFailsAfterADeclineLeavesTheClosedPanelUntouched() async {
        let pending = PendingVerifier()
        let (notice, confirming) = await startPendingVerify(pending)

        notice.vm.handleDecline()
        pending.fail(VerifyFailure(text: "late"))
        await confirming.value

        XCTAssertEqual(notice.vm.otpPanel, OtpPanelState())
    }

    @MainActor
    func testACodeThatVerifiesWhileThePanelStaysOpenStillSubmitsOnTheNewToken() async {
        let pending = PendingVerifier()
        let (notice, confirming) = await startPendingVerify(pending)

        pending.succeed()
        await confirming.value
        await swapToken(notice, NoticeFixtures.customerToken)

        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertEqual(notice.accepts.count, 1)
    }

    @MainActor
    func testConfirmOnAnIncompleteCodeDoesNotCallVerify() async {
        let spy = VerifierSpy()
        let notice = makeNotice(otpGate: spy.gate())
        notice.vm.handleAccept(mode: .all)

        notice.vm.updateOtpDigits(digitsOf("32000"))
        XCTAssertFalse(notice.vm.otpConfirmEnabled)
        await notice.vm.confirmOtp()

        XCTAssertTrue(spy.calls.isEmpty)
        XCTAssertTrue(notice.vm.otpLocked)
    }

    @MainActor
    func testConfirmEnablesOnlyOnceTheSixthDigitIsIn() {
        let notice = makeNotice(otpGate: VerifierSpy().gate())
        notice.vm.handleAccept(mode: .all)

        var digits = OtpCodeEntry.empty()
        for (index, digit) in ["3", "2", "0", "0", "0"].enumerated() {
            digits = OtpCodeEntry.applyText(digits, index: index, text: digit)!.digits
            notice.vm.updateOtpDigits(digits)
            XCTAssertFalse(notice.vm.otpConfirmEnabled)
        }
        digits = OtpCodeEntry.applyText(digits, index: 5, text: "5")!.digits
        notice.vm.updateOtpDigits(digits)

        XCTAssertTrue(notice.vm.otpConfirmEnabled)
    }
}
