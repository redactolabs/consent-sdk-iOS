import XCTest
@testable import RedactoConsentSDK

final class InlineSelectionTests: XCTestCase {
    private typealias F = InlineFixtures
    private let A = InlineFixtures.productA
    private let B = InlineFixtures.productB

    private func rowKey(_ row: NoticePurposeRow) -> String {
        ProductMatrix.productPurposeKey(row.productUuid, row.purpose.uuid)
    }

    private func fresh(_ config: ActiveConfig) -> SelectionState {
        InlineSelection.initialSelection(InlineSelection.inlinePurposeRows(config))
    }

    private func tickPurpose(_ state: SelectionState, _ purpose: ActiveConfigPurpose, _ productUuid: String? = nil) -> SelectionState {
        let key = ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
        let next = !(state.selectedPurposes[key] ?? false)
        var purposes = state.selectedPurposes
        purposes[key] = next
        return SelectionState(
            selectedPurposes: purposes,
            selectedDataElements: InlineSelection.withPurposeElements(purpose, productUuid, next, state.selectedDataElements)
        )
    }

    private func tickElement(
        _ state: SelectionState,
        _ purpose: ActiveConfigPurpose,
        _ elementUuid: String,
        _ productUuid: String? = nil
    ) -> SelectionState {
        let toggled = InlineSelection.toggleDataElement(purpose, elementUuid, productUuid, state.selectedDataElements)
        var purposes = state.selectedPurposes
        purposes[ProductMatrix.productPurposeKey(productUuid, purpose.uuid)] = toggled.purposeSelected
        return SelectionState(selectedPurposes: purposes, selectedDataElements: toggled.selectedDataElements)
    }

    private func gate(_ config: ActiveConfig, _ state: SelectionState) -> Bool {
        InlineSelection.allRequiredElementsChecked(InlineSelection.inlinePurposeRows(config), state.selectedDataElements)
    }

    private func wire(_ config: ActiveConfig, _ state: SelectionState) -> [Purpose] {
        InlineSelection.buildInlineSubmitPurposes(InlineSelection.inlinePurposeRows(config), state)
    }

    private func covers(_ purpose: ActiveConfigPurpose, _ productUuid: String) -> Bool {
        guard let scope = purpose.productUuids, !scope.isEmpty else { return true }
        return scope.contains(productUuid)
    }

    private func names(_ purpose: ActiveConfigPurpose, _ productUuid: String) -> Bool {
        purpose.productUuids?.contains(productUuid) ?? false
    }

    private func isMandatory(_ purpose: ActiveConfigPurpose) -> Bool {
        purpose.dataElements.contains { $0.required && $0.enabled }
    }

    private func ledgerRefusal(_ config: ActiveConfig, _ payload: [Purpose]) -> String? {
        var byUuid: [String: ActiveConfigPurpose] = [:]
        for purpose in config.purposes {
            byUuid[purpose.uuid] = purpose
        }
        let productUuids = (config.products ?? []).map { $0.uuid }
        var seen = Set<String>()
        var scoped = Set<String>()
        var unscoped = Set<String>()

        for selection in payload {
            guard let target = byUuid[selection.uuid] else { return "unknown purpose \(selection.uuid)" }
            let key = "\(selection.uuid)|\(selection.productUuid ?? "")"
            if seen.contains(key) { return "duplicate purpose \(selection.uuid)" }
            seen.insert(key)
            if let productUuid = selection.productUuid {
                scoped.insert(selection.uuid)
                if !productUuids.contains(productUuid) { return "unknown product \(productUuid)" }
                if !covers(target, productUuid) { return "purpose does not cover \(productUuid)" }
            } else {
                unscoped.insert(selection.uuid)
            }
        }
        for uuid in scoped where unscoped.contains(uuid) {
            return "mixed scope \(uuid)"
        }
        for target in config.purposes where !payload.contains(where: { $0.uuid == target.uuid }) {
            return "missing purpose \(target.uuid)"
        }

        for productUuid in productUuids {
            let selections = payload.filter { selection in
                guard let target = byUuid[selection.uuid] else { return false }
                return covers(target, productUuid) && (selection.productUuid == nil || selection.productUuid == productUuid)
            }
            let engaged = selections.contains { selection in
                guard let target = byUuid[selection.uuid] else { return false }
                return selection.productUuid == productUuid && selection.selected && names(target, productUuid)
            }
            if !engaged { continue }
            var order: [String] = []
            var answered: [String: Bool] = [:]
            for selection in selections {
                if answered[selection.uuid] == nil { order.append(selection.uuid) }
                answered[selection.uuid] = (answered[selection.uuid] ?? false) || selection.selected
            }
            for uuid in order where !(answered[uuid] ?? false) {
                if let target = byUuid[uuid], isMandatory(target) {
                    return "mandatory \(uuid) missing for \(productUuid)"
                }
            }
        }
        return nil
    }

