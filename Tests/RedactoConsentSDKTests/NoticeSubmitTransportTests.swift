import XCTest
@testable import RedactoConsentSDK

final class NoticeSubmitTransportTests: XCTestCase {
    private typealias F = TransportFixtures

    private final class Outcomes: @unchecked Sendable {
        private let lock = NSLock()
        private var queue: [TransportStubResponse]

        init(_ queue: [TransportStubResponse]) {
            self.queue = queue
        }

        func next() -> TransportStubResponse {
            lock.lock()
            defer { lock.unlock() }
            return queue.isEmpty ? .empty(201) : queue.removeFirst()
        }
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

    private func respond(_ outcomes: [TransportStubResponse]) {
        let queue = Outcomes(outcomes)
        TransportStubProtocol.install { _ in queue.next() }
    }

    private func submit(selected: Bool = true, ledgerBaseUrl: String? = F.ledger) async throws {
        try await ConsentAPI.submitConsentEvent(.init(
            accessToken: F.token(),
            baseUrl: F.python,
            ledgerBaseUrl: ledgerBaseUrl,
            noticeUuid: F.notice,
            purposes: [F.purpose(selected: selected)],
            declined: false
        ))
    }

    private func submitError(selected: Bool = true) async -> RedactoAPIError? {
        do {
            try await submit(selected: selected)
            return nil
        } catch {
            return error as? RedactoAPIError
        }
    }

    private var keysSent: [String?] {
        TransportStubProtocol.requests(pathSuffix: "/submit-consent").map { $0.header(IdempotencyKeys.header) }
    }

    func testRetriesA5xxSubmissionUnderTheSameKey() async throws {
        respond([.json(502, ["message": "x"]), .empty(201)])
        let failure = await submitError()
        XCTAssertEqual(failure?.statusCode, 502)
        try await submit()
        XCTAssertEqual(keysSent.count, 2)
        XCTAssertNotNil(keysSent[0])
        XCTAssertEqual(keysSent[1], keysSent[0])
    }

    func testRetriesADroppedConnectionUnderTheSameKey() async throws {
        respond([.offline, .empty(201)])
        _ = await submitError()
        try await submit()
        XCTAssertEqual(keysSent.count, 2)
        XCTAssertEqual(keysSent[1], keysSent[0])
    }

    func testReleasesTheKeyAfterA4xx() async throws {
        respond([.json(422, ["detail": ["message": "bad"]]), .empty(201)])
        let failure = await submitError()
        XCTAssertEqual(failure?.statusCode, 422)
        try await submit()
        XCTAssertNotEqual(keysSent[1], keysSent[0])
        XCTAssertEqual(IdempotencyKeys.shared.pendingCount, 0)
    }

    func testRecordsALaterIdenticalSubmissionAsANewRequest() async throws {
        respond([.empty(201), .empty(201)])
        try await submit()
        try await submit()
        XCTAssertNotEqual(keysSent[1], keysSent[0])
    }

    func testMintsANewKeyWhenTheSelectionChanges() async throws {
        respond([.json(503, [:] as [String: Any]), .empty(201)])
        _ = await submitError(selected: true)
        try await submit(selected: false)
        XCTAssertNotEqual(keysSent[1], keysSent[0])
    }

    func testTheConsentServerSubmitIsKeyedToo() async throws {
        respond([.json(500, ["message": "x"]), .empty(201)])
        do {
            try await submit(ledgerBaseUrl: nil)
        } catch {}
        try await submit(ledgerBaseUrl: nil)
        XCTAssertEqual(TransportStubProtocol.requests.first?.url.host, "api.example.test")
        XCTAssertNotNil(keysSent[0])
        XCTAssertEqual(keysSent[1], keysSent[0])
    }

    func testSurfacesTheServerMessageAndCodeOnAFailedSubmission() async {
        respond([.json(422, ["detail": ["message": "Purpose p-9 is not on this notice.", "error_code": "INVALID_PURPOSE"]])])
        let failure = await submitError()
        XCTAssertEqual(failure?.errorDescription, "Purpose p-9 is not on this notice.")
        XCTAssertEqual(failure?.errorCode, "INVALID_PURPOSE")
        XCTAssertEqual(failure?.statusCode, 422)
    }

    func testSurfacesTheServerMessageOnA500() async {
        respond([.json(500, ["message": "Consent could not be recorded."])])
        let failure = await submitError()
        XCTAssertEqual(failure?.errorDescription, "Consent could not be recorded.")
    }

