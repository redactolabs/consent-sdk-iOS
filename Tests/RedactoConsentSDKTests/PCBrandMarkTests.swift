import XCTest
@testable import RedactoConsentSDK

final class PCBrandMarkTests: XCTestCase {
    private let logo = "https://cdn.example.test/logo.png"
    private let icon = "https://cdn.example.test/icon.png"

    func testTheWorkspaceLogoWinsOverItsIcon() {
        XCTAssertEqual(PCBrandMark.resolve(logoUrl: logo, iconUrl: icon), .logo(URL(string: logo)!))
    }

    func testTheIconDrawsWhenThereIsNoLogo() {
        XCTAssertEqual(PCBrandMark.resolve(logoUrl: nil, iconUrl: icon), .icon(URL(string: icon)!))
    }

    func testInitialsDrawWithNeitherImage() {
        XCTAssertEqual(PCBrandMark.resolve(logoUrl: nil, iconUrl: nil), .initials)
    }

    func testTheFittedImageStaysInsideTheCircle() {
        for size in [CGFloat(32), 48, 72] {
            let side = PCLogoAvatar.imageSide(for: size)
            XCTAssertGreaterThan(side, 0)
            XCTAssertLessThanOrEqual((side * side * 2).squareRoot(), size)
        }
    }
}
