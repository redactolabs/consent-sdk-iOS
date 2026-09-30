import XCTest
@testable import RedactoConsentSDK

final class ProductConsentGateTests: XCTestCase {
    typealias F = ProductFixtures

    private let notice = [F.shared, F.aReq, F.aOpt, F.bOpt]

    func testHoldsConfirmOnFirstPaintWithNothingChosen() {
        XCTAssertEqual(F.verdict(F.products(false, false), notice), ConfirmVerdict(ok: false, reason: .nothingChosen))
    }

    func testRefusesAnEngagedProductThatStillOwesAMandatoryPurpose() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), notice, ticked: [F.key(F.a, F.aOpt)]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
    }

    func testASharedPurposeTickedUnderOneProductDoesNotSatisfyTheOther() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), notice, ticked: [F.key(F.a, F.shared), F.key(F.a, F.aReq), F.key(F.b, F.bOpt)]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.b])
        )
    }

    func testConfirmsTheEngagedProductAloneLeavingTheUntouchedOneOut() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), notice, ticked: [F.key(F.a, F.shared), F.key(F.a, F.aReq)]),
            ConfirmVerdict(ok: true, reason: .ok)
        )
    }

    func testConfirmsAProductOnceEveryPurposeItRequiresIsTaken() {
        XCTAssertTrue(F.verdict(F.products(false, false), notice, ticked: [F.key(F.b, F.shared), F.key(F.b, F.bOpt)]).ok)
    }

    func testEngagesAClaimMandatoryProductBeforeAnyTouch() {
        XCTAssertEqual(
            F.verdict(F.products(true, false), notice),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
        XCTAssertTrue(F.verdict(F.products(true, false), notice, ticked: [F.key(F.a, F.shared), F.key(F.a, F.aReq)]).ok)
    }

    func testNamesEveryEngagedProductStillOwingAPurpose() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), notice, ticked: [F.key(F.a, F.aOpt), F.key(F.b, F.bOpt)]).blocking,
            [F.a, F.b]
        )
    }

    func testANoticeWideTickDoesNotEngageTheProductItRendersUnder() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), [F.aReq, F.bOpt, F.wideOpt], ticked: [F.key(F.a, F.wideOpt)]),
            ConfirmVerdict(ok: false, reason: .nothingEngaged)
        )
    }

    func testAnEngagedProductStillOwesANoticeWideMandatoryPurpose() {
        let wide = [F.aReq, F.bOpt, F.wideReq]
        XCTAssertEqual(
            F.verdict(F.products(false, false), wide, ticked: [F.key(F.a, F.aReq)]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
        XCTAssertTrue(F.verdict(F.products(false, false), wide, ticked: [F.key(F.a, F.aReq), F.key(F.a, F.wideReq)]).ok)
    }

    func testEveryRowEngagesItsProductWhenNoPurposeNamesOne() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), [F.wideReq, F.wideOpt], ticked: [F.key(F.a, F.wideOpt)]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
    }

    func testDoesNotEngageAProductTheVisitorArrivesConsentedTo() {
        let recordedNotice = [F.aReq, F.mandatoryPurpose("a-req-2", [F.a]), F.bOpt]
        XCTAssertEqual(
            F.verdict(F.products(false, false), recordedNotice, ticked: [F.key(F.a, F.aReq)], recorded: [F.key(F.a, F.aReq): true]),
            ConfirmVerdict(ok: false, reason: .nothingEngaged)
        )
    }

    func testRefusesAPartialDowngradeOfARecordedProduct() {
        XCTAssertEqual(
            F.verdict(F.products(false, false), [F.aReq, F.aOpt, F.bOpt], ticked: [F.key(F.a, F.aOpt)], recorded: [F.key(F.a, F.aReq): true]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
    }

    func testConfirmsAStaleGrantReaffirmedUnchanged() {
        XCTAssertTrue(F.verdict(F.sole(false), [F.aReq], ticked: [F.aReq.uuid], recorded: [F.aReq.uuid: false]).ok)
    }

    func testGatesTheSoleProductsMandatoryPurposesThoughItsRowsCarryNoProduct() {
        let soleNotice = [F.wideOpt, F.wideReq]
        XCTAssertEqual(
            F.verdict(F.sole(true), soleNotice, ticked: [F.wideOpt.uuid]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a])
        )
        XCTAssertTrue(F.verdict(F.sole(true), soleNotice, ticked: [F.wideOpt.uuid, F.wideReq.uuid]).ok)
    }

    func testConfirmsOnFirstPaintWhenTheMarkedSoleProductRequiresNothing() {
        XCTAssertTrue(F.verdict(F.sole(true), [F.wideOpt]).ok)
    }

    func testAsksForAChoiceWhenTheClaimLeavesTheSoleProductOptional() {
        XCTAssertEqual(F.verdict(F.sole(false), [F.wideOpt]), ConfirmVerdict(ok: false, reason: .nothingChosen))
        XCTAssertTrue(F.verdict(F.sole(false), [F.wideOpt], ticked: [F.wideOpt.uuid]).ok)
    }

    func testANoticeWithNoProductsRequiresEveryMandatoryPurpose() {
        XCTAssertEqual(F.verdict(nil, [F.wideReq, F.wideOpt]), ConfirmVerdict(ok: false, reason: .requiredOutstanding))
        XCTAssertTrue(F.verdict(nil, [F.wideReq, F.wideOpt], ticked: [F.wideReq.uuid]).ok)
    }

    func testANoticeWithNoMandatoryPurposeConfirmsWithNothingTicked() {
        XCTAssertTrue(F.verdict(nil, [F.wideOpt]).ok)
    }

    func testARequiredElementThatIsDisabledHoldsNobody() {
        let disabledOnly = F.purpose("disabled-req", [], elements: [F.element("off", required: true, enabled: false), F.element("on", required: false)])
        XCTAssertTrue(F.verdict(nil, [disabledOnly]).ok)
        XCTAssertFalse(ProductConsent.hasRequiredDataElement(disabledOnly))
    }

    func testLegacyLetsAnyOneProductSatisfyWhenEveryProductCarriesAMandatoryPurpose() {
        XCTAssertTrue(F.verdict(F.products(), [F.aReq, F.bReq], ticked: [F.key(F.a, F.aReq)]).ok)
        XCTAssertFalse(F.verdict(F.products(), [F.aReq, F.bReq]).ok)
    }

    func testLegacyKeepsTheAllProductsRuleWhenOneProductCarriesNoMandatoryPurpose() {
        XCTAssertFalse(F.verdict(F.products(), [F.aReq, F.bOpt]).ok)
        XCTAssertTrue(F.verdict(F.products(), [F.aReq, F.bOpt], ticked: [F.key(F.a, F.aReq)]).ok)
    }

    func testFallsBackToLegacyWhenOnlySomeProductsCarryTheField() {
        let partial = [NoticeProduct(uuid: F.a, name: "Product A", mandatory: false), NoticeProduct(uuid: F.b, name: "Product B")]
        XCTAssertEqual(F.verdict(partial, [F.aReq, F.bReq], ticked: [F.key(F.b, F.bReq)]), ConfirmVerdict(ok: true, reason: .ok))
    }

    func testLegacyBlocksWhileAnAnsweredProductIsHalfDone() {
        let split = [F.mandatoryPurpose("purpose-a", [F.a]), F.mandatoryPurpose("purpose-b1", [F.b]), F.mandatoryPurpose("purpose-b2", [F.b])]
        XCTAssertTrue(F.verdict(F.products(), split, ticked: ["prod-a:purpose-a"]).ok)
        XCTAssertEqual(
            F.verdict(F.products(), split, ticked: ["prod-a:purpose-a", "prod-b:purpose-b1"]),
            ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.b])
        )
        XCTAssertTrue(F.verdict(F.products(), split, ticked: ["prod-a:purpose-a", "prod-b:purpose-b1", "prod-b:purpose-b2"]).ok)
    }

    func testIsVacuouslySatisfiedOnAnEmptyNotice() {
        XCTAssertTrue(F.verdict(F.products(false, false), []).ok)
    }
}

