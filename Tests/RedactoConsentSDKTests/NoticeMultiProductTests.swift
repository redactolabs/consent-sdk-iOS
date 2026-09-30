import XCTest
@testable import RedactoConsentSDK

@MainActor
final class NoticeMultiProductTests: XCTestCase {
    typealias N = NoticeProductFixtures

    private let nothingChosen = "Select at least one purpose to confirm."
    private let nothingEngaged = "Select or change a purpose for the product you are consenting to."
    private func owes(_ names: String) -> String { "Accept the required purposes for \(names) to confirm." }

    private func twoProductNotice(
        mandatoryA: Bool? = false,
        mandatoryB: Bool? = false,
        purposes: [[String: Any]]? = nil,
        config: [String: Any] = [:],
        detail: [String: Any] = [:]
    ) throws -> ConsentContent {
        try N.notice(
            products: N.twoProducts(mandatoryA: mandatoryA, mandatoryB: mandatoryB),
            purposes: purposes ?? [N.shared, N.onlyA, N.onlyB],
            config: config,
            detail: detail
        )
    }

    func testDecodesTheProductFieldsOfTheNotice() throws {
        let content = try twoProductNotice(
            mandatoryB: nil,
            config: [
                "product_purpose_order": ["prod-a": ["purpose-only-a", "purpose-shared"]],
                "supported_languages_and_translations": ["Hindi": ["products": ["prod-a": "उत्पाद ए"]]],
            ],
            detail: ["product_purpose_selections": ["prod-a": ["purpose-shared": N.recorded()]]]
        )
        let ac = content.detail.activeConfig

        XCTAssertEqual(ac.products?.map(\.uuid), ["prod-a", "prod-b"])
        XCTAssertEqual(ac.products?.map(\.mandatory), [false, nil])
        XCTAssertEqual(ac.purposes.first?.productUuids, ["prod-a", "prod-b"])
        XCTAssertEqual(ac.productPurposeOrder?["prod-a"], ["purpose-only-a", "purpose-shared"])
        XCTAssertEqual(content.detail.productPurposeSelections?["prod-a"]?["purpose-shared"]?.selected, true)
        XCTAssertEqual(ac.supportedLanguagesAndTranslations["Hindi"]?.products?["prod-a"]?.nameValue, "उत्पाद ए")
    }

    func testANoticeWithoutProductFieldsStillDecodes() throws {
        let bare: [String: Any] = ["uuid": "p", "name": "P", "description": "", "data_elements": [N.element("e", "E")]]
        let content = try N.notice(products: nil, purposes: [bare])
        XCTAssertNil(content.detail.activeConfig.products)
        XCTAssertNil(content.detail.activeConfig.purposes[0].productUuids)
        XCTAssertNil(content.detail.productPurposeSelections)
    }

    func testRendersASectionPerProductAndRepeatsAPurposeItSpans() throws {
        let viewModel = N.viewModel(try twoProductNotice())

        XCTAssertTrue(viewModel.isMultiProduct)
        XCTAssertEqual(viewModel.productGroups.map(\.product.uuid), ["prod-a", "prod-b"])
        XCTAssertEqual(viewModel.productGroups.map { $0.purposes.map(\.uuid) }, [
            ["purpose-shared", "purpose-only-a"],
            ["purpose-shared", "purpose-only-b"],
        ])
    }

    func testCollapsesEveryProductOnFirstPaint() throws {
        let viewModel = N.viewModel(try twoProductNotice())
        XCTAssertEqual(viewModel.collapsedProducts, ["prod-a": true, "prod-b": true])
    }

    func testOpensTheProductsTheHostNamesAndIgnoresOneItDoesNotRender() throws {
        let viewModel = N.viewModel(try twoProductNotice(), defaultOpenProducts: ["prod-b", "prod-gone"])
        XCTAssertEqual(viewModel.collapsedProducts, ["prod-a": true, "prod-b": false])

        viewModel.toggleProductCollapse("prod-a")
        XCTAssertEqual(viewModel.collapsedProducts["prod-a"], false)
    }

