import XCTest
@testable import RedactoConsentSDK

@MainActor
final class InlineLedgerConsentTests: XCTestCase {
    private typealias F = TransportFixtures

    private final class Counter {
        var value = 0
    }

    override func setUp() async throws {
        try await super.setUp()
        await APICache.shared.clear()
        IdempotencyKeys.shared.reset()
    }

    override func tearDown() async throws {
        TransportStubProtocol.uninstall()
        IdempotencyKeys.shared.reset()
        await APICache.shared.clear()
        try await super.tearDown()
    }

    private func install(check: TransportStubResponse, checkDelay: TimeInterval = 0) {
        TransportStubProtocol.install { request in
            if request.path.hasSuffix("/submit-consent") {
                return .empty(201)
            }
            if request.path.hasSuffix("/check-consent") {
                if checkDelay > 0 {
                    Thread.sleep(forTimeInterval: checkDelay)
                }
                return check
            }
            return .json(200, F.noticeJSON())
        }
    }

    private func makeInline(
        ledgerBaseUrl: String? = F.ledger,
        applicationId: String? = nil,
        accepted: Counter
    ) -> ConsentInlineViewModel {
        ConsentInlineViewModel(
            orgUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice,
            accessToken: F.token(),
            baseUrl: F.python,
            ledgerBaseUrl: ledgerBaseUrl,
            onAccept: { accepted.value += 1 },
            applicationId: applicationId
        )
    }

    private func loaded(_ vm: ConsentInlineViewModel) async {
        vm.fetchNotice()
        await waitUntil { vm.activeConfig != nil && !vm.isLoading && !vm.isCheckingConsent }
    }

    private var submits: [TransportStubRequest] {
        TransportStubProtocol.requests(pathSuffix: "/submit-consent")
    }

    private var checks: [TransportStubRequest] {
        TransportStubProtocol.requests(pathSuffix: "/check-consent")
    }

