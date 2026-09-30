import SwiftUI
import XCTest
@testable import RedactoConsentSDK

/// The inline notice against React's `RedactoNoticeConsentInline`: translation
/// fallbacks, its wire payload and the console appearance.
final class InlineParityTests: XCTestCase {
    private typealias F = InlineFixtures

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    static func translation(_ json: String) -> LanguageTranslation {
        try! JSONDecoder().decode(LanguageTranslation.self, from: Data(json.utf8))
    }

    private let hindi = InlineParityTests.translation(#"""
    {
      "purposes": {"pur-1": {"name": "विपणन", "description": ""}, "pur-2": {"name": "", "description": "विवरण"}},
      "data_elements": {"el-email": "", "el-phone": "फ़ोन"},
      "products": {"prod-a": {"name": "उत्पाद ए", "description": ""}},
      "notice_text": "सूचना"
    }
    """#)

    @MainActor
    private func viewModel(
        _ config: ActiveConfig,
        language: String,
        baseUrl: String? = "https://api.example.test/consent",
        token: String? = nil,
        settings: ConsentSettings? = nil
    ) -> ConsentInlineViewModel {
        let viewModel = ConsentInlineViewModel(
            orgUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            accessToken: token,
            baseUrl: baseUrl ?? "https://api.example.test/consent",
            settings: settings
        )
        viewModel.applyConfig(config)
        viewModel.selectedLanguage = language
        return viewModel
    }

    private var translated: ActiveConfig {
        var config = F.config(
            products: nil,
            purposes: [
                F.purpose("pur-1", nil, [F.element("el-email"), F.element("el-phone")]),
                F.purpose("pur-2", nil, []),
            ],
            translations: ["Hindi": hindi, "English": hindi]
        )
        config.products = [NoticeProduct(uuid: "prod-a", name: "Product A")]
        return config
    }

    @MainActor
    func testEnglishReadsTheBaseCopyEvenWhenATranslationIsKeyedEnglish() {
        let viewModel = viewModel(translated, language: "English")

        XCTAssertEqual(viewModel.getTranslatedText("purposes.name", defaultText: "Marketing", itemId: "pur-1"), "Marketing")
        XCTAssertEqual(viewModel.getTranslatedText("notice_text", defaultText: "Notice"), "Notice")
        XCTAssertEqual(viewModel.getTranslatedText("privacy_policy_anchor_text", defaultText: "Privacy Policy"), "Policy")
    }

    @MainActor
    func testAnEmptyTranslationFallsBackToTheBaseCopy() {
        let viewModel = viewModel(translated, language: "Hindi")

        XCTAssertEqual(viewModel.getTranslatedText("purposes.name", defaultText: "Marketing", itemId: "pur-1"), "विपणन")
        XCTAssertEqual(viewModel.getTranslatedText("purposes.description", defaultText: "Base", itemId: "pur-1"), "Base")
        XCTAssertEqual(viewModel.getTranslatedText("purposes.name", defaultText: "Second", itemId: "pur-2"), "Second")
        XCTAssertEqual(viewModel.getTranslatedText("data_elements.name", defaultText: "Email", itemId: "el-email"), "Email")
        XCTAssertEqual(viewModel.getTranslatedText("data_elements.name", defaultText: "Phone", itemId: "el-phone"), "फ़ोन")
        XCTAssertEqual(viewModel.getTranslatedText("products.name", defaultText: "Product A", itemId: "prod-a"), "उत्पाद ए")
        XCTAssertEqual(viewModel.getTranslatedText("notice_text", defaultText: "Notice"), "सूचना")
    }

    @MainActor
    func testSubmitsWithoutALanguage() async {
        RouteStub.install([
            "/notices/": [F.noticeResponse(F.config(products: nil, purposes: [F.purpose("pur-1", nil, [F.element("el-email")])]))],
            "submit-consent": [.text(201, "{}")],
        ])
        let viewModel = ConsentInlineViewModel(orgUuid: "org-1", workspaceUuid: "ws-1", noticeUuid: "ntc-1", accessToken: "tok", baseUrl: "https://api.example.test/consent")
        await viewModel.fetchNotice().value
        while let task = viewModel.submitTask {
            await task.value
        }

        let submit = RouteStub.requests(matching: "submit-consent").first
        XCTAssertNotNil(submit)
        XCTAssertNil(submit?.json["language"], "React's inline submit sends no language")
    }

    @MainActor
    func testPaintsTheConsoleAppearanceUnderTheHostSettings() {
        var config = F.config(products: nil, purposes: [F.purpose("pur-1", nil, [])])
        config.appearance = NoticeAppearance(
            colors: ["toggle_off": "#111111", "muted_text": "#222222", "heading": "#333333"],
            borderRadius: 20,
            selectionControl: "radio",
            controlStyle: "switch",
            textScale: "lg"
        )
        let appearance = viewModel(config, language: "en").appearance(colorScheme: .light)
        let style = InlineAppearance.rowStyle(appearance, isMobile: false)

        XCTAssertEqual(style.selectionControl, .radio)
        XCTAssertTrue(style.switchControl)
        XCTAssertEqual(style.titleSize, 17.6)
        XCTAssertEqual(style.elementSize, 15.4)
        XCTAssertEqual(appearance.modalRadius, 20)
        XCTAssertEqual(InlineAppearance.rowStyle(appearance, isMobile: true).titleSize, 15.4)

        let hosted = viewModel(config, language: "en", settings: ConsentSettings(selectionControl: .dropdown))
            .appearance(colorScheme: .light)
        XCTAssertEqual(InlineAppearance.rowStyle(hosted, isMobile: false).selectionControl, .dropdown)
    }

    @MainActor
    func testTheAccentIsTheToggleColourNeverThePrimaryColour() {
        var config = F.config(products: nil, purposes: [])
        XCTAssertEqual(InlineAppearance.accent(viewModel(config, language: "en").appearance(colorScheme: .light)), "#4f87ff")
        config.appearance = NoticeAppearance(colors: ["accept_all_bg": "#aa0000"])
        XCTAssertEqual(InlineAppearance.accent(viewModel(config, language: "en").appearance(colorScheme: .light)), "#aa0000")
        config.appearance = NoticeAppearance(colors: ["accept_all_bg": "#aa0000", "toggle_on": "#00aa00"])
        XCTAssertEqual(InlineAppearance.accent(viewModel(config, language: "en").appearance(colorScheme: .light)), "#00aa00")
    }
}
