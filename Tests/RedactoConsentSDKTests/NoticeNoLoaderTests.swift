import XCTest
@testable import RedactoConsentSDK

/// Nothing is painted before the notice read answers, ported from the React
/// SDK's 9235732 (RedactoNoticeConsent.test.tsx). The read answers "already
/// consented" with a 409, so a loader drawn first flashed for one round trip
/// at principals who were then never shown the notice.
@MainActor
final class NoticeNoLoaderTests: XCTestCase {
    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    private func serve(_ data: @escaping (TransportStubRequest) -> TransportStubResponse) async {
        await ConsentAPI.clearCache()
        TransportStubProtocol.install(data)
    }

    nonisolated private static func noticeJSON() -> Any {
        try! JSONSerialization.jsonObject(with: NoticeFixtures.contentData(config: [:]))
    }

    private func makeViewModel(
        accessToken: String = NoticeFixtures.agentToken,
        blockUI: Bool = true,
        onAccept: @escaping () -> Void = {}
    ) -> ConsentNoticeViewModel {
        ConsentNoticeViewModel(
            noticeId: "notice-1",
            accessToken: accessToken,
            refreshToken: "",
            baseUrl: NoticeFixtures.baseUrl,
            blockUI: blockUI,
            onAccept: onAccept,
            onDecline: {}
        )
    }

    func testOnlyAnInvisibleBackdropBlocksTheScreenWhileTheReadIsInFlight() async {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(200, Self.noticeJSON())
        }
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.paintStage, .blockingBackdrop)

        let task = viewModel.fetchContent()
        XCTAssertEqual(viewModel.paintStage, .blockingBackdrop)
        await task.value

        XCTAssertNotNil(viewModel.content)
        XCTAssertEqual(viewModel.paintStage, .dialog)
    }

    func testNothingIsPaintedWhileLoadingWhenTheHostTurnsTheBackdropOff() async {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(200, Self.noticeJSON())
        }
        let viewModel = makeViewModel(blockUI: false)
        XCTAssertEqual(viewModel.paintStage, .nothing)

        await viewModel.fetchContent().value
        XCTAssertEqual(viewModel.paintStage, .dialog)
    }

    func testAnAlreadyConsentedPrincipalGetsOnAcceptWithNothingPainted() async {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(409, ["message": "Already consented."])
        }
        let accepted = CallCounter()
        let viewModel = makeViewModel(onAccept: { accepted.count += 1 })
        XCTAssertNotEqual(viewModel.paintStage, .dialog)

        await viewModel.fetchContent().value

        XCTAssertEqual(accepted.count, 1)
        XCTAssertTrue(viewModel.hasAlreadyConsented)
        XCTAssertEqual(viewModel.paintStage, .nothing)
    }

    func testAFailedReadDrawsTheErrorDialog() async {
        await serve { _ in .json(500, ["message": "Notice unavailable."]) }
        let viewModel = makeViewModel()

        await viewModel.fetchContent().value

        XCTAssertEqual(viewModel.fetchErrorMessage, "Notice unavailable.")
        XCTAssertEqual(viewModel.paintStage, .dialog)
    }

    func testAConfigurationErrorDrawsTheDialogWithoutReading() async {
        await serve { _ in .json(200, Self.noticeJSON()) }
        let viewModel = makeViewModel(accessToken: " ")

        await viewModel.fetchContent().value

        XCTAssertNotNil(viewModel.configurationErrorMessage)
        XCTAssertTrue(TransportStubProtocol.requests.isEmpty)
        XCTAssertEqual(viewModel.paintStage, .dialog)
    }
}
