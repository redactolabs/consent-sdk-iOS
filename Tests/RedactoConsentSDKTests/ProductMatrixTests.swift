import XCTest
@testable import RedactoConsentSDK

final class ProductMatrixTests: XCTestCase {
    private func product(_ uuid: String, mandatory: Bool? = nil) -> NoticeProduct {
        NoticeProduct(uuid: uuid, name: uuid, mandatory: mandatory)
    }

    private func purpose(_ uuid: String, _ productUuids: [String]? = nil) -> ActiveConfigPurpose {
        ActiveConfigPurpose(uuid: uuid, name: uuid, description: "", industries: nil, dataElements: [], productUuids: productUuids)
    }

    private func uuids(_ purposes: [ActiveConfigPurpose]) -> [String] {
        purposes.map(\.uuid)
    }

    private func pairs(_ rows: [NoticePurposeRow]) -> [String] {
        rows.map { "\($0.productUuid ?? "-")/\($0.purpose.uuid)" }
    }

    func testCoversEveryProductWhenScopeIsAbsent() {
        XCTAssertTrue(ProductMatrix.purposeCoversProduct(purpose("p1"), "a"))
    }

    func testCoversEveryProductWhenScopeIsEmpty() {
        XCTAssertTrue(ProductMatrix.purposeCoversProduct(purpose("p1", []), "a"))
    }

    func testCoversOnlyANamedSubset() {
        let scoped = purpose("p1", ["a"])
        XCTAssertTrue(ProductMatrix.purposeCoversProduct(scoped, "a"))
        XCTAssertFalse(ProductMatrix.purposeCoversProduct(scoped, "b"))
    }

    func testKeyKeepsOnePurposesTwoProductsApart() {
        XCTAssertNotEqual(ProductMatrix.productPurposeKey("a", "p1"), ProductMatrix.productPurposeKey("b", "p1"))
        XCTAssertEqual(ProductMatrix.productPurposeKey("a", "p1"), "a:p1")
    }

    func testKeyCollapsesToTheBarePurposeWithoutAProduct() {
        XCTAssertEqual(ProductMatrix.productPurposeKey(nil, "p1"), "p1")
    }

    func testDataElementKeyIsPairKeyedOnlyWithAProduct() {
        XCTAssertEqual(dataElementKey(purposeUuid: "p1", elementUuid: "e1"), "p1-e1")
        XCTAssertEqual(dataElementKey(purposeUuid: "p1", elementUuid: "e1", productUuid: "a"), "a:p1-e1")
    }

    func testIsNotMultiProductWhenTheServerSendsNone() {
        XCTAssertFalse(ProductMatrix.isMultiProduct(nil))
    }

    func testIsNotMultiProductForASingleProduct() {
        XCTAssertFalse(ProductMatrix.isMultiProduct([product("a")]))
    }

    func testIsMultiProductPastOne() {
        XCTAssertTrue(ProductMatrix.isMultiProduct([product("a"), product("b")]))
    }

    func testGroupingPutsAnUnscopedPurposeUnderEveryProduct() {
        let groups = ProductMatrix.groupPurposesByProduct([product("a"), product("b")], [purpose("p1")])
        XCTAssertEqual(groups.map(\.product.uuid), ["a", "b"])
        XCTAssertEqual(uuids(groups[0].purposes), ["p1"])
        XCTAssertEqual(uuids(groups[1].purposes), ["p1"])
    }

    func testGroupingDropsAProductNoPurposeCovers() {
        let groups = ProductMatrix.groupPurposesByProduct([product("a"), product("b")], [purpose("p1", ["a"])])
        XCTAssertEqual(groups.map(\.product.uuid), ["a"])
    }

    func testGroupingOrdersEachProductIndependently() {
        let groups = ProductMatrix.groupPurposesByProduct(
            [product("a"), product("b")],
            [purpose("p1"), purpose("p2")],
            order: ["a": ["p1", "p2"], "b": ["p2", "p1"]]
        )
        XCTAssertEqual(uuids(groups[0].purposes), ["p1", "p2"])
        XCTAssertEqual(uuids(groups[1].purposes), ["p2", "p1"])
    }

    func testGroupingAppendsPurposesTheSavedOrderOmits() {
        let groups = ProductMatrix.groupPurposesByProduct([product("a")], [purpose("p1"), purpose("p2")], order: ["a": ["p2"]])
        XCTAssertEqual(uuids(groups[0].purposes), ["p2", "p1"])
    }

