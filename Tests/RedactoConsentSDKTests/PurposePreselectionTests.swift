import XCTest
@testable import RedactoConsentSDK

final class PurposePreselectionTests: XCTestCase {
    private let first = "purpose-first"
    private let second = "purpose-second"
    private let requiredElement = "element-required"
    private let optionalElement = "element-optional"
    private let disabledElement = "element-disabled"

    private func element(_ uuid: String, required: Bool, enabled: Bool = true) -> ActiveConfigDataElement {
        ActiveConfigDataElement(uuid: uuid, name: uuid, description: nil, industries: nil, enabled: enabled, required: required)
    }

    private var purposes: [ActiveConfigPurpose] {
        [
            ActiveConfigPurpose(uuid: first, name: "First", description: "", industries: nil, dataElements: [
                element(requiredElement, required: true),
                element(optionalElement, required: false),
            ]),
            ActiveConfigPurpose(uuid: second, name: "Second", description: "", industries: nil, dataElements: [
                element(optionalElement, required: false),
            ]),
        ]
    }

    private func selection(
        selected: Bool = false,
        status: String = "INACTIVE",
        needsReconsent: Bool = true,
        elements: [String: Bool] = [:]
    ) -> PurposeSelection {
        let json: [String: Any] = [
            "selected": selected,
            "status": status,
            "needs_reconsent": needsReconsent,
            "data_elements": elements.mapValues { ["selected": $0, "enabled": true, "required": false] },
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(PurposeSelection.self, from: data)
    }

    private func key(_ purpose: String, _ element: String) -> String {
        dataElementKey(purposeUuid: purpose, elementUuid: element)
    }

    func testPassesMandatoryAndAllThrough() {
        XCTAssertEqual(PurposePreselectionLogic.resolve("MANDATORY"), .mandatory)
        XCTAssertEqual(PurposePreselectionLogic.resolve("ALL"), .all)
    }

    func testFallsBackToNoneForAnythingElse() {
        for raw in [nil, "", " MANDATORY ", "mandatory", "EVERYTHING", "NONE"] as [String?] {
            XCTAssertEqual(PurposePreselectionLogic.resolve(raw), PurposePreselection.none, String(describing: raw))
        }
    }

    func testNoRecordedStateWithoutAnEntry() {
        XCTAssertFalse(PurposePreselectionLogic.hasRecordedState(nil))
    }

    func testNoRecordedStateForAnInactivePlaceholder() {
        XCTAssertFalse(PurposePreselectionLogic.hasRecordedState(selection()))
    }

    func testRecordedStateForADecidedStatus() {
        for status in ["ACTIVE", "EXPIRED", "WITHDRAW", "DECLINED"] {
            XCTAssertTrue(PurposePreselectionLogic.hasRecordedState(selection(status: status)), status)
        }
    }

    func testRecordedStateForAnInactiveEntryCarryingAnElementSnapshot() {
        XCTAssertTrue(PurposePreselectionLogic.hasRecordedState(selection(elements: [requiredElement: false])))
    }

    func testNoneTicksNothing() {
        let built = PurposePreselectionLogic.build(purposes: purposes, mode: .none)

        XCTAssertEqual(built.selectedPurposes, [first: false, second: false])
        XCTAssertFalse(built.selectedDataElements.values.contains(true))
    }

    func testMandatoryTicksOnlyTheRequiredElementsAndTheirPurpose() {
        let built = PurposePreselectionLogic.build(purposes: purposes, mode: .mandatory)

        XCTAssertEqual(built.selectedDataElements[key(first, requiredElement)], true)
        XCTAssertEqual(built.selectedDataElements[key(first, optionalElement)], false)
        XCTAssertEqual(built.selectedPurposes[first], true)
        XCTAssertEqual(built.selectedPurposes[second], false)
        XCTAssertEqual(built.selectedDataElements[key(second, optionalElement)], false)
    }

    func testMandatoryNeverTicksADisabledRequiredElement() {
        let disabledOnly = [ActiveConfigPurpose(uuid: first, name: "First", description: "", industries: nil, dataElements: [
            element(disabledElement, required: true, enabled: false),
        ])]
        let built = PurposePreselectionLogic.build(purposes: disabledOnly, mode: .mandatory)

        XCTAssertEqual(built.selectedDataElements[key(first, disabledElement)], false)
        XCTAssertEqual(built.selectedPurposes[first], false)
    }

    func testAllMatchesWhatAcceptAllSubmits() {
        let built = PurposePreselectionLogic.build(purposes: purposes, mode: .all)
        let acceptAll = buildSelection(
            purposes: purposes,
            mode: .all,
            current: SelectionState(selectedPurposes: [:], selectedDataElements: [:])
        )

        XCTAssertEqual(built.selectedPurposes, acceptAll.selectedPurposes)
        XCTAssertEqual(built.selectedDataElements, acceptAll.selectedDataElements)
    }

    func testAFreshSubjectOpensWithThePreselection() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: .mandatory)
        let seed = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: nil, preselection: preselection)

        XCTAssertEqual(seed, PurposeRowSeed(purposeSelected: true, dataElements: [requiredElement: true, optionalElement: false]))
    }

    func testAReturningSubjectWithAnUnansweredPurposeStillGetsThePreselection() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: .all)
        let seed = PurposePreselectionLogic.seedRow(purpose: purposes[1], recorded: selection(), preselection: preselection)

        XCTAssertEqual(seed, PurposeRowSeed(purposeSelected: true, dataElements: [optionalElement: true]))
    }

    func testARecordedDeclineIsNeverReTicked() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: .all)
        let declined = selection(selected: false, status: "WITHDRAW", needsReconsent: false)
        let seed = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: declined, preselection: preselection)

        XCTAssertEqual(seed, PurposeRowSeed(purposeSelected: false, dataElements: [requiredElement: false, optionalElement: false]))
    }

    func testARecordedGrantKeepsItsOwnElements() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: PurposePreselection.none)
        let granted = selection(selected: true, status: "ACTIVE", needsReconsent: false, elements: [requiredElement: true, optionalElement: false])
        let seed = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: granted, preselection: preselection)

        XCTAssertEqual(seed, PurposeRowSeed(purposeSelected: true, dataElements: [requiredElement: true, optionalElement: false]))
    }

    func testARecordedPurposeOwnsElementsMissingFromItsSnapshot() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: .all)
        let granted = selection(selected: true, status: "ACTIVE", needsReconsent: false, elements: [requiredElement: true])
        let seed = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: granted, preselection: preselection)

        XCTAssertEqual(seed.dataElements[optionalElement], false)
    }

    func testTheDefaultNoneSeedsExactlyAsTheNoticeDidBefore() {
        let preselection = PurposePreselectionLogic.build(purposes: purposes, mode: PurposePreselectionLogic.resolve(nil))
        let fresh = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: nil, preselection: preselection)
        let placeholder = PurposePreselectionLogic.seedRow(purpose: purposes[0], recorded: selection(), preselection: preselection)

        XCTAssertEqual(fresh, PurposeRowSeed(purposeSelected: false, dataElements: [requiredElement: false, optionalElement: false]))
        XCTAssertEqual(placeholder, fresh)
    }

    @MainActor
    private func loadedNotice(preselection: String?, selections: [String: Any]? = nil) async -> ConsentNoticeViewModel {
        var config: [String: Any] = [:]
        if let preselection {
            config["purpose_preselection"] = preselection
        }
        SubmitRecorder.start()
        SubmitRecorder.serveNotice(NoticeFixtures.contentData(config: config, purposeSelections: selections))
        await ConsentAPI.clearCache()
        let vm = makeNotice(content: NoticeFixtures.content()).vm
        vm.content = nil
        vm.fetchContent()
        await waitUntil { vm.content != nil && !vm.isLoading }
        SubmitRecorder.stop()
        return vm
    }

    @MainActor
    func testTheModalNoticeOpensAFreshSubjectWithTheMandatoryPreselection() async {
        let vm = await loadedNotice(preselection: "MANDATORY")

        XCTAssertEqual(vm.selectedPurposes, [NoticeFixtures.orders: true, NoticeFixtures.marketing: false])
        XCTAssertEqual(vm.selectedDataElements["\(NoticeFixtures.orders)-\(NoticeFixtures.email)"], true)
        XCTAssertEqual(vm.selectedDataElements["\(NoticeFixtures.orders)-\(NoticeFixtures.phone)"], false)
        XCTAssertNil(vm.initialDataElementSelections["\(NoticeFixtures.orders)-\(NoticeFixtures.email)"])
    }

    @MainActor
    func testTheModalNoticeHonoursThePreselectionForAReturningSubjectButNotOverARecordedDecline() async {
        let selections: [String: Any] = [
            NoticeFixtures.orders: ["selected": false, "status": "WITHDRAW", "needs_reconsent": false, "data_elements": [String: Any]()],
            NoticeFixtures.marketing: ["selected": false, "status": "INACTIVE", "needs_reconsent": true, "data_elements": [String: Any]()],
        ]
        let vm = await loadedNotice(preselection: "ALL", selections: selections)

        XCTAssertEqual(vm.selectedPurposes, [NoticeFixtures.orders: false, NoticeFixtures.marketing: true])
        XCTAssertEqual(vm.selectedDataElements["\(NoticeFixtures.orders)-\(NoticeFixtures.email)"], false)
        XCTAssertEqual(vm.selectedDataElements["\(NoticeFixtures.marketing)-\(NoticeFixtures.email)"], true)
    }

    @MainActor
    func testTheModalNoticeWithoutAPreselectionOpensUnticked() async {
        let vm = await loadedNotice(preselection: nil)

        XCTAssertEqual(vm.selectedPurposes, [NoticeFixtures.orders: false, NoticeFixtures.marketing: false])
        XCTAssertFalse(vm.selectedDataElements.values.contains(true))
    }

    private var multiProductContent: [String: Any] {
        [
            "products": NoticeProductFixtures.twoProducts(),
            "purposes": [NoticeProductFixtures.shared, NoticeProductFixtures.onlyA, NoticeProductFixtures.onlyB],
        ]
    }

    @MainActor
    func testMultiProductPreselectionSeedsPairKeysAndARecordedPerProductDeclineWins() async {
        let declined: [String: Any] = ["selected": false, "status": "WITHDRAW", "needs_reconsent": false, "data_elements": [String: Any]()]
        var config = multiProductContent
        let purposes = config.removeValue(forKey: "purposes") as? [[String: Any]]
        config["purpose_preselection"] = "MANDATORY"
        SubmitRecorder.start()
        let root = NoticeFixtures.contentData(purposes: purposes, config: config)
        var json = try! JSONSerialization.jsonObject(with: root) as! [String: Any]
        var detail = json["detail"] as! [String: Any]
        detail["product_purpose_selections"] = ["prod-a": ["purpose-shared": declined]]
        json["detail"] = detail
        SubmitRecorder.serveNotice(try! JSONSerialization.data(withJSONObject: json))
        await ConsentAPI.clearCache()
        let vm = makeNotice().vm
        vm.content = nil
        vm.fetchContent()
        await waitUntil { vm.content != nil && !vm.isLoading }
        SubmitRecorder.stop()

        let key = { (product: String, purpose: String) in ProductMatrix.productPurposeKey(product, purpose) }
        XCTAssertEqual(vm.selectedPurposes[key("prod-a", "purpose-shared")], false)
        XCTAssertEqual(vm.selectedPurposes[key("prod-b", "purpose-shared")], true)
        XCTAssertEqual(vm.selectedPurposes[key("prod-a", "purpose-only-a")], false)
        XCTAssertEqual(vm.selectedDataElements["\(key("prod-b", "purpose-shared"))-purpose-shared-id"], true)
        XCTAssertEqual(vm.selectedDataElements["\(key("prod-b", "purpose-shared"))-purpose-shared-extra"], false)
        XCTAssertEqual(vm.selectedDataElements["\(key("prod-a", "purpose-shared"))-purpose-shared-id"], false)
        XCTAssertNil(vm.selectedPurposes["purpose-shared"])
        XCTAssertNil(vm.initialDataElementSelections["\(key("prod-b", "purpose-shared"))-purpose-shared-id"])
    }

    func testThePairSeedLeavesAMultiProductNoticeUntouchedUnderNone() {
        let content = NoticeFixtures.content(
            purposes: [NoticeProductFixtures.shared, NoticeProductFixtures.onlyA],
            config: ["products": NoticeProductFixtures.twoProducts()]
        )
        let ac = content.detail.activeConfig
        let rows = ProductMatrix.noticePurposeRows(ac.products, ac.purposes, order: ac.productPurposeOrder)
        let granted = selection(selected: true, status: "ACTIVE", needsReconsent: false)
        let lookup: RecordedLookup = { purpose, product in
            purpose == "purpose-shared" && product == "prod-a" ? granted : nil
        }

        let seeded = PurposePreselectionLogic.seed(rows: rows, recordedFor: lookup, mode: PurposePreselection.none)
        let legacy = ProductConsent.seedSelection(rows: rows, recordedFor: lookup)

        XCTAssertEqual(seeded.selectedPurposes, legacy.selectedPurposes)
        XCTAssertEqual(seeded.selectedDataElements, legacy.selectedDataElements)
        XCTAssertEqual(seeded.selectedPurposes[ProductMatrix.productPurposeKey("prod-a", "purpose-shared")], true)
    }

    func testTheFieldDecodesOffTheNoticeConfig() {
        XCTAssertEqual(NoticeFixtures.content(config: ["purpose_preselection": "MANDATORY"]).detail.activeConfig.purposePreselection, "MANDATORY")
        XCTAssertNil(NoticeFixtures.content().detail.activeConfig.purposePreselection)
    }
}