    private func everyRequiredTicked() -> SelectionState {
        var state = fresh(F.multiProduct)
        state = tickElement(state, F.shared, "el-email", A)
        state = tickElement(state, F.shared, "el-email", B)
        state = tickElement(state, F.scopedA, "el-address", A)
        return state
    }

    func testRendersASharedPurposeOncePerProductAndAScopedOneOnce() {
        XCTAssertEqual(InlineSelection.inlinePurposeRows(F.multiProduct).map(rowKey), [
            "\(A):pur-shared",
            "\(A):pur-scoped-a",
            "\(A):pur-wide",
            "\(B):pur-shared",
            "\(B):pur-only-b",
            "\(B):pur-wide",
        ])
    }

    func testKeepsASingleProductNoticeOnBarePurposeKeys() {
        for products in [nil, [NoticeProduct(uuid: A, name: "Product A")]] as [[NoticeProduct]?] {
            let rows = InlineSelection.inlinePurposeRows(F.config(products: products, purposes: [F.shared, F.scopedA]))
            XCTAssertEqual(rows.map(rowKey), ["pur-shared", "pur-scoped-a"])
            XCTAssertTrue(rows.allSatisfy { $0.productUuid == nil })
        }
    }

    func testFollowsTheSavedPerProductOrder() {
        let config = F.config(
            products: F.twoProducts,
            purposes: [F.shared, F.scopedA, F.onlyB, F.wide],
            order: [B: ["pur-wide", "pur-only-b", "pur-shared"]]
        )
        let underB = InlineSelection.inlinePurposeRows(config).filter { $0.productUuid == B }.map { $0.purpose.uuid }
        XCTAssertEqual(underB, ["pur-wide", "pur-only-b", "pur-shared"])
    }

    func testMandatoryProductsComeFirst() {
        let products = [
            NoticeProduct(uuid: A, name: "Product A", mandatory: false),
            NoticeProduct(uuid: B, name: "Product B", mandatory: true),
        ]
        let groups = ProductMatrix.groupPurposesByProduct(products, [F.shared, F.scopedA, F.onlyB, F.wide])
        XCTAssertEqual(groups.map { $0.product.uuid }, [B, A])
    }

    func testDropsAPurposeThatCoversNoProductOnTheNotice() {
        let orphan = F.purpose("pur-orphan", ["prod-gone"], [F.element("el-x", required: true)])
        let config = F.config(products: F.twoProducts, purposes: [F.shared, F.scopedA, F.onlyB, F.wide, orphan])
        XCTAssertFalse(InlineSelection.inlinePurposeRows(config).contains { $0.purpose.uuid == "pur-orphan" })
        XCTAssertTrue(gate(config, everyRequiredTicked()))
    }

    func testSeedsEveryRenderedRowCollapsedUnderTheKeyTheRowReads() {
        let rows = InlineSelection.inlinePurposeRows(F.multiProduct)
        let collapsed = InlineSelection.initialCollapsedPurposes(rows)
        XCTAssertTrue(rows.allSatisfy { collapsed[rowKey($0)] == true })
        XCTAssertNil(collapsed["pur-shared"])
    }

