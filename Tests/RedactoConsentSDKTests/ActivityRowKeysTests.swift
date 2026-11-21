import XCTest
@testable import RedactoConsentSDK

final class ActivityRowKeysTests: XCTestCase {
    private typealias F = PCFixtures

    private func activity(_ id: String?, timestamp: String = "2026-01-01T10:00:00Z") -> Activity {
        Activity(backendId: id, activityType: "consent_given", timestamp: timestamp, title: "Consent given")
    }

    func testARowWithAnIdIsKeyedByItWhereverItSits() {
        let a = activity("a-1")
        let b = activity("b-1")

        XCTAssertEqual(ActivityListViewModel.rowKeys([a, b]), ["id:a-1", "id:b-1"])
        XCTAssertEqual(ActivityListViewModel.rowKeys([b, a])[1], "id:a-1")
    }

    func testRowsWithoutAnIdSharingATimestampGetDistinctKeys() {
        let keys = ActivityListViewModel.rowKeys([activity(nil), activity(nil), activity("")])

        XCTAssertEqual(Set(keys).count, 3)
        XCTAssertFalse(keys.contains { $0.hasPrefix("id:") })
    }

    func testARepeatedIdNeverYieldsARepeatedKey() {
        let keys = ActivityListViewModel.rowKeys([activity("dup"), activity("dup"), activity("dup")])

        XCTAssertEqual(Set(keys).count, 3)
        XCTAssertEqual(keys[0], "id:dup")
    }

    @MainActor
    func testTheTimelineDrawsEveryRowOfADayUnderItsOwnKey() {
        let store = PrivacyCenterStore(
            baseUrl: F.base,
            slug: "acme",
            accessToken: F.liveToken,
            refreshToken: "refresh-1",
            themeMode: .light,
            initialPage: .activity,
            onBack: nil,
            onError: { _ in false },
            language: "en",
            urlSession: F.session()
        )
        let vm = ActivityListViewModel(store: store)
        vm.activities = [activity("dup"), activity("dup"), activity(nil), activity(nil)]

        let rows = vm.dayGroups.flatMap(\.rows)

        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(Set(rows.map(\.id)).count, 4)
        XCTAssertEqual(vm.dayGroups.first?.items.count, 4)
    }
}
