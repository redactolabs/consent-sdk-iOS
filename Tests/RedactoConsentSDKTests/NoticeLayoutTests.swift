import SwiftUI
import XCTest
@testable import RedactoConsentSDK

final class NoticeLayoutTests: XCTestCase {
    func testPassesEachPositionThrough() {
        XCTAssertEqual(NoticeLayout.resolveLogoPosition("left"), .left)
        XCTAssertEqual(NoticeLayout.resolveLogoPosition("center"), .center)
        XCTAssertEqual(NoticeLayout.resolveLogoPosition("right"), .right)
    }

    func testFallsBackToLeftForAnythingUnrecognised() {
        for raw in [nil, "", "LEFT", "middle", " right "] as [String?] {
            XCTAssertEqual(NoticeLayout.resolveLogoPosition(raw), .left, String(describing: raw))
        }
    }

    func testMapsEachPositionOntoARowAlignment() {
        XCTAssertEqual(NoticeLayout.alignment(for: .left), .leading)
        XCTAssertEqual(NoticeLayout.alignment(for: .center), .center)
        XCTAssertEqual(NoticeLayout.alignment(for: .right), .trailing)
    }

    @MainActor
    func testTheNoticeReadsItsLogoPosition() {
        XCTAssertEqual(makeNotice(content: NoticeFixtures.content(config: ["logo_position": "center"])).vm.logoPosition, .center)
        XCTAssertEqual(makeNotice().vm.logoPosition, .left)
    }

    func testTheHostFontWinsOverTheNoticeFont() {
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: "Avenir Next", noticeFont: "Georgia"), ["Avenir Next"])
    }

    func testAHostStackIsTriedInOrderWithoutGenericKeywords() {
        XCTAssertEqual(
            NoticeFontResolver.candidates(hostFont: "\"Inter\", Helvetica, sans-serif", noticeFont: nil),
            ["Inter", "Helvetica"]
        )
    }

    func testTheNoticeFontResolvesThroughTheCatalogueCaseInsensitively() {
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: nil, noticeFont: "GEORGIA"), ["Georgia", "Times New Roman", "Times"])
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: "  ", noticeFont: "Verdana"), ["Verdana", "Geneva"])
    }

    func testANoticeFontTheCatalogueNoLongerOffersResolvesToTheDefaultFamily() {
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: nil, noticeFont: "Comic Sans"), ["Arial", "Helvetica"])
    }

    func testNothingStoredKeepsTheSystemFont() {
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: nil, noticeFont: nil), [])
        XCTAssertEqual(NoticeFontResolver.candidates(hostFont: "", noticeFont: "  "), [])
        XCTAssertNil(NoticeFontResolver.resolve(hostFont: nil, noticeFont: nil) { $0 })
    }

    func testResolvesTheFirstInstalledCandidate() {
        let installed: Set<String> = ["Trebuchet MS", "Arial"]
        let resolved = NoticeFontResolver.resolve(hostFont: nil, noticeFont: "montserrat") { installed.contains($0) ? $0 : nil }
        XCTAssertEqual(resolved, "Trebuchet MS")
    }

    func testFallsBackToTheSystemFontWhenNothingIsInstalled() {
        XCTAssertNil(NoticeFontResolver.resolve(hostFont: "Nope", noticeFont: "Georgia") { _ in nil })
    }

    func testAnInstalledSystemFamilyIsFoundOnDevice() {
        XCTAssertEqual(NoticeFontResolver.installedFamily("georgia"), "Georgia")
        XCTAssertNil(NoticeFontResolver.installedFamily("Definitely Not A Font"))
    }
}
