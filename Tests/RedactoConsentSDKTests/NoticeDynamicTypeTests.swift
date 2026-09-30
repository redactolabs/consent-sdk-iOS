import XCTest
@testable import RedactoConsentSDK

/// The notice follows the user's text size, and at the default size it is
/// exactly the web SDK's.
final class NoticeDynamicTypeTests: XCTestCase {
    func testTheDefaultSizeLeavesTheWebSizesAlone() {
        XCTAssertEqual(NoticeDynamicType.factor(.large), 1, accuracy: 0.001)
    }

    func testALargerSettingGrowsTheText() {
        XCTAssertGreaterThan(NoticeDynamicType.factor(.xxxLarge), 1.2)
        XCTAssertLessThan(NoticeDynamicType.factor(.small), 1)
    }

    func testAccessibilitySizesAreCapped() {
        XCTAssertEqual(NoticeDynamicType.factor(.accessibility5), NoticeDynamicType.maxFactor, accuracy: 0.001)
        XCTAssertLessThanOrEqual(NoticeDynamicType.factor(.accessibility2), NoticeDynamicType.maxFactor)
    }
}