    func testANonJSONFailureShowsTheSubmitFallbackAndNeverTheRawText() async {
        respond([.text(502, "<html><h1>502 Bad Gateway</h1>upstream nginx exploded</html>")])
        let failure = await submitError()
        XCTAssertEqual(failure?.errorDescription, APIErrorFallback.submitConsent)
        XCTAssertFalse(failure?.errorDescription?.contains("nginx") ?? true)
        XCTAssertEqual(failure?.statusCode, 502)
    }

    func testKeepsThe409TheAlreadyConsentedReadIsRecognisedBy() async {
        respond([.json(409, ["detail": ["message": "Consent already provided.", "error_code": "CONSENT_ALREADY_PROVIDED"]])])
        do {
            _ = try await ConsentAPI.fetchConsentContent(.init(noticeId: F.notice, accessToken: F.token(), baseUrl: F.python))
            XCTFail("expected a 409")
        } catch let error as RedactoAPIError {
            XCTAssertEqual(error.statusCode, 409)
            XCTAssertEqual(error.errorCode, "CONSENT_ALREADY_PROVIDED")
            XCTAssertEqual(error.errorDescription, "Consent already provided.")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testANonJSONReadFailureShowsTheReadFallback() async {
        respond([.text(503, "Service Unavailable")])
        do {
            _ = try await ConsentAPI.fetchConsentContent(.init(noticeId: F.notice, accessToken: F.token(), baseUrl: F.python))
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, APIErrorFallback.noticeRead)
        }
    }
}

@MainActor
final class NoticeViewModelErrorPassThroughTests: XCTestCase {
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

    private func install(read: TransportStubResponse, submit: TransportStubResponse) {
        TransportStubProtocol.install { request in
            if request.path.hasSuffix("/submit-consent") {
                return submit
            }
            if request.path.contains("/audio/") {
                return .json(404, ["message": "no audio"])
            }
            return read
        }
    }

    private func loadedModal(submit: TransportStubResponse) async -> ConsentNoticeViewModel {
        install(read: .json(200, F.noticeJSON()), submit: submit)
        let vm = ConsentNoticeViewModel(
            noticeId: F.notice,
            accessToken: F.token(),
            refreshToken: "",
            baseUrl: F.python,
            ledgerBaseUrl: F.ledger,
            onAccept: {},
            onDecline: {}
        )
        vm.fetchContent()
        await waitUntil { vm.content != nil && !vm.isLoading }
        return vm
    }

    func testModalSubmitShowsTheServerMessageOnA500() async {
        let vm = await loadedModal(submit: .json(500, ["message": "Consent could not be recorded."]))
        vm.handleAccept()
        await waitUntil { vm.errorMessage != nil }
        XCTAssertEqual(vm.errorMessage, "Consent could not be recorded.")
        XCTAssertEqual(TransportStubProtocol.requests(pathSuffix: "/submit-consent").first?.url.host, "ledger.example.test")
    }

    func testModalSubmitShowsTheFallbackForANonJSONFailure() async {
        let vm = await loadedModal(submit: .text(502, "<html>bad gateway from proxy-7</html>"))
        vm.handleAccept()
        await waitUntil { vm.errorMessage != nil }
        XCTAssertEqual(vm.errorMessage, APIErrorFallback.submitConsent)
    }

    func testModalReadShowsTheServerMessageOnA401() async {
        install(read: .json(401, ["detail": ["message": "This link has expired.", "error_code": "INVALID_TOKEN"]]), submit: .empty(201))
        let vm = ConsentNoticeViewModel(
            noticeId: F.notice,
            accessToken: F.token(),
            refreshToken: "",
            baseUrl: F.python,
            onAccept: {},
            onDecline: {}
        )
        vm.fetchContent()
        await waitUntil { vm.fetchErrorMessage != nil }
        XCTAssertEqual(vm.fetchErrorMessage, "This link has expired.")
        XCTAssertNil(vm.content)
        XCTAssertFalse(vm.isLoading)
    }

    func testInlineSubmitShowsTheServerMessageOnA500() async {
        install(read: .json(200, F.noticeJSON()), submit: .json(500, ["message": "Consent could not be recorded."]))
        let errors = Counter()
        let vm = ConsentInlineViewModel(
            orgUuid: F.org,
            workspaceUuid: F.workspace,
            noticeUuid: F.notice,
            accessToken: F.token(),
            baseUrl: F.python,
            onError: { _ in errors.value += 1 }
        )
        vm.fetchNotice()
        await waitUntil { vm.activeConfig != nil && !vm.isLoading }
        vm.handlePurposeToggle("p-1")
        await waitUntil { vm.errorMessage != nil }
        XCTAssertEqual(vm.errorMessage, "Consent could not be recorded.")
        XCTAssertEqual(errors.value, 1)
    }
}
