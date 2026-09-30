import XCTest
@testable import RedactoConsentSDK

final class OtpCodeEntryTests: XCTestCase {
    private let code = "320005"

    func testHoldsARequiredGateThatHasNotBeenVerified() {
        XCTAssertTrue(OtpGateFlow.shouldHold(required: true, verified: false))
    }

    func testLetsARequiredGateThroughOnceVerified() {
        XCTAssertFalse(OtpGateFlow.shouldHold(required: true, verified: true))
    }

    func testNeverHoldsANoticeWithNoGate() {
        XCTAssertFalse(OtpGateFlow.shouldHold(required: nil, verified: false))
        XCTAssertFalse(OtpGateFlow.shouldHold(required: nil, verified: true))
    }

    func testNeverHoldsANoticeWhoseGateIsNotRequired() {
        XCTAssertFalse(OtpGateFlow.shouldHold(required: false, verified: false))
        XCTAssertFalse(OtpGateFlow.shouldHold(required: false, verified: true))
    }

    func testTheFlowDefersTheAcceptUntilTheTokenChanges() {
        var flow = OtpGateFlow()
        XCTAssertTrue(flow.holds(required: true))

        flow.markVerified(mode: .all, token: "agent")

        XCTAssertFalse(flow.holds(required: true))
        XCTAssertNil(flow.takeDeferredAccept(currentToken: "agent"))
        XCTAssertEqual(flow.takeDeferredAccept(currentToken: "customer"), .all)
        XCTAssertNil(flow.takeDeferredAccept(currentToken: "someone-else"))
    }

    func testPassingTheGateDropsTheDeferredAccept() {
        var flow = OtpGateFlow()
        flow.markVerified(mode: .selected, token: "agent")

        flow.passGate()

        XCTAssertNil(flow.takeDeferredAccept(currentToken: "customer"))
        XCTAssertTrue(flow.verified)
    }

    func testStartsWithOneEmptyBoxPerDigit() {
        let digits = OtpCodeEntry.empty()
        XCTAssertEqual(digits, ["", "", "", "", "", ""])
        XCTAssertFalse(OtpCodeEntry.isComplete(digits))
        XCTAssertEqual(OtpCodeEntry.code(of: digits), "")
    }

    func testIsCompleteOnlyWhenEveryBoxHoldsADigit() {
        XCTAssertTrue(OtpCodeEntry.isComplete(digitsOf(code)))
        XCTAssertFalse(OtpCodeEntry.isComplete(["3", "2", "0", "", "0", "5"]))
        XCTAssertFalse(OtpCodeEntry.isComplete(["3", "2", "0", "a", "0", "5"]))
        XCTAssertEqual(OtpCodeEntry.code(of: digitsOf(code)), code)
    }

