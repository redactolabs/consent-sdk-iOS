import XCTest
@testable import RedactoConsentSDK

final class InlineAutoSubmitTests: XCTestCase {
    private typealias F = InlineFixtures
    private let A = InlineFixtures.productA
    private let B = InlineFixtures.productB
    private let marketing = InlineFixtures.purpose(
        "pur-marketing",
        [InlineFixtures.productA, InlineFixtures.productB],
        [InlineFixtures.element("el-phone")]
    )

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    private var optionalOnly: ActiveConfig {
        F.config(products: F.twoProducts, purposes: [marketing])
    }

    private func install(_ config: ActiveConfig, submits: [TransportStubResponse] = [.text(201, "{}")]) {
        RouteStub.install([
            "/notices/": [F.noticeResponse(config)],
            "submit-consent": submits,
        ])
    }

    @MainActor
    private func loaded(token: String?, counter: FlowCounter) async -> ConsentInlineViewModel {
        let viewModel = ConsentInlineViewModel(
            orgUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            accessToken: token,
            baseUrl: "https://api.example.test/consent",
            onAccept: { counter.accepts += 1 },
            onError: { _ in counter.errors += 1 }
        )
        await viewModel.fetchNotice().value
        return viewModel
    }

    @MainActor
    private func settle(_ viewModel: ConsentInlineViewModel) async {
        while let task = viewModel.submitTask {
            await task.value
        }
    }

    private var submits: [TransportStubRequest] {
        RouteStub.requests(matching: "submit-consent")
    }

    private func selections(_ index: Int) -> [String: Bool] {
        var result: [String: Bool] = [:]
        guard index < submits.count else { return result }
        let purposes = (submits[index].json["purposes"] as? [[String: Any]]) ?? []
        for entry in purposes {
            let key = "\(entry["product_uuid"] as? String ?? "-"):\(entry["purpose_uuid"] as? String ?? "")"
            result[key] = entry["selected"] as? Bool
        }
        return result
    }

    @MainActor
    func testDoesNotSubmitAnUnchangedSelectionAgain() async {
        install(optionalOnly)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)
        viewModel.checkValidationAndAutoSubmit()
        viewModel.updateAccessToken("tok")
        await settle(viewModel)

        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testWaitsForEveryRequiredPairThenSubmitsOncePerPair() async {
        install(F.multiProduct)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.handlePurposeToggle("pur-shared", productUuid: A)
        viewModel.handlePurposeToggle("pur-scoped-a", productUuid: A)
        await settle(viewModel)
        XCTAssertEqual(submits.count, 0)

        viewModel.handlePurposeToggle("pur-shared", productUuid: B)
        await settle(viewModel)
        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)

        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(selections(0), [
            "\(A):pur-shared": true,
            "\(A):pur-scoped-a": true,
            "\(A):pur-wide": false,
            "\(B):pur-shared": true,
            "\(B):pur-only-b": false,
            "\(B):pur-wide": false,
        ])
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testHoldsTheSubmitWhileOneProductsCopyOfTheSharedPurposeIsUnticked() async {
        install(F.multiProduct)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.handlePurposeToggle("pur-shared", productUuid: B)
        viewModel.handlePurposeToggle("pur-scoped-a", productUuid: A)
        await settle(viewModel)

        XCTAssertEqual(submits.count, 0)
        XCTAssertEqual(counter.accepts, 0)
    }

    @MainActor
    func testCollapseStateIsKeyedByPair() async {
        install(F.multiProduct)
        let viewModel = await loaded(token: nil, counter: FlowCounter())

        viewModel.handlePurposeCollapse("pur-shared", productUuid: A)

        XCTAssertEqual(viewModel.collapsedPurposes["\(A):pur-shared"], false)
        XCTAssertEqual(viewModel.collapsedPurposes["\(B):pur-shared"], true)
        XCTAssertNil(viewModel.collapsedPurposes["pur-shared"])
    }

    @MainActor
    func testDoesNotRetryAFailedSubmitOfAnUnchangedSelection() async {
        install(optionalOnly, submits: [.text(409, #"{"detail":"consent already recorded"}"#)])
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)
        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)

        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(counter.errors, 1)
        XCTAssertEqual(counter.accepts, 0)
    }

    @MainActor
    func testSubmitsOnceMoreWhenTheSelectionChangesAfterASuccess() async {
        install(optionalOnly)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)
        viewModel.handlePurposeToggle("pur-marketing", productUuid: A)
        await settle(viewModel)

        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(selections(1), ["\(A):pur-marketing": true, "\(B):pur-marketing": false])
        XCTAssertEqual(counter.accepts, 2)
    }

    @MainActor
    func testSubmitsAChangeMadeWhileTheFirstSubmitWasInFlightOnceItLands() async {
        install(optionalOnly)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        viewModel.handlePurposeToggle("pur-marketing", productUuid: B)
        await settle(viewModel)

        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(selections(0), ["\(A):pur-marketing": false, "\(B):pur-marketing": false])
        XCTAssertEqual(selections(1), ["\(A):pur-marketing": false, "\(B):pur-marketing": true])
    }

    @MainActor
    func testSubmitsAChangedSelectionAfterAFailedSubmit() async {
        install(optionalOnly, submits: [.text(500, "{}"), .text(201, "{}")])
        let counter = FlowCounter()
        let viewModel = await loaded(token: "tok", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)
        viewModel.handlePurposeToggle("pur-marketing", productUuid: B)
        await settle(viewModel)

        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(counter.errors, 1)
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testSubmitsAgainOnceUnderANewAccessToken() async {
        install(optionalOnly)
        let counter = FlowCounter()
        let viewModel = await loaded(token: "first", counter: counter)

        viewModel.checkValidationAndAutoSubmit()
        await settle(viewModel)
        await viewModel.updateAccessToken("second")?.value
        await settle(viewModel)
        XCTAssertNil(viewModel.updateAccessToken("second"))
        await settle(viewModel)

        XCTAssertEqual(submits.map { $0.header("Authorization") ?? "" }, ["Bearer first", "Bearer second"])
    }

    @MainActor
    func testSingleProductNoticeSubmitsBarePurposes() async {
        let config = F.config(
            products: [NoticeProduct(uuid: A, name: "Product A")],
            purposes: [F.purpose("pur-1", [A], [F.element("el-email", required: true)])]
        )
        install(config)
        let viewModel = await loaded(token: "tok", counter: FlowCounter())

        viewModel.handlePurposeToggle("pur-1")
        await settle(viewModel)

        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(selections(0), ["-:pur-1": true])
    }
}