final class ProductConsentBaselineTests: XCTestCase {
    typealias F = ProductFixtures

    private func baseline(_ recorded: PurposeSelection?) -> Bool? {
        let rows = ProductMatrix.noticePurposeRows(F.products(), [F.aReq, F.bOpt])
        let lookup = ProductConsent.recordedSelectionLookup(
            purposeSelections: recorded.map { [F.aReq.uuid: $0] },
            productPurposeSelections: nil
        )
        return ProductConsent.recordedBaseline(rows: rows, recordedFor: lookup)[F.key(F.a, F.aReq)]
    }

    func testCountsAnActiveGrantTheServerIsNotAskingAbout() {
        XCTAssertEqual(baseline(F.selection()), true)
    }

    func testDoesNotCountAnInactiveRowEvenOneArrivingSelected() {
        for status in ["EXPIRED", "WITHDRAW", "DECLINED", "INACTIVE"] {
            XCTAssertEqual(baseline(F.selection(status: status)), false, status)
        }
    }

    func testDoesNotCountAStaleGrantTheServerWantsReaffirmed() {
        XCTAssertEqual(baseline(F.selection(needsReconsent: true)), false)
    }

    func testCountsAStatuslessRecordedRow() {
        XCTAssertEqual(baseline(F.selection(status: "")), true)
    }