    func testSeedsASingleProductNoticeExactlyAsBeforeProducts() {
        let rows = InlineSelection.inlinePurposeRows(F.config(products: nil, purposes: [F.shared, F.scopedA]))
        XCTAssertEqual(InlineSelection.initialCollapsedPurposes(rows), ["pur-shared": true, "pur-scoped-a": true])
        let selection = InlineSelection.initialSelection(rows)
        XCTAssertEqual(selection.selectedPurposes, ["pur-shared": false, "pur-scoped-a": false])
        XCTAssertEqual(selection.selectedDataElements, [
            "pur-shared-el-email": false,
            "pur-shared-el-phone": false,
            "pur-scoped-a-el-address": false,
        ])
    }

    func testTicksTheSharedPurposeUnderOneProductWithoutTouchingTheOther() {
        let state = tickPurpose(fresh(F.multiProduct), F.shared, A)
        XCTAssertEqual(state.selectedPurposes["\(A):pur-shared"], true)
        XCTAssertEqual(state.selectedPurposes["\(B):pur-shared"], false)
        XCTAssertEqual(state.selectedDataElements["\(A):pur-shared-el-email"], true)
        XCTAssertEqual(state.selectedDataElements["\(B):pur-shared-el-email"], false)
    }

    func testSelectsARowFromItsOwnElementTicksOnly() {
        let state = tickElement(fresh(F.multiProduct), F.shared, "el-email", B)
        XCTAssertEqual(state.selectedPurposes["\(B):pur-shared"], true)
        XCTAssertEqual(state.selectedPurposes["\(A):pur-shared"], false)
    }

    func testDoesNotMarkAPurposeWhoseOnlyRequiredElementIsDisabled() {
        XCTAssertFalse(ProductConsent.hasRequiredDataElement(F.wide))
        XCTAssertFalse(ProductConsent.isBlockingRequiredElement(F.wide.dataElements[1]))
    }

    func testMarksAPurposeCarryingALiveRequiredElement() {
        XCTAssertTrue(ProductConsent.hasRequiredDataElement(F.shared))
        XCTAssertTrue(ProductConsent.isBlockingRequiredElement(F.shared.dataElements[0]))
    }

    func testGatePassesOnceTheSharedRequiredElementIsTickedUnderBothProducts() {
        let state = everyRequiredTicked()
        XCTAssertTrue(gate(F.multiProduct, state))
        XCTAssertNil(ledgerRefusal(F.multiProduct, wire(F.multiProduct, state)))
    }

    func testGateStaysBlockedWithTheSharedPurposeTickedUnderOneProductOnly() {
        var state = fresh(F.multiProduct)
        state = tickElement(state, F.shared, "el-email", A)
        state = tickElement(state, F.scopedA, "el-address", A)
        XCTAssertFalse(gate(F.multiProduct, state))
    }

    func testGateDoesNotDemandAScopedPurposeUnderAProductItDoesNotCover() {
        XCTAssertFalse(InlineSelection.inlinePurposeRows(F.multiProduct).map(rowKey).contains("\(B):pur-scoped-a"))
        XCTAssertTrue(gate(F.multiProduct, everyRequiredTicked()))
    }

    func testGateDoesNotDemandADisabledRequiredElement() {
        let state = everyRequiredTicked()
        XCTAssertEqual(state.selectedDataElements["\(A):pur-wide-el-legacy"], false)
        XCTAssertEqual(state.selectedDataElements["\(B):pur-wide-el-legacy"], false)
        XCTAssertTrue(gate(F.multiProduct, state))
    }

    func testGatePassesASingleProductNoticeOnceItsRequiredElementsAreTicked() {
        let config = F.config(products: nil, purposes: [F.shared, F.wide])
        let state = tickElement(fresh(config), F.shared, "el-email")
        XCTAssertTrue(gate(config, state))
        XCTAssertNil(ledgerRefusal(config, wire(config, state)))
    }