    func testPastingIntoTheFirstBoxFillsAllSix() {
        let entry = OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 0, text: code)
        XCTAssertEqual(entry?.digits, digitsOf(code))
        XCTAssertEqual(entry?.focus, OtpGateCopy.length - 1)
    }

    func testPastingIntoALaterBoxStillFillsFromTheStart() {
        let entry = OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 3, text: code)
        XCTAssertEqual(entry?.digits, digitsOf(code))
        XCTAssertEqual(entry?.focus, OtpGateCopy.length - 1)
    }

    func testAFullPasteReplacesWhatWasEntered() {
        let entry = OtpCodeEntry.applyText(digitsOf("98"), index: 1, text: code)
        XCTAssertEqual(entry?.digits, digitsOf(code))
    }

    func testKeepsOnlyTheDigitsOfAPaste() {
        for pasted in ["320-005", " 320 005 ", "320 005\n"] {
            XCTAssertEqual(OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 0, text: pasted)?.digits, digitsOf(code), pasted)
        }
    }

    func testTruncatesAPasteLongerThanTheCode() {
        let entry = OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 0, text: "32000512")
        XCTAssertEqual(entry.map { OtpCodeEntry.code(of: $0.digits) }, code)
        XCTAssertEqual(entry?.focus, OtpGateCopy.length - 1)
    }

    func testDropsTheDigitAlreadyInTheBoxWhenAPasteLandsBesideIt() {
        let filled = digitsOf("7")
        XCTAssertEqual(OtpCodeEntry.applyText(filled, index: 0, text: "7\(code)").map { OtpCodeEntry.code(of: $0.digits) }, code)
        XCTAssertEqual(OtpCodeEntry.applyText(filled, index: 0, text: "\(code)7").map { OtpCodeEntry.code(of: $0.digits) }, code)
    }

    func testAPartialPasteFillsFromTheStartAndFocusesTheNextEmptyBox() {
        let entry = OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 4, text: "320")
        XCTAssertEqual(entry?.digits, ["3", "2", "0", "", "", ""])
        XCTAssertEqual(entry?.focus, 3)
    }

    func testRejectsANonDigitKeystroke() {
        XCTAssertNil(OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 2, text: "a"))
        XCTAssertNil(OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 2, text: "-"))
        XCTAssertNil(OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 2, text: "٣"))
    }

    func testRejectsANonDigitTypedAfterADigitInTheBox() {
        XCTAssertNil(OtpCodeEntry.applyText(digitsOf("3"), index: 0, text: "3a"))
    }

    func testATypedDigitGoesInItsOwnBoxAndAdvancesFocus() {
        let entry = OtpCodeEntry.applyText(digitsOf("32"), index: 2, text: "0")
        XCTAssertEqual(entry?.digits, ["3", "2", "0", "", "", ""])
        XCTAssertEqual(entry?.focus, 3)
    }

    func testTypesIntoABoxWhoseEarlierBoxesAreEmptyWithoutShifting() {
        let entry = OtpCodeEntry.applyText(OtpCodeEntry.empty(), index: 3, text: "5")
        XCTAssertEqual(entry?.digits, ["", "", "", "5", "", ""])
        XCTAssertEqual(entry?.focus, 4)
    }

    func testKeepsFocusOnTheLastBoxAfterItsDigit() {
        let entry = OtpCodeEntry.applyText(digitsOf("32000"), index: 5, text: "5")
        XCTAssertEqual(entry.map { OtpCodeEntry.code(of: $0.digits) }, code)
        XCTAssertNil(entry?.focus)
    }

    func testReplacesAFilledBoxWhenADigitIsTypedEitherSideOfIt() {
        for text in ["35", "53"] {
            let entry = OtpCodeEntry.applyText(digitsOf("3"), index: 0, text: text)
            XCTAssertEqual(entry?.digits, ["5", "", "", "", "", ""], text)
            XCTAssertEqual(entry?.focus, 1, text)
        }
    }

    func testClearsTheBoxWhenItsTextIsDeleted() {
        let entry = OtpCodeEntry.applyText(digitsOf("320"), index: 1, text: "")
        XCTAssertEqual(entry?.digits, ["3", "", "0", "", "", ""])
        XCTAssertNil(entry?.focus)
    }

    func testBackspaceClearsAFilledBoxAndStaysOnIt() {
        let entry = OtpCodeEntry.applyBackspace(digitsOf("320"), index: 2)
        XCTAssertEqual(entry.digits, ["3", "2", "", "", "", ""])
        XCTAssertNil(entry.focus)
    }

    func testBackspaceStepsBackFromAnEmptyBoxClearingThePreviousDigit() {
        let entry = OtpCodeEntry.applyBackspace(digitsOf("320"), index: 3)
        XCTAssertEqual(entry.digits, ["3", "2", "", "", "", ""])
        XCTAssertEqual(entry.focus, 2)
    }

    func testBackspaceDoesNothingOnAnEmptyFirstBox() {
        let digits = OtpCodeEntry.empty()
        let entry = OtpCodeEntry.applyBackspace(digits, index: 0)
        XCTAssertEqual(entry.digits, digits)
        XCTAssertNil(entry.focus)
    }

    func testTypingForwardThenBackspacingMovesFocusBothWays() {
        var digits = OtpCodeEntry.empty()
        let first = OtpCodeEntry.applyText(digits, index: 0, text: "3")!
        XCTAssertEqual(first.focus, 1)
        digits = first.digits
        let second = OtpCodeEntry.applyText(digits, index: 1, text: "2")!
        XCTAssertEqual(second.focus, 2)
        digits = second.digits

        let back = OtpCodeEntry.applyBackspace(digits, index: 2)
        XCTAssertEqual(back.focus, 1)
        XCTAssertEqual(back.digits, ["3", "", "", "", "", ""])
    }
}