    func testDoesNotCountARowNothingWasRecordedFor() {
        XCTAssertEqual(baseline(nil), false)
    }

    private let gateNotice = [F.aReq, F.mandatoryPurpose("a-req-2", [F.a]), F.bOpt]

    private func gate(_ recordedA: PurposeSelection) -> ConfirmVerdict {
        let marked = F.products(false, false)
        let rows = ProductMatrix.noticePurposeRows(marked, gateNotice)
        let lookup = ProductConsent.recordedSelectionLookup(
            purposeSelections: [F.aReq.uuid: recordedA],
            productPurposeSelections: [F.a: [F.aReq.uuid: recordedA]]
        )
        return ProductConsent.confirmVerdict(
            products: marked,
            purposes: gateNotice,
            rows: rows,
            selectedPurposes: ProductConsent.seedSelection(rows: rows, recordedFor: lookup).selectedPurposes,
            recordedPurposeSelections: ProductConsent.recordedBaseline(rows: rows, recordedFor: lookup)
        )
    }

    func testEngagesAProductWhoseOnlyPreTickedRowIsNotActive() {
        for status in ["EXPIRED", "WITHDRAW", "DECLINED"] {
            XCTAssertEqual(gate(F.selection(status: status)), ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.a]), status)
        }
    }

    func testEngagesNothingOnAnInactiveRowTheLedgerSendsUnticked() {
        XCTAssertEqual(
            gate(F.selection(selected: false, status: "INACTIVE", needsReconsent: true)),
            ConfirmVerdict(ok: false, reason: .nothingChosen)
        )
    }

    func testDoesNotEngageTheSameProductWhileTheGrantIsStillActive() {
        XCTAssertEqual(gate(F.selection()), ConfirmVerdict(ok: false, reason: .nothingEngaged))
    }

    func testDoesNotEngageOnAStatuslessRecordedRow() {
        XCTAssertEqual(gate(F.selection(status: "")).reason, .nothingEngaged)
    }

    func testLetsAVisitorReaffirmAStaleGrantWithNothingElseToEngage() {
        let sole = F.sole(false)
        let rows = ProductMatrix.noticePurposeRows(sole, [F.aReq])
        func verdict(_ recorded: PurposeSelection) -> ConfirmVerdict {
            let lookup = ProductConsent.recordedSelectionLookup(
                purposeSelections: [F.aReq.uuid: recorded],
                productPurposeSelections: [F.a: [F.aReq.uuid: recorded]]
            )
            return ProductConsent.confirmVerdict(
                products: sole,
                purposes: [F.aReq],
                rows: rows,
                selectedPurposes: ProductConsent.seedSelection(rows: rows, recordedFor: lookup).selectedPurposes,
                recordedPurposeSelections: ProductConsent.recordedBaseline(rows: rows, recordedFor: lookup)
            )
        }
        XCTAssertTrue(verdict(F.selection(needsReconsent: true)).ok)
        XCTAssertEqual(verdict(F.selection()).reason, .nothingEngaged)
    }
}