    func testTheSectionCheckboxKeepsItsTicksThroughACollapseAndNeverOpensTheSection() throws {
        let viewModel = N.viewModel(try twoProductNotice())

        viewModel.handleProductCheckboxChange("prod-a")
        XCTAssertEqual(viewModel.collapsedProducts["prod-a"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)

        viewModel.toggleProductCollapse("prod-a")
        viewModel.toggleProductCollapse("prod-a")
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-b:purpose-shared"], false)
    }

    func testTheSectionCheckboxReachesOnlyTheRequiredPurposesAndIsMixedWhilePartial() throws {
        let secondA = N.requiredPurpose("purpose-second-a", "Second A", ["prod-a"])
        let viewModel = N.viewModel(try twoProductNotice(purposes: [N.shared, secondA, N.onlyA, N.onlyB]))
        let groupA = viewModel.productGroups[0].purposes
        let summary = { viewModel.sectionSummary(for: groupA, keyProductUuid: "prod-a") }

        XCTAssertEqual(summary().purposeCount, 2)
        XCTAssertTrue(summary().requiredOnly)

        viewModel.handlePurposeToggle("purpose-second-a", productUuid: "prod-a")
        XCTAssertTrue(summary().mixed)

        viewModel.handleProductCheckboxChange("prod-a")
        XCTAssertTrue(summary().allSelected)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-only-a"], false)

        viewModel.handleProductCheckboxChange("prod-a")
        XCTAssertFalse(summary().someSelected)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], false)
    }

    func testTicksASharedPurposeUnderOneProductOnlyAndSubmitsOneRowPerProduct() throws {
        let viewModel = N.viewModel(try twoProductNotice(), defaultOpenProducts: ["prod-a", "prod-b"])

        viewModel.handlePurposeToggle("purpose-shared", productUuid: "prod-a")

        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-b:purpose-shared"], false)
        XCTAssertFalse(viewModel.acceptDisabled)

        let sent = ProductConsent.submissionPurposes(
            rows: viewModel.purposeRows,
            selection: SelectionState(selectedPurposes: viewModel.selectedPurposes, selectedDataElements: viewModel.selectedDataElements),
            mode: .selected,
            recordedPurposeSelections: viewModel.recordedPurposeSelections,
            initialDataElementSelections: viewModel.initialDataElementSelections
        )
        XCTAssertEqual(sent.map { "\($0.uuid)/\($0.productUuid ?? "-")/\($0.selected)" }, [
            "purpose-shared/prod-a/true",
            "purpose-only-a/prod-a/false",
            "purpose-shared/prod-b/false",
            "purpose-only-b/prod-b/false",
        ])
    }

    func testTogglingADataElementKeysItToThePair() throws {
        let viewModel = N.viewModel(try twoProductNotice())

        viewModel.handleDataElementToggle("purpose-shared-id", purposeUuid: "purpose-shared", productUuid: "prod-b")

        XCTAssertEqual(viewModel.selectedDataElements["prod-b:purpose-shared-purpose-shared-id"], true)
        XCTAssertEqual(viewModel.selectedDataElements["prod-a:purpose-shared-purpose-shared-id"], false)
        XCTAssertEqual(viewModel.selectedPurposes["prod-b:purpose-shared"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], false)
    }

    func testHoldsConfirmOnFirstPaintAndNamesTheEngagedProductThatStillOwesAPurpose() throws {
        let viewModel = N.viewModel(try twoProductNotice())

        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, nothingChosen)

        viewModel.handlePurposeToggle("purpose-only-a", productUuid: "prod-a")
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, owes("Product A"))

        viewModel.handlePurposeToggle("purpose-shared", productUuid: "prod-a")
        XCTAssertFalse(viewModel.acceptDisabled)
        XCTAssertNil(viewModel.confirmHintText)
    }

    func testANoticeWidePurposeDoesNotEngageTheProductItRendersUnder() throws {
        let wide = N.optionalPurpose("purpose-wide", "Everywhere", [])
        let viewModel = N.viewModel(try twoProductNotice(purposes: [N.shared, N.onlyA, N.onlyB, wide]))

        viewModel.handlePurposeToggle("purpose-wide", productUuid: "prod-a")

        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-wide"], true)
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, nothingEngaged)
    }

    func testFloatsAClaimMandatoryProductFirstStarsItAndHoldsConfirmOnItBeforeAnyTouch() throws {
        let viewModel = N.viewModel(try twoProductNotice(mandatoryA: false, mandatoryB: true))

        XCTAssertEqual(viewModel.productGroups.map(\.product.uuid), ["prod-b", "prod-a"])
        XCTAssertTrue(viewModel.productIsRequired("prod-b"))
        XCTAssertFalse(viewModel.productIsRequired("prod-a"))
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, owes("Product B"))

        viewModel.handleProductCheckboxChange("prod-b")
        XCTAssertFalse(viewModel.acceptDisabled)
    }

    func testLetsAnyOneProductSatisfyConfirmWhenTheServerSendsNoPerProductMandatory() throws {
        let aReq = N.requiredPurpose("purpose-a-req", "A Required", ["prod-a"])
        let bReq = N.requiredPurpose("purpose-b-req", "B Required", ["prod-b"])
        let viewModel = N.viewModel(try N.notice(products: N.twoProducts(mandatoryA: nil, mandatoryB: nil), purposes: [aReq, bReq]))

        XCTAssertFalse(viewModel.productIsRequired("prod-a"))
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, "Accept the required purposes to confirm.")

        viewModel.handleProductCheckboxChange("prod-a")
        XCTAssertFalse(viewModel.acceptDisabled)
    }

    func testMarksASettledProductAndLocksItsSettledRowsLeavingAStaleGrantActionable() throws {
        let declined = N.recorded(selected: false, status: "DECLINED", needsReconsent: true)
        let stale = N.recorded(needsReconsent: true)
        let viewModel = N.viewModel(try twoProductNotice(detail: [
            "purpose_selections": ["purpose-shared": N.recorded(), "purpose-only-a": declined],
            "product_purpose_selections": [
                "prod-a": ["purpose-shared": N.recorded(), "purpose-only-a": declined],
                "prod-b": ["purpose-shared": stale],
            ],
        ]))

        XCTAssertEqual(viewModel.consentedProducts["prod-a"], true)
        XCTAssertEqual(viewModel.consentedProducts["prod-b"], false)
        XCTAssertTrue(viewModel.isRowLocked("purpose-shared", productUuid: "prod-a"))
        XCTAssertFalse(viewModel.isRowLocked("purpose-only-a", productUuid: "prod-a"))
        XCTAssertFalse(viewModel.isRowLocked("purpose-shared", productUuid: "prod-b"))
    }

    func testTheSectionCheckboxNeverClearsALockedRow() throws {
        let secondA = N.requiredPurpose("purpose-second-a", "Second A", ["prod-a"])
        let viewModel = N.viewModel(try twoProductNotice(
            purposes: [N.shared, secondA, N.onlyB],
            detail: [
                "purpose_selections": ["purpose-shared": N.recorded()],
                "product_purpose_selections": [
                    "prod-a": ["purpose-shared": N.recorded()],
                    "prod-b": ["purpose-shared": N.recorded(selected: false, status: "INACTIVE", needsReconsent: true)],
                ],
            ]
        ))

        viewModel.handleProductCheckboxChange("prod-a")
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-second-a"], true)
        viewModel.handleProductCheckboxChange("prod-a")

        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-second-a"], false)
        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)
    }

    func testPreTicksEachProductFromTheStateRecordedForItNotTheDowngradedFlatMap() throws {
        let viewModel = N.viewModel(try twoProductNotice(detail: [
            "purpose_selections": ["purpose-shared": N.recorded(selected: false, status: "INACTIVE", needsReconsent: true)],
            "product_purpose_selections": [
                "prod-a": ["purpose-shared": N.recorded(needsReconsent: true)],
                "prod-b": ["purpose-only-b": N.recorded(selected: false, status: "INACTIVE", needsReconsent: true)],
            ],
        ]))

        XCTAssertEqual(viewModel.selectedPurposes["prod-a:purpose-shared"], true)
        XCTAssertEqual(viewModel.selectedPurposes["prod-b:purpose-shared"], false)
    }

    func testTranslatesTheProductHeadingKeepingTheSourceNameWhereItHasNone() throws {
        let viewModel = N.viewModel(try twoProductNotice(config: [
            "supported_languages_and_translations": ["Hindi": ["products": ["prod-a": "उत्पाद ए"]]],
        ]))
        let products = try XCTUnwrap(viewModel.noticeProducts)

        viewModel.selectedLanguage = "Hindi"

        XCTAssertEqual(viewModel.productName(products[0]), "उत्पाद ए")
        XCTAssertEqual(viewModel.productName(products[1]), "Product B")
    }

    func testTheHintNamesAProductByItsTranslatedName() throws {
        let viewModel = N.viewModel(try twoProductNotice(config: [
            "supported_languages_and_translations": ["Hindi": ["products": ["prod-a": ["name": "उत्पाद ए", "description": ""]]]],
        ]))
        viewModel.selectedLanguage = "Hindi"

        viewModel.handlePurposeToggle("purpose-only-a", productUuid: "prod-a")

        XCTAssertEqual(viewModel.confirmHintText, owes("उत्पाद ए"))
    }

    func testAStaleGrantCanBeReaffirmedWithoutChangingAnything() throws {
        let viewModel = N.viewModel(try soleOptional(N.recorded(needsReconsent: true)))
        XCTAssertFalse(viewModel.acceptDisabled)
    }

    func testConfirmStaysOffForAnUntouchedGrantTheServerIsNotAskingAbout() throws {
        let viewModel = N.viewModel(try soleOptional(N.recorded()))
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, nothingEngaged)
    }

    private func soleOptional(_ selection: [String: Any]) throws -> ConsentContent {
        try N.notice(
            products: [N.product("prod-a", "Product A", mandatory: false)],
            purposes: [N.requiredPurpose("purpose-a-req", "A Required", ["prod-a"])],
            detail: [
                "purpose_selections": ["purpose-a-req": selection],
                "product_purpose_selections": ["prod-a": ["purpose-a-req": selection]],
            ]
        )
    }
}

