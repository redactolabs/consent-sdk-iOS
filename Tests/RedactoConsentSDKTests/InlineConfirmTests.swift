import XCTest
@testable import RedactoConsentSDK

/// The inline notice runs the "confirm before submitting" step (React
/// 80c68a0, 4bd8ef2, 6f98d02, 349de4f). It has no accept button, so the
/// question gates the automatic submission.
final class InlineConfirmTests: XCTestCase {
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

    private func install(submits: [TransportStubResponse] = [.text(201, "{}")]) {
        RouteStub.install([
            "/notices/": [F.noticeResponse(F.config(products: F.twoProducts, purposes: [marketing]))],
            "submit-consent": submits,
        ])
    }

    @MainActor
    private func loaded(
        token: String? = "tok",
        confirm: Bool? = true,
        counter: FlowCounter
    ) async -> ConsentInlineViewModel {
        var settings: ConsentSettings?
        if let confirm {
            settings = ConsentSettings(confirmBeforeSubmit: confirm)
        }
        let viewModel = ConsentInlineViewModel(
            orgUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            accessToken: token,
            baseUrl: "https://api.example.test/consent",
            onAccept: { counter.accepts += 1 },
            onError: { _ in counter.errors += 1 },
            settings: settings
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

    @MainActor
    func testAsksBeforeTheAutomaticSubmissionAndSendsNothingYet() async {
        install()
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        await settle(viewModel)

        XCTAssertTrue(viewModel.awaitingConfirm)
        XCTAssertTrue(submits.isEmpty)
        XCTAssertEqual(counter.accepts, 0)
    }

    @MainActor
    func testSubmitsOnceConfirmed() async {
        install()
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        viewModel.confirmSubmission()
        await settle(viewModel)

        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testDoesNotAskAgainAfterItSubmitted() async {
        install()
        let viewModel = await loaded(counter: FlowCounter())

        viewModel.confirmSubmission()
        await settle(viewModel)
        viewModel.checkValidationAndAutoSubmit()

        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertEqual(submits.count, 1)
    }

    @MainActor
    func testDecliningStopsThatSubmissionWithoutSilencingALaterChange() async {
        install()
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        viewModel.refuseSubmission()
        viewModel.checkValidationAndAutoSubmit()
        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertTrue(submits.isEmpty)

        viewModel.handlePurposeToggle("pur-marketing", productUuid: A)

        XCTAssertTrue(viewModel.awaitingConfirm)
        XCTAssertTrue(submits.isEmpty)
        XCTAssertEqual(counter.accepts, 0)
    }

    @MainActor
    func testAFailedConfirmedSubmissionAsksAgain() async {
        install(submits: [.text(500, "{}"), .text(201, "{}")])
        let counter = FlowCounter()
        let viewModel = await loaded(counter: counter)

        viewModel.confirmSubmission()
        await settle(viewModel)

        XCTAssertEqual(counter.errors, 1)
        XCTAssertTrue(viewModel.awaitingConfirm)

        viewModel.confirmSubmission()
        await settle(viewModel)

        XCTAssertEqual(submits.count, 2)
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testANewTokenReleasesARefusal() async {
        install()
        let viewModel = await loaded(counter: FlowCounter())

        viewModel.refuseSubmission()
        await viewModel.updateAccessToken("second")?.value
        await settle(viewModel)

        XCTAssertTrue(viewModel.awaitingConfirm)
        XCTAssertTrue(submits.isEmpty)
    }

    @MainActor
    func testWithoutTheStepItSubmitsStraightAway() async {
        install()
        let viewModel = await loaded(confirm: nil, counter: FlowCounter())

        await settle(viewModel)

        XCTAssertFalse(viewModel.confirmBeforeSubmit)
        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertEqual(submits.count, 1)
    }

    @MainActor
    func testTheHostCanTurnTheConsoleStepOff() async {
        install()
        let viewModel = await loaded(confirm: false, counter: FlowCounter())

        await settle(viewModel)

        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertEqual(submits.count, 1)
    }

    @MainActor
    func testNeverAsksWithoutAToken() async {
        install()
        let viewModel = await loaded(token: nil, counter: FlowCounter())

        viewModel.checkValidationAndAutoSubmit()

        XCTAssertFalse(viewModel.awaitingConfirm)
        XCTAssertTrue(submits.isEmpty)
    }
}