final class ProductConsentHintTests: XCTestCase {
    typealias F = ProductFixtures

    private func hint(_ verdict: ConfirmVerdict) -> String? {
        ProductConsent.confirmHint(verdict, products: F.products()) { "translated \($0.name)" }
    }

    func testSaysNothingWhileConfirmIsLive() {
        XCTAssertNil(hint(ConfirmVerdict(ok: true, reason: .ok)))
    }

    func testExplainsEachNonProductReason() {
        XCTAssertEqual(hint(ConfirmVerdict(ok: false, reason: .nothingChosen)), "Select at least one purpose to confirm.")
        XCTAssertEqual(
            hint(ConfirmVerdict(ok: false, reason: .nothingEngaged)),
            "Select or change a purpose for the product you are consenting to."
        )
        XCTAssertEqual(hint(ConfirmVerdict(ok: false, reason: .requiredOutstanding)), "Accept the required purposes to confirm.")
    }

    func testNamesTheOwingProductsTheWayTheirHeadingsDo() {
        XCTAssertEqual(
            hint(ConfirmVerdict(ok: false, reason: .productIncomplete, blocking: [F.b, "gone"])),
            "Accept the required purposes for translated Product B, gone to confirm."
        )
    }
}

final class ProductConsentSelectionTests: XCTestCase {
    typealias F = ProductFixtures

    private let shared = F.mandatoryPurpose("shared", [F.a, F.b])
    private let flatDowngraded = F.selection(selected: false, status: "INACTIVE")
    private var perA: PurposeSelection {
        F.selection(dataElements: ["shared-req": DataElementSelection(selected: true, enabled: true, required: true)])
    }

    func testPrefersTheStateRecordedForTheProductAndFallsBackToTheFlatMap() {
        let lookup = ProductConsent.recordedSelectionLookup(
            purposeSelections: ["shared": flatDowngraded],
            productPurposeSelections: [F.a: ["shared": perA]]
        )
        XCTAssertEqual(lookup("shared", F.a)?.selected, true)
        XCTAssertEqual(lookup("shared", F.b)?.status, "INACTIVE")
        XCTAssertEqual(lookup("shared", nil)?.status, "INACTIVE")
    }

    func testPreTicksASharedPurposeOnlyUnderTheProductItWasConsentedFor() {
        let rows = ProductMatrix.noticePurposeRows(F.products(), [shared])
        let seeded = ProductConsent.seedSelection(
            rows: rows,
            recordedFor: ProductConsent.recordedSelectionLookup(
                purposeSelections: ["shared": flatDowngraded],
                productPurposeSelections: [F.a: ["shared": perA]]
            )
        )
        XCTAssertEqual(seeded.selectedPurposes, [F.key(F.a, shared): true, F.key(F.b, shared): false])
        XCTAssertEqual(seeded.selectedDataElements["\(F.key(F.a, shared))-shared-req"], true)
        XCTAssertEqual(seeded.selectedDataElements["\(F.key(F.b, shared))-shared-req"], false)
    }

    func testKeysASingleProductNoticeByPurposeAloneAsToday() {
        let rows = ProductMatrix.noticePurposeRows(F.sole(), [shared])
        let seeded = ProductConsent.seedSelection(
            rows: rows,
            recordedFor: ProductConsent.recordedSelectionLookup(purposeSelections: ["shared": perA], productPurposeSelections: nil)
        )
        XCTAssertEqual(seeded.selectedPurposes, ["shared": true])
        XCTAssertEqual(seeded.selectedDataElements.keys.sorted(), ["shared-shared-opt", "shared-shared-req"])
    }

