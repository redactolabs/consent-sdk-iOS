import XCTest
@testable import RedactoConsentSDK

final class APICacheTests: XCTestCase {
    func testSetAndGet() async {
        let cache = APICache.shared
        await cache.clear()

        let testData = "test data".data(using: .utf8)!
        await cache.set("key1", data: testData)

        let retrieved = await cache.get("key1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, testData)
    }

    func testCacheMiss() async {
        let cache = APICache.shared
        await cache.clear()

        let retrieved = await cache.get("nonexistent")
        XCTAssertNil(retrieved)
    }

    func testClear() async {
        let cache = APICache.shared
        await cache.clear()

        let testData = "test data".data(using: .utf8)!
        await cache.set("key1", data: testData)
        await cache.clear()

        let retrieved = await cache.get("key1")
        XCTAssertNil(retrieved)
    }

    func testExpiredEntry() async {
        let cache = APICache.shared
        await cache.clear()

        let testData = "test data".data(using: .utf8)!
        // Set with 0 TTL (immediately expired)
        await cache.set("key1", data: testData, ttl: 0)

        // Wait a tiny bit to ensure expiration
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let retrieved = await cache.get("key1")
        XCTAssertNil(retrieved)
    }
}