@MainActor
final class NoticeSingleProductTests: XCTestCase {
    typealias N = NoticeProductFixtures

    private let orders = N.requiredPurpose("purpose-orders", "Order Fulfilment", [])
    private let marketing = N.optionalPurpose("purpose-marketing", "Marketing", [])

    func testDrawsTheSoleProductsHeadingOpenAndKeysByBarePurpose() throws {
        let viewModel = N.viewModel(try N.notice(products: [N.product("prod-a", "Product A", mandatory: true)], purposes: [orders, marketing]))

        XCTAssertFalse(viewModel.isMultiProduct)
        XCTAssertEqual(viewModel.soleProduct?.uuid, "prod-a")
        XCTAssertTrue(viewModel.productIsRequired("prod-a"))
        XCTAssertEqual(viewModel.collapsedProducts, ["prod-a": false])
        XCTAssertEqual(Set(viewModel.selectedPurposes.keys), ["purpose-orders", "purpose-marketing"])
        XCTAssertTrue(viewModel.acceptDisabled)
        XCTAssertEqual(viewModel.confirmHintText, "Accept the required purposes for Product A to confirm.")

        let summary = viewModel.sectionSummary(for: viewModel.activeConfig?.purposes ?? [], keyProductUuid: nil)
        XCTAssertEqual(summary.purposeCount, 1)
        XCTAssertTrue(summary.requiredOnly)

        viewModel.handleSoleProductCheckboxChange()
        XCTAssertEqual(viewModel.selectedPurposes, ["purpose-orders": true, "purpose-marketing": false])
        XCTAssertFalse(viewModel.acceptDisabled)

        let sent = ProductConsent.submissionPurposes(
            rows: viewModel.purposeRows,
            selection: SelectionState(selectedPurposes: viewModel.selectedPurposes, selectedDataElements: viewModel.selectedDataElements),
            mode: .selected,
            recordedPurposeSelections: viewModel.recordedPurposeSelections,
            initialDataElementSelections: viewModel.initialDataElementSelections
        )
        XCTAssertEqual(sent.map(\.uuid), ["purpose-orders", "purpose-marketing"])
        XCTAssertTrue(sent.allSatisfy { $0.productUuid == nil })
    }