    func testCollapsesEveryRowItSeeds() {
        let rows = ProductMatrix.noticePurposeRows(F.products(), [shared])
        XCTAssertEqual(ProductConsent.collapseEveryRow(rows), [F.key(F.a, shared): true, F.key(F.b, shared): true])
    }

    func testCollapsesEveryProductOnAMultiProductNotice() {
        let groups = ProductMatrix.groupPurposesByProduct(F.products(), [shared])
        XCTAssertEqual(ProductConsent.initialCollapsedProducts(groups: groups, defaultOpenProducts: nil), [F.a: true, F.b: true])
    }

    func testOpensTheProductsTheHostNamedAndIgnoresOneItDoesNotRender() {
        let groups = ProductMatrix.groupPurposesByProduct(F.products(), [shared])
        XCTAssertEqual(ProductConsent.initialCollapsedProducts(groups: groups, defaultOpenProducts: [F.b, "gone"]), [F.a: true, F.b: false])
    }

    func testOpensTheSoleSection() {
        let groups = ProductMatrix.groupPurposesByProduct(F.sole(), [shared])
        XCTAssertEqual(ProductConsent.initialCollapsedProducts(groups: groups, defaultOpenProducts: nil), [F.a: false])
    }
}

final class ProductConsentSettleTests: XCTestCase {
    typealias F = ProductFixtures

    private let notice = [F.aReq, F.aOpt, F.bOpt]

    private func settle(_ flat: [String: PurposeSelection]) -> SettledProducts {
        ProductConsent.settleProducts(
            rows: ProductMatrix.noticePurposeRows(F.products(), notice),
            products: F.products(),
            recordedFor: ProductConsent.recordedSelectionLookup(purposeSelections: flat, productPurposeSelections: nil)
        )
    }

    func testSettlesAProductOnceItsMandatoryPurposesAreRecordedOptionalOnesDeclined() {
        let settled = settle([
            F.aReq.uuid: F.selection(),
            F.aOpt.uuid: F.selection(selected: false, status: "DECLINED", needsReconsent: true),
            F.bOpt.uuid: F.selection(selected: false, status: "INACTIVE", needsReconsent: true),
        ])
        XCTAssertEqual(settled.consentedProducts, [F.a: true, F.b: false])
        XCTAssertEqual(settled.consentedPurposes[F.key(F.a, F.aReq)], true)
        XCTAssertEqual(settled.consentedPurposes[F.key(F.a, F.aOpt)], false)
    }

    func testDoesNotSettleAProductWhoseMandatoryGrantNeedsReconsent() {
        XCTAssertEqual(settle([F.aReq.uuid: F.selection(needsReconsent: true)]).consentedProducts[F.a], false)
    }

    func testJudgesAProductWithNoMandatoryPurposeOnEveryRow() {
        XCTAssertEqual(settle([F.bOpt.uuid: F.selection()]).consentedProducts[F.b], true)
        XCTAssertEqual(settle([:]).consentedProducts[F.b], false)
    }

    func testSettlesASingleProductNoticeUnderItsBarePurposeKeys() {
        let settled = ProductConsent.settleProducts(
            rows: ProductMatrix.noticePurposeRows(F.sole(), [F.aReq, F.aOpt]),
            products: F.sole(),
            recordedFor: ProductConsent.recordedSelectionLookup(purposeSelections: [F.aReq.uuid: F.selection()], productPurposeSelections: nil)
        )
        XCTAssertEqual(settled.consentedProducts, [F.a: true])
        XCTAssertEqual(settled.consentedPurposes, [F.aReq.uuid: true, F.aOpt.uuid: false])
    }

    func testSettlesNothingOnANoticeWithNoProducts() {
        let settled = ProductConsent.settleProducts(
            rows: ProductMatrix.noticePurposeRows(nil, [F.aReq]),
            products: nil,
            recordedFor: ProductConsent.recordedSelectionLookup(purposeSelections: [F.aReq.uuid: F.selection()], productPurposeSelections: nil)
        )
        XCTAssertEqual(settled, SettledProducts(consentedProducts: [:], consentedPurposes: [:]))
    }

