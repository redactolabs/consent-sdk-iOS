import XCTest
@testable import RedactoConsentSDK

/// The console's confirmation copy, against React's `confirmDialogCopyOverride`.
final class ConfirmDialogCopyOverrideTests: XCTestCase {
    private static func translation(_ json: String) -> LanguageTranslation {
        try! JSONDecoder().decode(LanguageTranslation.self, from: Data(json.utf8))
    }

    private func config(
        acceptAllTitle: String? = nil,
        acceptAllDetail: String? = nil,
        acceptSelectedTitle: String? = nil,
        declineTitle: String? = nil,
        translations: [String: LanguageTranslation] = [:]
    ) -> ActiveConfig {
        var config = InlineFixtures.config(
            products: nil, purposes: [InlineFixtures.wide], translations: translations
        )
        config.confirmAcceptAllTitle = acceptAllTitle
        config.confirmAcceptAllDetail = acceptAllDetail
        config.confirmAcceptSelectedTitle = acceptSelectedTitle
        config.confirmDeclineTitle = declineTitle
        return config
    }

    // The claim that matters most: a notice that never set this copy resolves
    // to nothing, and nothing is what leaves the dialog on its own wording.
    func testResolvesToNothingWithoutANotice() {
        let override = ConfirmDialogCopyOverride.resolve(nil, language: "en", action: .acceptAll)

        XCTAssertNil(override.title)
        XCTAssertNil(override.detail)
    }

    func testResolvesToNothingForANoticeThatCarriesNoCopy() {
        let override = ConfirmDialogCopyOverride.resolve(
            config(), language: "en", action: .acceptAll
        )

        XCTAssertNil(override.title)
        XCTAssertNil(override.detail)
    }

    /// The server serves "" rather than null for copy the admin left blank.
    func testResolvesToNothingWhenTheFieldsAreServedEmpty() {
        let override = ConfirmDialogCopyOverride.resolve(
            config(acceptAllTitle: "", acceptAllDetail: ""),
            language: "en",
            action: .acceptAll
        )

        XCTAssertNil(override.title)
        XCTAssertNil(override.detail)
    }

    func testTakesTheNoticesBaseCopyWhenOnlyThatIsSet() {
        let override = ConfirmDialogCopyOverride.resolve(
            config(
                acceptAllTitle: "Agree to all of it?",
                acceptAllDetail: "Every purpose is recorded as agreed."
            ),
            language: "en",
            action: .acceptAll
        )

        XCTAssertEqual(override.title, "Agree to all of it?")
        XCTAssertEqual(override.detail, "Every purpose is recorded as agreed.")
    }

    func testLetsTheLanguagesTranslationBeatTheBaseCopy() {
        let hindi = Self.translation(#"""
        {"confirm_accept_all_title": "सब कुछ स्वीकार करें?", "confirm_accept_all_detail": ""}
        """#)
        let override = ConfirmDialogCopyOverride.resolve(
            config(
                acceptAllTitle: "Agree to all of it?",
                acceptAllDetail: "Every purpose is recorded as agreed.",
                translations: ["Hindi": hindi]
            ),
            language: "Hindi",
            action: .acceptAll
        )

        XCTAssertEqual(override.title, "सब कुछ स्वीकार करें?")
        XCTAssertEqual(override.detail, "Every purpose is recorded as agreed.")
    }

    func testReadsEachActionFromItsOwnKeys() {
        let served = config(
            acceptAllTitle: "all", acceptSelectedTitle: "selected", declineTitle: "decline"
        )

        XCTAssertEqual(
            ConfirmDialogCopyOverride.resolve(served, language: "en", action: .acceptAll).title,
            "all"
        )
        XCTAssertEqual(
            ConfirmDialogCopyOverride.resolve(served, language: "en", action: .acceptSelected).title,
            "selected"
        )
        XCTAssertEqual(
            ConfirmDialogCopyOverride.resolve(served, language: "en", action: .decline).title,
            "decline"
        )
    }

    /// The dialog's own wording when nothing is served, the console's when it is.
    func testTheDialogPrefersTheOverrideAndFallsBackToTheChromeCopy() {
        let hindi = NoticeChromeCopy.forLanguage("Hindi")
        let none = ConfirmDialogCopyOverride.none
        let set = ConfirmDialogCopyOverride(title: "अपने चयन भेजें?", detail: "")

        XCTAssertEqual(
            none.title ?? hindi.confirmTitle(.acceptSelected), hindi.confirmAcceptSelectedTitle
        )
        XCTAssertEqual(
            none.detail ?? hindi.confirmDetail(.acceptSelected), hindi.confirmAcceptSelectedDetail
        )
        XCTAssertEqual(set.title ?? hindi.confirmTitle(.acceptSelected), "अपने चयन भेजें?")
        XCTAssertEqual(
            set.detail ?? hindi.confirmDetail(.acceptSelected), hindi.confirmAcceptSelectedDetail
        )
    }
}
