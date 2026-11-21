import XCTest
@testable import RedactoConsentSDK

final class PCTopBarLogoSlotTests: XCTestCase {
    func testACentredLogoThatClearsTheActionsSitsOnTheBarsCentre() {
        let slot = PCTopBarLogoSlot.resolve(barWidth: 400, actionsWidth: 100, logoWidth: 120, spacing: 8)

        XCTAssertTrue(slot.centered)
        XCTAssertEqual(slot.x, 140)
        XCTAssertEqual(slot.width, 120)
        XCTAssertLessThanOrEqual(slot.x + slot.width, 400 - 100 - 8)
    }

    func testALogoThatWouldReachTheActionsMovesToTheLeadingEdge() {
        let slot = PCTopBarLogoSlot.resolve(barWidth: 296, actionsWidth: 120, logoWidth: 160, spacing: 8)

        XCTAssertFalse(slot.centered)
        XCTAssertEqual(slot.x, 0)
        XCTAssertEqual(slot.width, 160)
        XCTAssertLessThanOrEqual(slot.x + slot.width, 296 - 120 - 8)
    }

    func testALeadingLogoNeverRunsUnderTheActions() {
        let slot = PCTopBarLogoSlot.resolve(barWidth: 296, actionsWidth: 200, logoWidth: 160, spacing: 8)

        XCTAssertFalse(slot.centered)
        XCTAssertEqual(slot.width, 88)
    }

    func testNoRoomLeavesTheLogoNoWidthRatherThanANegativeOne() {
        let slot = PCTopBarLogoSlot.resolve(barWidth: 100, actionsWidth: 120, logoWidth: 32, spacing: 8)

        XCTAssertFalse(slot.centered)
        XCTAssertEqual(slot.width, 0)
    }
}