    func testFullyConsentedReadsEachProductsOwnRecord() {
        let rows = ProductMatrix.noticePurposeRows(F.products(), [F.shared])
        XCTAssertTrue(ProductConsent.isFullyConsented(
            rows: rows,
            recordedFor: ProductConsent.recordedSelectionLookup(
                purposeSelections: nil,
                productPurposeSelections: [F.a: [F.shared.uuid: F.selection()], F.b: [F.shared.uuid: F.selection()]]
            )
        ))
        XCTAssertFalse(ProductConsent.isFullyConsented(
            rows: rows,
            recordedFor: ProductConsent.recordedSelectionLookup(
                purposeSelections: nil,
                productPurposeSelections: [F.a: [F.shared.uuid: F.selection()]]
            )
        ))
    }

    func testFullyConsentedReadsOnlyWhetherEveryRowIsSelected() {
        XCTAssertFalse(ProductConsent.isFullyConsented(rows: [], recordedFor: { _, _ in nil }))
        XCTAssertFalse(ProductConsent.isFullyConsented(
            rows: ProductMatrix.noticePurposeRows(nil, [F.shared]),
            recordedFor: ProductConsent.recordedSelectionLookup(
                purposeSelections: [F.shared.uuid: F.selection(selected: false)],
                productPurposeSelections: nil
            )
        ))
        XCTAssertTrue(ProductConsent.isFullyConsented(
            rows: ProductMatrix.noticePurposeRows(nil, [F.shared]),
            recordedFor: ProductConsent.recordedSelectionLookup(
                purposeSelections: [F.shared.uuid: F.selection(needsReconsent: true)],
                productPurposeSelections: nil
            )
        ))
    }
}

final class ProductConsentToggleTests: XCTestCase {
    typealias F = ProductFixtures

    private let withDisabled = F.purpose("mixed", [F.a], elements: [F.element("off", required: true, enabled: false), F.element("live", required: true)])

    func testSectionBoxReachesOnlyTheRequiredPurposesWhenTheProductHasAny() {
        XCTAssertEqual(ProductConsent.productBoxPurposes([F.aReq, F.aOpt]).map(\.uuid), [F.aReq.uuid])
    }

    func testSectionBoxReachesEveryPurposeWhenNoneIsRequired() {
        XCTAssertEqual(ProductConsent.productBoxPurposes([F.aOpt, F.bOpt]).map(\.uuid), [F.aOpt.uuid, F.bOpt.uuid])
    }

    func testSectionToggleFillsAPartlyTickedSectionUnderItsOwnProductOnly() {
        let next = ProductConsent.sectionToggle(sectionPurposes: [F.shared, F.aReq], keyProductUuid: F.a, selectedPurposes: [F.key(F.a, F.shared): true])
        XCTAssertEqual(next.selectedPurposes, [F.key(F.a, F.shared): true, F.key(F.a, F.aReq): true])
        XCTAssertNil(next.selectedPurposes[F.key(F.b, F.shared)])
    }

    func testSectionToggleClearsAFullyTickedSection() {
        let next = ProductConsent.sectionToggle(sectionPurposes: [F.aReq], keyProductUuid: F.a, selectedPurposes: [F.key(F.a, F.aReq): true])
        XCTAssertEqual(next.selectedPurposes[F.key(F.a, F.aReq)], false)
        XCTAssertEqual(next.selectedDataElements["\(F.key(F.a, F.aReq))-a-req-req"], false)
    }

    func testSectionToggleNeverTicksADisabledElement() {
        let next = ProductConsent.sectionToggle(sectionPurposes: [withDisabled], keyProductUuid: F.a, selectedPurposes: [:])
        XCTAssertEqual(next.selectedDataElements["\(F.key(F.a, withDisabled))-off"], false)
        XCTAssertEqual(next.selectedDataElements["\(F.key(F.a, withDisabled))-live"], true)
    }

    func testSectionToggleKeysASingleProductSectionByPurposeAlone() {
        XCTAssertEqual(
            Array(ProductConsent.sectionToggle(sectionPurposes: [F.aReq], keyProductUuid: nil, selectedPurposes: [:]).selectedPurposes.keys),
            [F.aReq.uuid]
        )
    }