    func testAFullyConsentedPrincipalIsNotResubmitted() async {
        install(check: .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: true)))
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        await loaded(vm)

        XCTAssertTrue(vm.hasAlreadyConsented)
        XCTAssertEqual(accepted.value, 1)
        vm.handlePurposeToggle("p-1")
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(submits.isEmpty)
        XCTAssertEqual(checks.first?.url.absoluteString, "\(F.scope(F.ledger))/notices/\(F.notice)/check-consent")
        XCTAssertEqual(checks.first?.header("Authorization"), "Bearer \(F.token())")
    }

    func testAPrincipalWithoutARecordStillSubmitsToTheLedger() async {
        install(check: .json(200, F.consentStatusJSON(consented: false, allMandatoryActive: false)))
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        await loaded(vm)

        XCTAssertFalse(vm.hasAlreadyConsented)
        vm.handlePurposeToggle("p-1")
        await waitUntil { accepted.value == 1 }
        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(submits.first?.url.host, "ledger.example.test")
        XCTAssertNotNil(submits.first?.header(IdempotencyKeys.header))
    }

    func testAConsentedButMandatoryInactiveRecordStillSubmits() async {
        install(check: .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: false)))
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        await loaded(vm)

        vm.handlePurposeToggle("p-1")
        await waitUntil { accepted.value == 1 }
        XCTAssertEqual(submits.count, 1)
    }

    func testAFailedCheckDegradesToSubmitting() async {
        install(check: .json(500, ["message": "down"]))
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        await loaded(vm)

        XCTAssertFalse(vm.hasAlreadyConsented)
        vm.handlePurposeToggle("p-1")
        await waitUntil { accepted.value == 1 }
        XCTAssertEqual(submits.count, 1)
    }

    func testASelectionMadeDuringTheCheckWaitsForItThenSubmitsOnce() async {
        install(check: .json(200, F.consentStatusJSON(consented: false, allMandatoryActive: false)), checkDelay: 0.5)
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        vm.fetchNotice()
        await waitUntil { vm.activeConfig != nil }

        XCTAssertTrue(vm.isCheckingConsent)
        vm.handlePurposeToggle("p-1")
        XCTAssertTrue(submits.isEmpty)

        await waitUntil { accepted.value == 1 }
        XCTAssertEqual(submits.count, 1)
    }

    func testASelectionMadeDuringTheCheckIsDroppedWhenAlreadyConsented() async {
        install(check: .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: true)), checkDelay: 0.5)
        let accepted = Counter()
        let vm = makeInline(accepted: accepted)
        vm.fetchNotice()
        await waitUntil { vm.activeConfig != nil }

        vm.handlePurposeToggle("p-1")
        await waitUntil { !vm.isCheckingConsent }
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(submits.isEmpty)
        XCTAssertEqual(accepted.value, 1)
    }

    func testNoLedgerMeansNoCheckAndTheConsentServerSubmit() async {
        install(check: .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: true)))
        let accepted = Counter()
        let vm = makeInline(ledgerBaseUrl: nil, accepted: accepted)
        XCTAssertFalse(vm.isCheckingConsent)
        await loaded(vm)

        vm.handlePurposeToggle("p-1")
        await waitUntil { accepted.value == 1 }
        XCTAssertTrue(checks.isEmpty)
        XCTAssertEqual(submits.first?.url.host, "api.example.test")
    }

    func testMagicLinkSkipsTheCheckButStillWritesToTheLedger() async {
        install(check: .json(200, F.consentStatusJSON(consented: true, allMandatoryActive: true)))
        let accepted = Counter()
        let vm = makeInline(applicationId: "app-1", accepted: accepted)
        XCTAssertFalse(vm.isCheckingConsent)
        await loaded(vm)

        vm.handlePurposeToggle("p-1")
        await waitUntil { accepted.value == 1 }
        XCTAssertTrue(checks.isEmpty)
        XCTAssertEqual(submits.first?.url.host, "ledger.example.test")
        let read = TransportStubProtocol.requests.first { $0.path.hasSuffix("/notices/\(F.notice)") }
        XCTAssertEqual(read?.url.host, "api.example.test")
    }

    func testRunsTheCheckOnlyWithALedgerAndNoApplication() {
        XCTAssertTrue(ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: F.ledger, applicationId: nil))
        XCTAssertTrue(ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: F.ledger, applicationId: ""))
        XCTAssertFalse(ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: F.ledger, applicationId: "app-1"))
        XCTAssertFalse(ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: " ", applicationId: nil))
        XCTAssertFalse(ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: nil, applicationId: nil))
    }

    // The authenticated inline read goes to the ledger when one is configured,
    // as the modal's does; a magic link and a tokenless read stay on the
    // consent server, which alone serves `specific_uuid` and `get-notice`.

    @MainActor
    func testTheInlineReadGoesToTheLedgerWhenOneIsConfigured() async {
        install(check: .json(200, F.consentStatusJSON(consented: false, allMandatoryActive: false)))
        let vm = makeInline(accepted: Counter())

        await loaded(vm)

        let read = TransportStubProtocol.requests.first { $0.path.hasSuffix("/notices/\(F.notice)") }
        XCTAssertEqual(read?.url.host, "ledger.example.test")
        XCTAssertNil(read?.query("specific_uuid"))
    }

    @MainActor
    func testTheInlineReadStaysOnTheConsentServerWithoutALedger() async {
        install(check: .json(200, F.consentStatusJSON(consented: false, allMandatoryActive: false)))
        let vm = makeInline(ledgerBaseUrl: nil, accepted: Counter())

        await loaded(vm)

        let read = TransportStubProtocol.requests.first { $0.path.hasSuffix("/notices/\(F.notice)") }
        XCTAssertEqual(read?.url.host, "api.example.test")
    }

    func testATokenlessInlineReadStaysOnTheConsentServer() async throws {
        TransportStubProtocol.install { _ in .json(200, F.noticeJSON()) }
        defer { TransportStubProtocol.uninstall() }

        _ = try await ConsentAPI.fetchInlineConsentContent(.init(
            orgUuid: F.org, workspaceUuid: F.workspace, noticeUuid: F.notice,
            baseUrl: F.python, ledgerBaseUrl: F.ledger
        ))

        let read = try XCTUnwrap(TransportStubProtocol.requests.first)
        XCTAssertEqual(read.url.host, "api.example.test")
        XCTAssertTrue(read.path.hasSuffix("/notices/get-notice/\(F.notice)"))
    }
}