    func testDrawsNoProductHeadingAndSendsNoProductUuidWithoutProducts() throws {
        let viewModel = N.viewModel(try N.notice(products: nil, purposes: [orders, marketing]))

        XCTAssertNil(viewModel.soleProduct)
        XCTAssertFalse(viewModel.isMultiProduct)
        XCTAssertTrue(viewModel.collapsedProducts.isEmpty)
        XCTAssertEqual(viewModel.confirmHintText, "Accept the required purposes to confirm.")

        viewModel.handlePurposeToggle("purpose-orders")
        XCTAssertNil(viewModel.confirmHintText)
        XCTAssertFalse(viewModel.acceptDisabled)
        XCTAssertTrue(viewModel.purposeRows.allSatisfy { $0.productUuid == nil })
    }

    func testEnablesConfirmOnFirstPaintWithNoProductsAndNothingMandatory() throws {
        let viewModel = N.viewModel(try N.notice(products: nil, purposes: [marketing]))
        XCTAssertFalse(viewModel.acceptDisabled)
    }

    func testLocksTheSoleProductHeadingInReviewMode() throws {
        let viewModel = N.viewModel(
            try N.notice(
                products: [N.product("prod-a", "Product A", mandatory: nil)],
                purposes: [orders, marketing],
                detail: ["purpose_selections": ["purpose-orders": N.recorded(), "purpose-marketing": N.recorded()]]
            ),
            includeFullyConsentedData: true
        )

        XCTAssertTrue(viewModel.soleProductLocked)
        XCTAssertTrue(viewModel.isRowLocked("purpose-orders", productUuid: nil))
    }