    func testGateBlocksTheSharedPurposeLeftUntickedUnderAnEngagedProduct() {
        var state = fresh(F.multiProduct)
        state = tickElement(state, F.shared, "el-email", A)
        state = tickElement(state, F.scopedA, "el-address", A)
        state = tickElement(state, F.onlyB, "el-device", B)
        XCTAssertEqual(ledgerRefusal(F.multiProduct, wire(F.multiProduct, state)), "mandatory pur-shared missing for \(B)")
        XCTAssertFalse(gate(F.multiProduct, state))
    }

    func testGateBlocksTheScopedMandatoryPurposeLeftUntickedUnderItsProduct() {
        var state = fresh(F.multiProduct)
        state = tickElement(state, F.shared, "el-email", A)
        state = tickElement(state, F.shared, "el-email", B)
        XCTAssertEqual(ledgerRefusal(F.multiProduct, wire(F.multiProduct, state)), "mandatory pur-scoped-a missing for \(A)")
        XCTAssertFalse(gate(F.multiProduct, state))
    }

    func testGateHoldsForEveryCombinationOfElementTicks() {
        let rows = InlineSelection.inlinePurposeRows(F.multiProduct)
        let switches = rows.flatMap { row in row.purpose.dataElements.map { (row, $0.uuid) } }
        XCTAssertEqual(switches.count, 10)
        var passed = 0
        for mask in 0..<(1 << switches.count) {
            var state = fresh(F.multiProduct)
            for (bit, entry) in switches.enumerated() where mask & (1 << bit) != 0 {
                state = tickElement(state, entry.0.purpose, entry.1, entry.0.productUuid)
            }
            if gate(F.multiProduct, state) {
                passed += 1
                XCTAssertNil(ledgerRefusal(F.multiProduct, wire(F.multiProduct, state)), "mask \(mask)")
            }
        }
        XCTAssertEqual(passed, 1 << 7)
    }

    func testSubmitSendsOneEntryPerRenderedRowEachCarryingItsProduct() {
        let state = tickPurpose(fresh(F.multiProduct), F.shared, A)
        let submitted = wire(F.multiProduct, state).map { "\($0.productUuid ?? "-")|\($0.uuid)|\($0.selected)" }
        XCTAssertEqual(submitted, [
            "\(A)|pur-shared|true",
            "\(A)|pur-scoped-a|false",
            "\(A)|pur-wide|false",
            "\(B)|pur-shared|false",
            "\(B)|pur-only-b|false",
            "\(B)|pur-wide|false",
        ])
    }

    func testSubmitSendsNoProductOnASingleProductNotice() {
        let config = F.config(products: [NoticeProduct(uuid: A, name: "Product A")], purposes: [F.shared])
        XCTAssertTrue(wire(config, fresh(config)).allSatisfy { $0.productUuid == nil })
    }

    func testSubmitPutsNoPurposeAndProductPairOnTheWireTwice() {
        let pairs = wire(F.multiProduct, fresh(F.multiProduct)).map { "\($0.productUuid ?? "")|\($0.uuid)" }
        XCTAssertEqual(Set(pairs).count, pairs.count)
        XCTAssertTrue(wire(F.multiProduct, fresh(F.multiProduct)).allSatisfy { $0.productUuid != nil })
    }

    func testSubmissionKeyChangesWithTheSelectionAndTheTokenOnly() {
        let state = fresh(F.multiProduct)
        let key = InlineSelection.inlineSubmissionKey(token: "t1", configUuid: "cfg-1", selection: state)
        XCTAssertEqual(key, InlineSelection.inlineSubmissionKey(token: "t1", configUuid: "cfg-1", selection: fresh(F.multiProduct)))
        XCTAssertNotEqual(key, InlineSelection.inlineSubmissionKey(token: "t2", configUuid: "cfg-1", selection: state))
        XCTAssertNotEqual(key, InlineSelection.inlineSubmissionKey(token: "t1", configUuid: "cfg-2", selection: state))
        XCTAssertNotEqual(key, InlineSelection.inlineSubmissionKey(token: "t1", configUuid: "cfg-1", selection: tickPurpose(state, F.shared, B)))
    }
}
