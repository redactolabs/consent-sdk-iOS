import Foundation

/// Thread-safe, TTL-based API cache using actor isolation.
actor APICache {
    static let shared = APICache()

    private var cache: [String: CacheEntry] = [:]
    private let defaultTTL: TimeInterval = 5 * 60 // 5 minutes

    private struct CacheEntry {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
    }

    func get(_ key: String) -> Data? {
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) < entry.ttl {
            return entry.data
        }
        cache.removeValue(forKey: key)
        return nil
    }

    func set(_ key: String, data: Data, ttl: TimeInterval? = nil) {
        cache[key] = CacheEntry(
            data: data,
            timestamp: Date(),
            ttl: ttl ?? defaultTTL
        )
    }

    func clear() {
        cache.removeAll()
    }
}