    func testTheSoleSectionCheckboxReachesEveryRequiredPurposeOutsideAReview() throws {
        let secondRequired = N.requiredPurpose("purpose-kyc", "KYC", [])
        let viewModel = N.viewModel(try N.notice(
            products: [N.product("prod-a", "Product A", mandatory: false)],
            purposes: [orders, secondRequired, marketing],
            detail: ["purpose_selections": ["purpose-orders": N.recorded()]]
        ))

        XCTAssertFalse(viewModel.isRowLocked("purpose-orders", productUuid: nil))
        viewModel.handleSoleProductCheckboxChange()
        XCTAssertEqual(viewModel.selectedPurposes["purpose-kyc"], true)
        viewModel.handleSoleProductCheckboxChange()

        XCTAssertEqual(viewModel.selectedPurposes["purpose-orders"], false)
        XCTAssertEqual(viewModel.selectedPurposes["purpose-kyc"], false)
        XCTAssertEqual(viewModel.selectedPurposes["purpose-marketing"], false)
    }

    func testNeverTicksARequiredElementThatIsDisabledFromEitherToggle() throws {
        let mixed: [String: Any] = [
            "uuid": "purpose-mixed",
            "name": "Mixed",
            "description": "",
            "product_uuids": ["prod-a"],
            "data_elements": [N.element("element-old", "Old ID", required: true, enabled: false), N.element("element-nick", "Nickname")],
        ]
        let content = try N.notice(products: N.twoProducts(), purposes: [mixed, N.onlyB])

        let bySection = N.viewModel(content)
        bySection.handleProductCheckboxChange("prod-a")
        XCTAssertEqual(bySection.selectedDataElements["prod-a:purpose-mixed-element-old"], false)
        XCTAssertEqual(bySection.selectedDataElements["prod-a:purpose-mixed-element-nick"], true)

        let byPurpose = N.viewModel(content)
        byPurpose.handlePurposeToggle("purpose-mixed", productUuid: "prod-a")
        XCTAssertEqual(byPurpose.selectedDataElements["prod-a:purpose-mixed-element-old"], false)
        XCTAssertEqual(byPurpose.selectedDataElements["prod-a:purpose-mixed-element-nick"], true)
    }
}