    func testGroupingIgnoresAnOrderNamingAPurposeThatIsGone() {
        let groups = ProductMatrix.groupPurposesByProduct([product("a")], [purpose("p1")], order: ["a": ["removed", "p1"]])
        XCTAssertEqual(uuids(groups[0].purposes), ["p1"])
    }

    func testGroupingIsEmptyWithoutProducts() {
        XCTAssertTrue(ProductMatrix.groupPurposesByProduct(nil, [purpose("p1")]).isEmpty)
        XCTAssertTrue(ProductMatrix.groupPurposesByProduct([], [purpose("p1")]).isEmpty)
    }

    func testMandatoryProductsFloatKeepingAuthoredOrderInEachGroup() {
        let authored = [product("b", mandatory: false), product("a", mandatory: true), product("d", mandatory: false), product("c", mandatory: true)]
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst(authored).map(\.uuid), ["a", "c", "b", "d"])
    }

    func testALegacyNoticeKeepsItsAuthoredOrder() {
        let authored = [product("b"), product("a"), product("c")]
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst(authored), authored)
    }

    func testAProductWhoseMandatoryIsOmittedDoesNotFloat() {
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst([product("a"), product("b", mandatory: true)]).map(\.uuid), ["b", "a"])
    }

    func testTheOrderStaysWhenThePartitionCannotMoveAnything() {
        let none = [product("b", mandatory: false), product("a", mandatory: false)]
        let all = [product("b", mandatory: true), product("a", mandatory: true)]
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst(none), none)
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst(all), all)
    }

    func testMandatoryFirstDoesNotReorderWithinAGroup() {
        let authored = [product("z", mandatory: true), product("y", mandatory: false), product("x", mandatory: true), product("w", mandatory: false)]
        XCTAssertEqual(ProductMatrix.mandatoryProductsFirst(authored).map(\.uuid), ["z", "x", "y", "w"])
    }

    func testGroupingCarriesTheMandatoryPartition() {
        let groups = ProductMatrix.groupPurposesByProduct([product("b", mandatory: false), product("a", mandatory: true)], [purpose("p1")])
        XCTAssertEqual(groups.map(\.product.uuid), ["a", "b"])
    }

    func testExpansionIsEmptyOnASingleProductNotice() {
        XCTAssertTrue(ProductMatrix.expandPurposesByProduct([product("a")], [purpose("p1")]).isEmpty)
    }

    func testExpansionEmitsOneRowPerCoveredPair() {
        let rows = ProductMatrix.expandPurposesByProduct([product("a"), product("b")], [purpose("p1"), purpose("p2", ["b"])])
        XCTAssertEqual(pairs(rows), ["a/p1", "b/p1", "b/p2"])
    }

    func testRowsCarryNoProductBelowTwoProducts() {
        XCTAssertEqual(pairs(ProductMatrix.noticePurposeRows([product("a")], [purpose("p1")])), ["-/p1"])
        XCTAssertEqual(pairs(ProductMatrix.noticePurposeRows(nil, [purpose("p1"), purpose("p2")])), ["-/p1", "-/p2"])
    }

    func testRowsArePerCoveredPairPastOneProduct() {
        XCTAssertEqual(pairs(ProductMatrix.noticePurposeRows([product("a"), product("b")], [purpose("p1", ["b"])])), ["b/p1"])
    }

    func testRowsDropAPurposeCoveringNoProduct() {
        let rows = ProductMatrix.noticePurposeRows([product("a"), product("b")], [purpose("p1", ["a"]), purpose("orphan", ["gone"])])
        XCTAssertEqual(pairs(rows), ["a/p1"])
    }

    func testNamesOnlyAProductThePurposeLists() {
        XCTAssertTrue(ProductMatrix.purposeNamesProduct(purpose("p", ["prod-a"]), "prod-a"))
        XCTAssertFalse(ProductMatrix.purposeNamesProduct(purpose("p", ["prod-a"]), "prod-b"))
    }

    func testANoticeWidePurposeCoversButNamesNothing() {
        for unscoped in [purpose("p", []), purpose("p")] {
            XCTAssertTrue(ProductMatrix.purposeCoversProduct(unscoped, "prod-a"))
            XCTAssertFalse(ProductMatrix.purposeNamesProduct(unscoped, "prod-a"))
        }
    }

    func testNoticeScopesPurposesOnceAnyPurposeNamesAProduct() {
        XCTAssertTrue(ProductMatrix.noticeScopesPurposes([purpose("a", []), purpose("b", ["prod-b"])]))
    }

    func testNoticeDoesNotScopePurposesWhenNoneNamesAnything() {
        XCTAssertFalse(ProductMatrix.noticeScopesPurposes([purpose("a", []), purpose("b")]))
        XCTAssertFalse(ProductMatrix.noticeScopesPurposes([]))
    }

    func testServerMarksMandatoryWhenEveryProductCarriesTheField() {
        XCTAssertTrue(ProductMatrix.serverMarksMandatoryProducts([product("a", mandatory: true), product("b", mandatory: false)]))
    }

    func testServerDoesNotMarkMandatoryWhenNoProductCarriesTheField() {
        XCTAssertFalse(ProductMatrix.serverMarksMandatoryProducts([product("a"), product("b")]))
    }

    func testServerDoesNotMarkMandatoryWhenOnlySomeProductsCarryTheField() {
        XCTAssertFalse(ProductMatrix.serverMarksMandatoryProducts([product("a", mandatory: true), product("b")]))
    }

    func testServerDoesNotMarkMandatoryForAnEmptyOrAbsentList() {
        XCTAssertFalse(ProductMatrix.serverMarksMandatoryProducts([]))
        XCTAssertFalse(ProductMatrix.serverMarksMandatoryProducts(nil))
    }

    func testGatedProductsAreOnlyTheMarkedOnes() {
        XCTAssertEqual(ProductMatrix.gatedProductUuids([product("a", mandatory: true), product("b", mandatory: false)]), ["a"])
    }

    func testASingleMarkedProductIsGated() {
        XCTAssertEqual(ProductMatrix.gatedProductUuids([product("a", mandatory: true)]), ["a"])
    }

    func testNothingIsGatedWhenTheServerMarkedNothing() {
        XCTAssertTrue(ProductMatrix.gatedProductUuids([product("a", mandatory: false), product("b", mandatory: false)]).isEmpty)
        XCTAssertTrue(ProductMatrix.gatedProductUuids([]).isEmpty)
        XCTAssertTrue(ProductMatrix.gatedProductUuids(nil).isEmpty)
    }

    func testAnUnlabelledRowOnASingleProductNoticeResolvesToThatProduct() {
        XCTAssertEqual(ProductMatrix.rowProductUuid(nil, [product("a")]), "a")
        XCTAssertNil(ProductMatrix.rowProductUuid(nil, [product("a"), product("b")]))
        XCTAssertNil(ProductMatrix.rowProductUuid(nil, nil))
        XCTAssertEqual(ProductMatrix.rowProductUuid("b", [product("a"), product("b")]), "b")
    }

    func testTheGateCoversASingleProductNoticeWhoseRowsCarryNoProduct() {
        let products = [product("a", mandatory: true)]
        let rows = ProductMatrix.noticePurposeRows(products, [purpose("p1")])
        XCTAssertTrue(rows.allSatisfy { $0.productUuid == nil })
        XCTAssertEqual(ProductMatrix.rowsUnderGate(rows, products).map(\.purpose.uuid), ["p1"])
    }

    func testTheGateCoversNothingOnAnUnmarkedSingleProductNotice() {
        let products = [product("a", mandatory: false)]
        XCTAssertTrue(ProductMatrix.rowsUnderGate(ProductMatrix.noticePurposeRows(products, [purpose("p1")]), products).isEmpty)
    }

    func testTheGateCoversOnlyTheMarkedProductsRows() {
        let products = [product("a", mandatory: true), product("b", mandatory: false)]
        let rows = ProductMatrix.noticePurposeRows(products, [purpose("p1")])
        XCTAssertEqual(ProductMatrix.rowsUnderGate(rows, products).map(\.productUuid), ["a"])
    }

    func testTheGateCoversEveryRowWhenEveryProductIsMarked() {
        let products = [product("a", mandatory: true), product("b", mandatory: true)]
        XCTAssertEqual(ProductMatrix.rowsUnderGate(ProductMatrix.noticePurposeRows(products, [purpose("p1")]), products).count, 2)
    }

    func testTheGateCoversNothingWithoutProducts() {
        XCTAssertTrue(ProductMatrix.rowsUnderGate(ProductMatrix.noticePurposeRows([], [purpose("p1")]), []).isEmpty)
    }

    func testTheHeadingStarFollowsTheGateNotTheNotice() {
        XCTAssertTrue(ProductMatrix.productIsRequired("a", [product("a", mandatory: true), product("b", mandatory: false)]))
        XCTAssertFalse(ProductMatrix.productIsRequired("b", [product("a", mandatory: true), product("b", mandatory: false)]))
        XCTAssertFalse(ProductMatrix.productIsRequired("a", [product("a", mandatory: true), product("b")]))
        XCTAssertTrue(ProductMatrix.productIsRequired(nil, [product("a", mandatory: true)]))
    }
}
