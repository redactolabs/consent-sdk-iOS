import XCTest
@testable import RedactoConsentSDK

final class IdempotencyKeysTests: XCTestCase {
    private let url = "https://ledger.example/submit-consent"
    private let body = Data(#"{"notice_uuid":"n-1","purposes":[]}"#.utf8)
    private let otherBody = Data(#"{"notice_uuid":"n-1","purposes":[{"selected":true}]}"#.utf8)

    private final class KeyLog: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: [String] = []

        func record(_ headers: [String: String]) {
            lock.lock()
            keys.append(headers[IdempotencyKeys.header] ?? "")
            lock.unlock()
        }

        var seen: [String] {
            lock.lock()
            defer { lock.unlock() }
            return keys
        }
    }

    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var opened = false
        private var waiter: CheckedContinuation<Void, Never>?

        func wait() async {
            await withCheckedContinuation { continuation in
                lock.lock()
                if opened {
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiter = continuation
                    lock.unlock()
                }
            }
        }

        func open() {
            lock.lock()
            opened = true
            let waiter = self.waiter
            self.waiter = nil
            lock.unlock()
            waiter?.resume()
        }
    }

    private func response(_ status: Int) -> (Data, URLResponse) {
        (Data(), HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    private func attempt(
        _ keys: IdempotencyKeys,
        _ log: KeyLog,
        status: Int,
        url: String? = nil,
        body: Data? = nil
    ) async throws {
        _ = try await keys.withKey(url: url ?? self.url, body: body ?? self.body) { headers in
            log.record(headers)
            return self.response(status)
        }
    }

    private func failingAttempt(_ keys: IdempotencyKeys, _ log: KeyLog, error: Error) async {
        do {
            _ = try await keys.withKey(url: url, body: body) { headers in
                log.record(headers)
                throw error
            }
            XCTFail("expected the attempt to throw")
        } catch {}
    }

    func testSendsAKeyInTheIdempotencyHeader() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 201)
        XCTAssertEqual(IdempotencyKeys.header, "Idempotency-Key")
        XCTAssertFalse(log.seen[0].isEmpty)
    }

    func testReusesTheKeyAfterADroppedConnection() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        await failingAttempt(keys, log, error: URLError(.networkConnectionLost))
        try await attempt(keys, log, status: 201)
        XCTAssertEqual(log.seen[1], log.seen[0])
    }

    func testKeepsReusingTheKeyAcrossRepeatedFailures() async {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        for _ in 0..<3 {
            await failingAttempt(keys, log, error: URLError(.timedOut))
        }
        XCTAssertEqual(Set(log.seen).count, 1)
    }

    func testKeepsTheKeyWhenTheServerAnswers5xx() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 500)
        try await attempt(keys, log, status: 201)
        XCTAssertEqual(log.seen[1], log.seen[0])
    }

    func testReleasesTheKeyWhenTheServerAnswers4xx() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 422)
        try await attempt(keys, log, status: 201)
        XCTAssertNotEqual(log.seen[1], log.seen[0])
    }

    func testReleasesTheKeyWhenTheSenderThrowsA4xx() async {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        let refusal = RedactoAPIError.api(status: 422, code: "INVALID_PURPOSE", message: "no")
        await failingAttempt(keys, log, error: refusal)
        await failingAttempt(keys, log, error: refusal)
        XCTAssertNotEqual(log.seen[1], log.seen[0])
    }

    func testKeepsTheKeyWhenTheSenderThrowsA5xx() async {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        let outage = RedactoAPIError.api(status: 503, code: nil, message: "busy")
        await failingAttempt(keys, log, error: outage)
        await failingAttempt(keys, log, error: outage)
        XCTAssertEqual(log.seen[1], log.seen[0])
    }

    func testMintsANewKeyOnceTheRequestSucceeded() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 201)
        try await attempt(keys, log, status: 201)
        XCTAssertNotEqual(log.seen[1], log.seen[0])
        XCTAssertEqual(keys.pendingCount, 0)
    }

    func testMintsANewKeyWhenTheBodyChanges() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 500)
        try await attempt(keys, log, status: 201, body: otherBody)
        XCTAssertNotEqual(log.seen[1], log.seen[0])
    }

    func testMintsANewKeyForADifferentEndpoint() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 500)
        try await attempt(keys, log, status: 201, url: "https://ledger.example/other")
        XCTAssertNotEqual(log.seen[1], log.seen[0])
    }

    func testKeepsEachRequestsKeyWhenBodiesInterleave() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 500)
        try await attempt(keys, log, status: 201, body: otherBody)
        try await attempt(keys, log, status: 201)
        XCTAssertEqual(log.seen[2], log.seen[0])
        XCTAssertNotEqual(log.seen[1], log.seen[0])
    }

    func testReleasesTheKeyOnceARetrySettlesDefinitively() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 500)
        try await attempt(keys, log, status: 201)
        try await attempt(keys, log, status: 201)
        XCTAssertEqual(log.seen[1], log.seen[0])
        XCTAssertNotEqual(log.seen[2], log.seen[1])
    }

    func testHoldsTheKeyWhenTheFailureSettlesLast() async throws {
        try await assertConcurrentAttemptsHoldTheKey(firstStatus: 500, secondStatus: 201)
    }

    func testHoldsTheKeyWhenTheFailureSettlesFirst() async throws {
        try await assertConcurrentAttemptsHoldTheKey(firstStatus: 201, secondStatus: 500)
    }

    private func assertConcurrentAttemptsHoldTheKey(firstStatus: Int, secondStatus: Int) async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        let firstGate = Gate()
        let secondGate = Gate()
        let url = self.url
        let body = self.body

        let first = Task {
            _ = try await keys.withKey(url: url, body: body) { headers in
                log.record(headers)
                await firstGate.wait()
                return self.response(firstStatus)
            }
        }
        await waitForKeys(log, count: 1)
        let second = Task {
            _ = try await keys.withKey(url: url, body: body) { headers in
                log.record(headers)
                await secondGate.wait()
                return self.response(secondStatus)
            }
        }
        await waitForKeys(log, count: 2)
        XCTAssertEqual(log.seen[1], log.seen[0])

        secondGate.open()
        try await second.value
        firstGate.open()
        try await first.value

        try await attempt(keys, log, status: 201)
        XCTAssertEqual(log.seen[2], log.seen[0])
    }

    private func waitForKeys(_ log: KeyLog, count: Int) async {
        let deadline = Date().addingTimeInterval(2)
        while log.seen.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testCapsPendingKeysAndEvictsTheOldest() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        for index in 0...IdempotencyKeys.maxPending {
            try await attempt(keys, log, status: 500, body: Data("body-\(index)".utf8))
        }
        XCTAssertEqual(keys.pendingCount, IdempotencyKeys.maxPending)

        try await attempt(keys, log, status: 500, body: Data("body-0".utf8))
        XCTAssertNotEqual(log.seen.last, log.seen[0])

        try await attempt(keys, log, status: 500, body: Data("body-\(IdempotencyKeys.maxPending)".utf8))
        XCTAssertEqual(log.seen.last, log.seen[IdempotencyKeys.maxPending])
    }

    func testMintsKeysTheLedgerAccepts() async throws {
        let keys = IdempotencyKeys()
        let log = KeyLog()
        try await attempt(keys, log, status: 201)
        try await attempt(keys, log, status: 201)
        let minted = log.seen[0]
        XCTAssertNotNil(UUID(uuidString: minted))
        XCTAssertTrue((1...255).contains(minted.count))
        XCTAssertTrue(minted.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value <= 0x7e })
        XCTAssertNotEqual(log.seen[1], minted)
    }
}
