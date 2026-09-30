import Foundation

final class IdempotencyKeys: @unchecked Sendable {
    static let header = "Idempotency-Key"
    static let maxPending = 16
    static let shared = IdempotencyKeys()

    private let lock = NSLock()
    private var pending: [String: PendingIdempotencyKey] = [:]
    private var order: [String] = []

    func withKey(
        url: String,
        body: Data,
        send: ([String: String]) async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        let signature = "\(url)\n\(String(decoding: body, as: UTF8.self))"
        let entry = acquire(signature)
        do {
            let result = try await send([Self.header: entry.key])
            settle(entry, signature: signature, settled: Self.settledOnResolve(result.1))
            return result
        } catch {
            settle(entry, signature: signature, settled: Self.settledOnReject(error))
            throw error
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        pending.removeAll()
        order.removeAll()
    }

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pending.count
    }

    private func acquire(_ signature: String) -> PendingIdempotencyKey {
        lock.lock()
        defer { lock.unlock() }
        let entry: PendingIdempotencyKey
        if let existing = pending[signature] {
            if existing.inFlight == 0 {
                existing.keep = false
            }
            entry = existing
        } else {
            if pending.count >= Self.maxPending, let oldest = order.first {
                remove(oldest)
            }
            entry = PendingIdempotencyKey(key: UUID().uuidString.lowercased())
            pending[signature] = entry
            order.append(signature)
        }
        entry.inFlight += 1
        return entry
    }

    private func settle(_ entry: PendingIdempotencyKey, signature: String, settled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        entry.inFlight -= 1
        if !settled {
            entry.keep = true
        }
        if entry.inFlight == 0, !entry.keep, pending[signature] === entry {
            remove(signature)
        }
    }

    private func remove(_ signature: String) {
        pending.removeValue(forKey: signature)
        order.removeAll { $0 == signature }
    }

    private static func settledOnResolve(_ response: URLResponse) -> Bool {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return true }
        return status < 500
    }

    private static func settledOnReject(_ error: Error) -> Bool {
        guard let status = (error as? RedactoAPIError)?.statusCode ?? (error as? PrivacyCenterAPIError)?.httpStatus else { return false }
        return status < 500
    }
}