    func testPurposeToggleNeverTicksADisabledElementAndStillTicksTheLiveOnes() {
        let mixed = F.purpose("mixed", [F.a], elements: [F.element("off", required: true, enabled: false), F.element("live", required: false)])
        let next = ProductConsent.purposeToggle(purpose: mixed, productUuid: F.b, selectedPurposes: [:])
        XCTAssertEqual(next.selectedPurposes, [F.key(F.b, mixed): true])
        XCTAssertEqual(next.selectedDataElements, ["\(F.key(F.b, mixed))-off": false, "\(F.key(F.b, mixed))-live": true])
    }

    func testPurposeToggleUnticksEveryElementWhenThePurposeClears() {
        let next = ProductConsent.purposeToggle(purpose: F.aReq, productUuid: F.a, selectedPurposes: [F.key(F.a, F.aReq): true])
        XCTAssertTrue(next.selectedDataElements.values.allSatisfy { !$0 })
    }

    private let mixedElements = F.purpose("mixed", [F.a], elements: [
        F.element("off", required: true, enabled: false),
        F.element("live-req", required: true),
        F.element("opt", required: false),
    ])

    func testTicksThePurposeOnceItsLiveRequiredElementsAreTickedIgnoringADisabledOne() {
        XCTAssertTrue(ProductConsent.purposeCheckedFromElements(
            purpose: mixedElements,
            productUuid: F.a,
            selectedDataElements: ["\(F.key(F.a, mixedElements))-live-req": true]
        ))
    }

    func testDoesNotTickItOnAnOptionalElementAloneWhileALiveRequiredOneIsOff() {
        XCTAssertFalse(ProductConsent.purposeCheckedFromElements(
            purpose: mixedElements,
            productUuid: F.a,
            selectedDataElements: ["\(F.key(F.a, mixedElements))-opt": true]
        ))
    }

    func testTicksAPurposeWithNoRequiredElementOnAnyElement() {
        XCTAssertTrue(ProductConsent.purposeCheckedFromElements(purpose: F.aOpt, productUuid: nil, selectedDataElements: ["a-opt-a-opt-opt": true]))
        XCTAssertFalse(ProductConsent.purposeCheckedFromElements(purpose: F.aOpt, productUuid: nil, selectedDataElements: [:]))
    }

    func testSectionSummaryIsMixedWhilePartial() {
        let secondA = F.mandatoryPurpose("second-a", [F.a])
        let partial = ProductConsent.sectionSummary(purposes: [F.shared, secondA, F.aOpt], keyProductUuid: F.a, selectedPurposes: [F.key(F.a, secondA): true])
        XCTAssertEqual(partial, ProductSectionSummary(purposeCount: 2, requiredOnly: true, allSelected: false, someSelected: true))
        XCTAssertTrue(partial.mixed)

        let full = ProductConsent.sectionSummary(
            purposes: [F.shared, secondA, F.aOpt],
            keyProductUuid: F.a,
            selectedPurposes: [F.key(F.a, secondA): true, F.key(F.a, F.shared): true]
        )
        XCTAssertTrue(full.allSelected)
        XCTAssertFalse(full.mixed)
    }

    func testSectionSummaryReadsItsOwnProductsKeysOnly() {
        let summary = ProductConsent.sectionSummary(purposes: [F.shared], keyProductUuid: F.b, selectedPurposes: [F.key(F.a, F.shared): true])
        XCTAssertFalse(summary.someSelected)
    }
}

final class ProductConsentSubmissionTests: XCTestCase {
    typealias F = ProductFixtures

