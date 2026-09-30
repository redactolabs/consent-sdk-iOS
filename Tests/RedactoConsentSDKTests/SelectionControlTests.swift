import XCTest
@testable import RedactoConsentSDK

final class SelectionControlTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SubmitRecorder.start()
    }

    override func tearDown() {
        SubmitRecorder.stop()
        super.tearDown()
    }

    func testTheDefaultsLeaveAnExistingNoticeUnchanged() {
        let settings = ConsentSettings()
        XCTAssertEqual(settings.selectionControl, .checkbox)
        XCTAssertFalse(settings.confirmBeforeSubmit)
    }

    func testACheckboxAsksForTheOppositeOfWhatItShows() {
        XCTAssertTrue(SelectionControlLogic.shouldReport(true, checked: false, indeterminate: false))
        XCTAssertTrue(SelectionControlLogic.shouldReport(false, checked: true, indeterminate: false))
    }

    func testRePickingTheAnswerAlreadyHeldIsANoOp() {
        XCTAssertFalse(SelectionControlLogic.shouldReport(true, checked: true, indeterminate: false))
        XCTAssertFalse(SelectionControlLogic.shouldReport(false, checked: false, indeterminate: false))
    }

    func testAMixedSectionReportsEitherAnswer() {
        XCTAssertTrue(SelectionControlLogic.shouldReport(false, checked: false, indeterminate: true))
        XCTAssertTrue(SelectionControlLogic.shouldReport(true, checked: false, indeterminate: true))
    }

    func testTheRadioPairHoldsTheCurrentAnswer() {
        XCTAssertTrue(SelectionControlLogic.holds(true, checked: true, indeterminate: false, locked: false))
        XCTAssertFalse(SelectionControlLogic.holds(false, checked: true, indeterminate: false, locked: false))
        XCTAssertTrue(SelectionControlLogic.holds(false, checked: false, indeterminate: false, locked: false))
    }

    func testAMixedSectionHoldsNeitherAnswer() {
        XCTAssertFalse(SelectionControlLogic.holds(true, checked: false, indeterminate: true, locked: false))
        XCTAssertFalse(SelectionControlLogic.holds(false, checked: false, indeterminate: true, locked: false))
    }

    func testALockedRowHoldsYesWhateverTheTickSays() {
        XCTAssertTrue(SelectionControlLogic.holds(true, checked: false, indeterminate: false, locked: true))
        XCTAssertFalse(SelectionControlLogic.holds(false, checked: false, indeterminate: false, locked: true))
    }

    func testEachControlRendersLiveWhenUnlocked() {
        XCTAssertEqual(SelectionControlLogic.rendering(control: .checkbox, locked: false), .checkbox)
        XCTAssertEqual(SelectionControlLogic.rendering(control: .radio, locked: false), .radio)
        XCTAssertEqual(SelectionControlLogic.rendering(control: .dropdown, locked: false), .dropdown)
    }

    func testASettledRowRendersAsARecordInEachControlsVocabulary() {
        XCTAssertEqual(SelectionControlLogic.rendering(control: .checkbox, locked: true), .lockedTick)
        XCTAssertEqual(SelectionControlLogic.rendering(control: .radio, locked: true), .radio)
        XCTAssertEqual(SelectionControlLogic.rendering(control: .dropdown, locked: true), .settledAnswer)
    }

    func testTheDropdownShowsTheAnswerOrMixed() {
        XCTAssertEqual(SelectionControlLogic.dropdownAnswer(checked: true, indeterminate: false), .yes)
        XCTAssertEqual(SelectionControlLogic.dropdownAnswer(checked: false, indeterminate: false), .no)
        XCTAssertEqual(SelectionControlLogic.dropdownAnswer(checked: true, indeterminate: true), .mixed)
    }

    func testTheSavedAnswerIsReadOutBesideOnlyTheOptionOnRecord() {
        XCTAssertEqual(SelectionControlLogic.optionLabel("Yes", value: true, recordedAnswer: true), "Yes Saved answer: Yes")
        XCTAssertEqual(SelectionControlLogic.optionLabel("No", value: false, recordedAnswer: true), "No")
        XCTAssertEqual(SelectionControlLogic.optionLabel("Yes", value: true, recordedAnswer: nil), "Yes")
    }

    @MainActor
    func testPickingNoOnAMixedSectionClearsItRatherThanTickingEverything() {
        let requiredA = NoticeProductFixtures.requiredPurpose("purpose-required-a", "Required A", ["prod-a"])
        let content = NoticeFixtures.content(
            purposes: [NoticeProductFixtures.shared, requiredA, NoticeProductFixtures.onlyB],
            config: ["products": NoticeProductFixtures.twoProducts()]
        )
        let vm = makeNotice(content: content).vm
        let sharedA = ProductMatrix.productPurposeKey("prod-a", "purpose-shared")
        let requiredKey = ProductMatrix.productPurposeKey("prod-a", "purpose-required-a")
        vm.handlePurposeToggle("purpose-shared", productUuid: "prod-a")
        let group = vm.productGroups.first { $0.product.uuid == "prod-a" }!
        XCTAssertTrue(vm.sectionSummary(for: group.purposes, keyProductUuid: "prod-a").mixed)

        vm.handleProductCheckboxChange("prod-a", to: false)

        XCTAssertEqual(vm.selectedPurposes[sharedA], false)
        XCTAssertEqual(vm.selectedPurposes[requiredKey], false)
    }

    @MainActor
    func testPickingYesOnASectionTicksItsBoxPurposes() {
        let content = NoticeFixtures.content(
            purposes: [NoticeProductFixtures.shared, NoticeProductFixtures.onlyA, NoticeProductFixtures.onlyB],
            config: ["products": NoticeProductFixtures.twoProducts()]
        )
        let vm = makeNotice(content: content).vm

        vm.handleProductCheckboxChange("prod-a", to: true)

        XCTAssertEqual(vm.selectedPurposes[ProductMatrix.productPurposeKey("prod-a", "purpose-shared")], true)
        XCTAssertNotEqual(vm.selectedPurposes[ProductMatrix.productPurposeKey("prod-b", "purpose-shared")], true)
    }

    @MainActor
    func testTheRecordedAnswerReadsThePerProductRecordFirst() {
        var root = try! JSONSerialization.jsonObject(with: NoticeFixtures.contentData(
            purposes: [NoticeProductFixtures.shared, NoticeProductFixtures.onlyA, NoticeProductFixtures.onlyB],
            config: ["products": NoticeProductFixtures.twoProducts()],
            purposeSelections: ["purpose-shared": NoticeProductFixtures.recorded(selected: false, status: "INACTIVE", needsReconsent: true)]
        )) as! [String: Any]
        var detail = root["detail"] as! [String: Any]
        detail["product_purpose_selections"] = ["prod-a": ["purpose-shared": NoticeProductFixtures.recorded()]]
        root["detail"] = detail
        let content = try! JSONDecoder().decode(ConsentContent.self, from: JSONSerialization.data(withJSONObject: root))
        let vm = makeNotice(content: content).vm

        XCTAssertEqual(vm.recordedAnswer(forPurpose: "purpose-shared", productUuid: "prod-a"), true)
        XCTAssertNil(vm.recordedAnswer(forPurpose: "purpose-shared", productUuid: "prod-b"))
    }

    @MainActor
    func testTheNoticeReadsTheControlFromSettings() {
        XCTAssertEqual(makeNotice().vm.selectionControl, .checkbox)
        XCTAssertEqual(makeNotice(settings: ConsentSettings(selectionControl: .dropdown)).vm.selectionControl, .dropdown)
    }

    @MainActor
    func testTheRecordedAnswerIsAbsentForAnUnansweredPurpose() {
        let selections: [String: Any] = [
            NoticeFixtures.orders: ["selected": true, "status": "ACTIVE", "needs_reconsent": false, "data_elements": [String: Any]()],
            NoticeFixtures.marketing: ["selected": false, "status": "INACTIVE", "needs_reconsent": true, "data_elements": [String: Any]()],
        ]
        let vm = makeNotice(content: NoticeFixtures.content(purposeSelections: selections)).vm

        XCTAssertEqual(vm.recordedAnswer(forPurpose: NoticeFixtures.orders), true)
        XCTAssertNil(vm.recordedAnswer(forPurpose: NoticeFixtures.marketing))
        XCTAssertNil(vm.recordedAnswer(forPurpose: "purpose-unknown"))
    }

    func testTheConfirmCopySaysWhatEachButtonRecords() {
        let actions: [ConfirmAction] = [.acceptAll, .acceptSelected, .decline]
        XCTAssertEqual(Set(actions.map(ConfirmDialogCopy.title(for:))).count, 3)
        XCTAssertEqual(Set(actions.map(ConfirmDialogCopy.detail(for:))).count, 3)
        XCTAssertEqual(ConfirmDialogCopy.title(for: .decline), "Decline this notice?")
    }

    @MainActor
    func testWithoutConfirmBeforeSubmitEachButtonActsAtOnce() async {
        let notice = makeNotice()

        notice.vm.requestAction(.decline)
        XCTAssertEqual(notice.declines.count, 1)
        XCTAssertNil(notice.vm.pendingConfirmAction)

        notice.vm.requestAction(.acceptAll)
        await waitUntil { notice.accepts.count == 1 }
        XCTAssertEqual(SubmitRecorder.submits.count, 1)
        XCTAssertNil(notice.vm.pendingConfirmAction)
    }

    @MainActor
    func testConfirmBeforeSubmitAsksFirstAndActsOnlyOnYes() async {
        let notice = makeNotice(settings: ConsentSettings(confirmBeforeSubmit: true))

        notice.vm.requestAction(.acceptAll)
        await settle()
        XCTAssertEqual(notice.vm.pendingConfirmAction, .acceptAll)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)

        notice.vm.confirmPendingAction(.acceptAll)
        await waitUntil { notice.accepts.count == 1 }
        XCTAssertNil(notice.vm.pendingConfirmAction)
        XCTAssertEqual(SubmitRecorder.submits.count, 1)
    }

    @MainActor
    func testCancellingTheConfirmationRecordsNothing() async {
        let notice = makeNotice(settings: ConsentSettings(confirmBeforeSubmit: true))

        notice.vm.requestAction(.decline)
        XCTAssertEqual(notice.vm.pendingConfirmAction, .decline)
        notice.vm.dismissConfirm()
        await settle()

        XCTAssertNil(notice.vm.pendingConfirmAction)
        XCTAssertEqual(notice.declines.count, 0)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
    }

    @MainActor
    func testAConfirmedAcceptStillWaitsOnTheOtpGate() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate(), settings: ConsentSettings(confirmBeforeSubmit: true))
        notice.vm.handlePurposeToggle(NoticeFixtures.orders)

        notice.vm.requestAction(.acceptSelected)
        XCTAssertEqual(notice.vm.pendingConfirmAction, .acceptSelected)
        XCTAssertFalse(notice.vm.otpLocked)
        notice.vm.confirmPendingAction(.acceptSelected)
        await settle()

        XCTAssertTrue(notice.vm.otpLocked)
        XCTAssertEqual(notice.vm.otpPanel.pendingMode, .selected)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
    }

    @MainActor
    func testTheEngagedProductGateRunsBeforeTheConfirmationAndTheOtpHold() async {
        let notice = makeNotice(otpGate: VerifierSpy().gate(), settings: ConsentSettings(confirmBeforeSubmit: true))
        XCTAssertTrue(notice.vm.acceptDisabled)

        notice.vm.requestAction(.acceptSelected)
        await settle()

        XCTAssertNil(notice.vm.pendingConfirmAction)
        XCTAssertFalse(notice.vm.otpLocked)
        XCTAssertTrue(SubmitRecorder.submits.isEmpty)
    }

    @MainActor
    func testAcceptAllIsNotHeldByTheEngagedProductGate() {
        let notice = makeNotice(otpGate: VerifierSpy().gate(), settings: ConsentSettings(confirmBeforeSubmit: true))
        XCTAssertTrue(notice.vm.acceptDisabled)

        notice.vm.requestAction(.acceptAll)

        XCTAssertEqual(notice.vm.pendingConfirmAction, .acceptAll)
    }
}
