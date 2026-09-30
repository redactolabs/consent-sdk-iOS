import XCTest
@testable import RedactoConsentSDK

/// What the inline notice does on load, before the reader touches anything —
/// mirrors React's derived-validity effect, its pre-selection seeding and its
/// per-identity read.
final class InlineLoadTests: XCTestCase {
    private typealias F = InlineFixtures

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    private let requiredOnly = F.config(
        products: nil,
        purposes: [F.purpose("pur-1", nil, [F.element("el-email", required: true)])]
    )
    private let optionalOnly = F.config(
        products: nil,
        purposes: [F.purpose("pur-1", nil, [F.element("el-email")])]
    )

    private func install(_ config: ActiveConfig, notices: [TransportStubResponse]? = nil) {
        RouteStub.install([
            "/notices/": notices ?? [F.noticeResponse(config)],
            "submit-consent": [.text(201, "{}")],
        ])
    }

    @MainActor
    private func make(
        token: String? = "tok",
        applicationId: String? = nil,
        counter: FlowCounter = FlowCounter(),
        validity: ValidityLog = ValidityLog()
    ) -> ConsentInlineViewModel {
        ConsentInlineViewModel(
            orgUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            accessToken: token,
            baseUrl: "https://api.example.test/consent",
            onAccept: { counter.accepts += 1 },
            onError: { _ in counter.errors += 1 },
            onValidationChange: { validity.values.append($0) },
            applicationId: applicationId
        )
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

    private var reads: [TransportStubRequest] {
        RouteStub.requests(matching: "/notices/")
    }

    @MainActor
    func testReportsValidityAsSoonAsANoticeWithNothingRequiredLoads() async {
        install(optionalOnly)
        let validity = ValidityLog()
        let viewModel = make(token: nil, validity: validity)

        await viewModel.fetchNotice().value

        XCTAssertEqual(validity.values, [true])
    }

    @MainActor
    func testReportsInvalidOnLoadWhenARequiredElementIsUnticked() async {
        install(requiredOnly)
        let validity = ValidityLog()
        let viewModel = make(token: nil, validity: validity)

        await viewModel.fetchNotice().value

        XCTAssertEqual(validity.values, [false])
    }

    @MainActor
    func testReportsEachChangeOfValidityOnce() async {
        install(requiredOnly)
        let validity = ValidityLog()
        let viewModel = make(token: nil, validity: validity)
        await viewModel.fetchNotice().value

        viewModel.handleDataElementToggle("el-email", purposeUuid: "pur-1")
        viewModel.handlePurposeCollapse("pur-1")
        viewModel.checkValidationAndAutoSubmit()

        XCTAssertEqual(validity.values, [false, true])
    }

    @MainActor
    func testAutoSubmitsOnLoadWhenNothingIsRequired() async {
        install(optionalOnly)
        let counter = FlowCounter()
        let viewModel = make(counter: counter)

        await viewModel.fetchNotice().value
        await settle(viewModel)

        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(counter.accepts, 1)
    }

    @MainActor
    func testSeedsTheNoticesMandatoryPreselection() async {
        var config = requiredOnly
        config.purposePreselection = PurposePreselection.mandatory.rawValue
        install(config)
        let validity = ValidityLog()
        let viewModel = make(token: nil, validity: validity)

        await viewModel.fetchNotice().value

        XCTAssertEqual(viewModel.selectedDataElements["pur-1-el-email"], true)
        XCTAssertEqual(viewModel.selectedPurposes["pur-1"], true)
        XCTAssertEqual(validity.values, [true])
    }

    @MainActor
    func testLeavesEverythingUntickedWithoutAPreselection() async {
        install(requiredOnly)
        let viewModel = make(token: nil)

        await viewModel.fetchNotice().value

        XCTAssertEqual(viewModel.selectedDataElements["pur-1-el-email"], false)
    }

    @MainActor
    func testReappearingDoesNotReadAgainOrDropTheReadersTicks() async {
        install(requiredOnly)
        let viewModel = make(token: nil)
        await viewModel.fetchNotice().value
        viewModel.handleDataElementToggle("el-email", purposeUuid: "pur-1")
        let before = reads.count

        viewModel.fetchNoticeIfNeeded()
        await Task.yield()

        XCTAssertEqual(viewModel.selectedDataElements["pur-1-el-email"], true)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(reads.count, before)
    }

    @MainActor
    func testANewApplicationDropsThePreviousOnesAcceptance() async {
        install(requiredOnly, notices: [
            .text(409, #"{"detail":"CONSENT_ALREADY_PROVIDED"}"#),
            F.noticeResponse(requiredOnly),
        ])
        let validity = ValidityLog()
        let viewModel = make(token: nil, applicationId: "app-1", validity: validity)
        await viewModel.fetchNotice().value
        XCTAssertTrue(viewModel.hasAlreadyConsented)

        var next = viewModel.identity
        next = InlineNoticeIdentity(
            orgUuid: next.orgUuid,
            workspaceUuid: next.workspaceUuid,
            noticeUuid: next.noticeUuid,
            language: next.language,
            applicationId: "app-2"
        )
        await viewModel.updateIdentity(next)?.value

        XCTAssertFalse(viewModel.hasAlreadyConsented)
        XCTAssertNotNil(viewModel.activeConfig)
        XCTAssertEqual(validity.values.last, false)
        XCTAssertTrue(reads.last?.url.absoluteString.contains("specific_uuid=app-2") ?? false)
    }

    // MARK: - A submit still in flight when the principal or consent changes

    private let oldConsent = F.config(products: nil, purposes: [F.purpose("pur-old", nil, [F.element("el-email")])], uuid: "cfg-old")
    private let newConsent = F.config(products: nil, purposes: [F.purpose("pur-new", nil, [F.element("el-email")])], uuid: "cfg-new")

    /// Holds the first submit on the transport thread until `release` signals.
    private func installHoldingFirstSubmit(notices: [TransportStubResponse], release: DispatchSemaphore) {
        let routes = RouteStub([
            "/notices/": notices,
            "submit-consent": [.text(201, "{}")],
        ])
        let held = NSLock()
        var isFirst = true
        TransportStubProtocol.install { request in
            if request.url.absoluteString.contains("submit-consent") {
                held.lock()
                let hold = isFirst
                isFirst = false
                held.unlock()
                if hold { _ = release.wait(timeout: .now() + 5) }
            }
            return routes.respond(to: request)
        }
    }

    private func application(_ request: TransportStubRequest) -> String? {
        (request.json["meta_data"] as? [String: Any])?["specific_uuid"] as? String
    }

    private func purposeUuids(_ request: TransportStubRequest) -> [String] {
        ((request.json["purposes"] as? [[String: Any]]) ?? []).compactMap { $0["purpose_uuid"] as? String }
    }

    @MainActor
    private func identity(_ viewModel: ConsentInlineViewModel, applicationId: String) -> InlineNoticeIdentity {
        let current = viewModel.identity
        return InlineNoticeIdentity(
            orgUuid: current.orgUuid,
            workspaceUuid: current.workspaceUuid,
            noticeUuid: current.noticeUuid,
            language: current.language,
            applicationId: applicationId
        )
    }

    @MainActor
    func testASubmitOutlivingItsApplicationNeitherAcceptsNorBlocksTheNextOne() async {
        let release = DispatchSemaphore(value: 0)
        installHoldingFirstSubmit(notices: [F.noticeResponse(oldConsent), F.noticeResponse(newConsent)], release: release)
        let counter = FlowCounter()
        let viewModel = make(applicationId: "app-1", counter: counter)
        await viewModel.fetchNotice().value
        await waitUntil { submits.count == 1 }

        await viewModel.updateIdentity(identity(viewModel, applicationId: "app-2"))?.value
        XCTAssertEqual(submits.count, 1)
        release.signal()
        await settle(viewModel)

        XCTAssertEqual(counter.accepts, 1)
        XCTAssertEqual(submits.map(application), ["app-1", "app-2"])
        XCTAssertEqual(submits.map(purposeUuids), [["pur-old"], ["pur-new"]])
    }

    @MainActor
    func testAFailedReReadLeavesNoEarlierConsentToSubmit() async {
        let release = DispatchSemaphore(value: 0)
        installHoldingFirstSubmit(notices: [F.noticeResponse(oldConsent), .text(500, "{}")], release: release)
        let counter = FlowCounter()
        let viewModel = make(applicationId: "app-1", counter: counter)
        await viewModel.fetchNotice().value
        await waitUntil { submits.count == 1 }

        await viewModel.updateIdentity(identity(viewModel, applicationId: "app-2"))?.value
        release.signal()
        await settle(viewModel)

        XCTAssertEqual(counter.accepts, 0)
        XCTAssertEqual(submits.count, 1)
        XCTAssertNil(viewModel.activeConfig)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    @MainActor
    func testASubmitOutlivingItsTokenDoesNotAcceptForTheNextPrincipal() async {
        let release = DispatchSemaphore(value: 0)
        installHoldingFirstSubmit(notices: [F.noticeResponse(oldConsent)], release: release)
        let counter = FlowCounter()
        let viewModel = make(token: "tok-1", counter: counter)
        await viewModel.fetchNotice().value
        await waitUntil { submits.count == 1 }

        await viewModel.updateAccessToken("tok-2")?.value
        release.signal()
        await settle(viewModel)

        XCTAssertEqual(counter.accepts, 1)
        XCTAssertEqual(submits.count, 2)
        XCTAssertTrue(submits.last?.header("Authorization")?.contains("tok-2") ?? false)
    }

    @MainActor
    func testAnUnchangedIdentityDoesNotReadAgain() async {
        install(requiredOnly)
        let viewModel = make(token: nil)
        await viewModel.fetchNotice().value

        XCTAssertNil(viewModel.updateIdentity(viewModel.identity))
    }
}

final class ValidityLog {
    var values: [Bool] = []
}