    func testSendsOneRowPerProductWithItsProductUuidForAPurposeSpanningTwo() {
        let sent = ProductConsent.submissionPurposes(
            rows: ProductMatrix.noticePurposeRows(F.products(), [F.shared]),
            selection: SelectionState(
                selectedPurposes: [F.key(F.a, F.shared): true, F.key(F.b, F.shared): false],
                selectedDataElements: ["\(F.key(F.a, F.shared))-shared-req-opt": true]
            ),
            mode: .selected,
            recordedPurposeSelections: [:],
            initialDataElementSelections: [:]
        )
        XCTAssertEqual(sent.map(\.uuid), [F.shared.uuid, F.shared.uuid])
        XCTAssertEqual(sent.map(\.productUuid), [F.a, F.b])
        XCTAssertEqual(sent.map(\.selected), [true, false])
        XCTAssertEqual(sent[0].dataElements.map(\.selected), [true, true])
        XCTAssertEqual(sent[1].dataElements.map(\.selected), [true, false])
    }

    func testSendsASingleProductNoticeWithoutAProductUuid() {
        let sent = ProductConsent.submissionPurposes(
            rows: ProductMatrix.noticePurposeRows(F.sole(), [F.shared]),
            selection: SelectionState(selectedPurposes: [F.shared.uuid: true], selectedDataElements: [:]),
            mode: .selected,
            recordedPurposeSelections: [:],
            initialDataElementSelections: [:]
        )
        XCTAssertEqual(sent.count, 1)
        XCTAssertNil(sent[0].productUuid)
        XCTAssertTrue(sent[0].selected)
    }

    func testNeverSendsADisabledRequiredElementAsTicked() {
        let mixed = F.purpose("mixed", [F.a], elements: [F.element("old", required: true, enabled: false), F.element("nick", required: false)])
        let sent = ProductConsent.submissionPurposes(
            rows: ProductMatrix.noticePurposeRows(F.products(), [mixed, F.bOpt]),
            selection: SelectionState(selectedPurposes: [F.key(F.a, mixed): true], selectedDataElements: ["\(F.key(F.a, mixed))-nick": true]),
            mode: .selected,
            recordedPurposeSelections: [:],
            initialDataElementSelections: [:]
        )
        XCTAssertEqual(sent[0].dataElements.map(\.selected), [false, true])
    }

    func testAcceptAllTicksEveryPairAndOnlyEnabledElements() {
        let mixed = F.purpose("mixed", [], elements: [F.element("off", required: true, enabled: false), F.element("on", required: false)])
        let rows = ProductMatrix.noticePurposeRows(F.products(), [mixed])
        let all = ProductConsent.selectionForMode(rows: rows, mode: .all, current: SelectionState(selectedPurposes: [:], selectedDataElements: [:]))
        XCTAssertEqual(all.selectedPurposes, [F.key(F.a, mixed): true, F.key(F.b, mixed): true])
        XCTAssertEqual(all.selectedDataElements["\(F.key(F.a, mixed))-off"], false)
        XCTAssertEqual(all.selectedDataElements["\(F.key(F.b, mixed))-on"], true)
    }

    func testAModifiedRecordedPurposeIsSentSelected() {
        let rows = ProductMatrix.noticePurposeRows(F.products(), [F.shared])
        let elementKey = "\(F.key(F.a, F.shared))-shared-req-opt"
        let sent = ProductConsent.submissionPurposes(
            rows: rows,
            selection: SelectionState(selectedPurposes: [:], selectedDataElements: [elementKey: true]),
            mode: .selected,
            recordedPurposeSelections: [F.key(F.a, F.shared): true],
            initialDataElementSelections: [elementKey: false]
        )
        XCTAssertEqual(sent.map(\.selected), [true, false])
    }

    func testTheWirePayloadCarriesProductUuidOnlyWhenThereIsOne() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let pinned = ConsentPurposePayload(purposeUuid: "p1", productUuid: F.a, selected: true, dataElements: nil)
        let bare = ConsentPurposePayload(purposeUuid: "p1", selected: true, dataElements: nil)
        XCTAssertEqual(String(data: try encoder.encode(pinned), encoding: .utf8), #"{"product_uuid":"prod-a","purpose_uuid":"p1","selected":true}"#)
        XCTAssertEqual(String(data: try encoder.encode(bare), encoding: .utf8), #"{"purpose_uuid":"p1","selected":true}"#)
    }
}
