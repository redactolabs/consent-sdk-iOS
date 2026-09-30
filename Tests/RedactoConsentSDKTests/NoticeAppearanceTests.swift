import SwiftUI
import XCTest
@testable import RedactoConsentSDK

final class NoticeAppearanceTests: XCTestCase {
    private typealias R = NoticeAppearanceResolver

    // MARK: - Shared vectors (docs/appearance-fixtures.json)

    private static let fixtures = AppearanceFixtures.object

    private func cases(_ key: String) throws -> [[String: Any]] {
        let cases = try XCTUnwrap(Self.fixtures[key] as? [[String: Any]], "missing \(key) in AppearanceFixtures")
        XCTAssertFalse(cases.isEmpty)
        return cases
    }

    /// Serves `input` on a notice and reads it back through the real decoder.
    private func served(_ input: Any?) throws -> NoticeAppearance? {
        var json = TransportFixtures.noticeJSON()
        var detail = try XCTUnwrap(json["detail"] as? [String: Any])
        var config = try XCTUnwrap(detail["active_config"] as? [String: Any])
        config["appearance"] = input ?? NSNull()
        detail["active_config"] = config
        json["detail"] = detail
        let data = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
        return try JSONDecoder().decode(ConsentContent.self, from: data).detail.activeConfig.appearance
    }

    private func colorMap(_ colors: NoticeAppearanceColors) -> [String: String] {
        Dictionary(uniqueKeysWithValues: colors.map { ($0.key.rawValue, $0.value) })
    }

    private func number(_ value: Any?) -> CGFloat? {
        (value as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    func testResolverMatchesTheSharedVectors() throws {
        for vector in try cases("cases") {
            let name = vector["name"] as? String ?? "?"
            let expected = try XCTUnwrap(vector["expected"] as? [String: Any])
            let resolved = R.resolve(try served(vector["input"]))
            XCTAssertEqual(resolved.style.rawValue, expected["style"] as? String, name)
            XCTAssertEqual(colorMap(resolved.colors), expected["colors"] as? [String: String], name)
            XCTAssertEqual(resolved.radius, number(expected["radius"]), name)
            XCTAssertEqual(resolved.selectionControl?.rawValue, expected["selection_control"] as? String, name)
            XCTAssertEqual(resolved.controlStyle?.rawValue, expected["control_style"] as? String, name)
            XCTAssertEqual(resolved.confirmBeforeSubmit, expected["confirm_before_submit"] as? Bool, name)
        }
    }

    // custom_css is web-only: native notices have no CSS, so it is not compared.
    func testLayoutMatchesTheSharedVectors() throws {
        for vector in try cases("layout_cases") {
            let name = vector["name"] as? String ?? "?"
            let expected = try XCTUnwrap(vector["expected"] as? [String: Any])
            let resolved = R.resolve(try served(vector["input"]))
            let layout = resolved.layout
            XCTAssertEqual(layout.mobileSheet, expected["mobile_sheet"] as? Bool, name)
            XCTAssertEqual(layout.desktopPosition.rawValue, expected["desktop_position"] as? String, name)
            XCTAssertEqual(layout.dimBackdrop, expected["dim_backdrop"] as? Bool, name)
            XCTAssertEqual(layout.collapsibleSections, expected["collapsible_sections"] as? Bool, name)
            XCTAssertEqual(layout.pairedFooter, expected["paired_footer"] as? Bool, name)
            XCTAssertEqual(layout.switchControl, expected["switch_control"] as? Bool, name)
            XCTAssertEqual(layout.motion, expected["motion"] as? Bool, name)
            XCTAssertEqual(resolved.maxWidth, number(expected["max_width"]), name)
            XCTAssertEqual(resolved.logoSize, number(expected["logo_size"]), name)
            XCTAssertEqual(resolved.textScale?.rawValue, expected["text_scale"] as? String, name)
        }
    }

    func testDarkModeMatchesTheSharedVectors() throws {
        for vector in try cases("dark_cases") {
            let name = vector["name"] as? String ?? "?"
            let scheme: ColorScheme = (vector["prefers_dark"] as? Bool) == true ? .dark : .light
            let resolved = NoticeAppearance.resolve(console: try served(vector["input"]), settings: nil, colorScheme: scheme)
            XCTAssertEqual(colorMap(resolved.colors), vector["expected_colors"] as? [String: String], name)
        }
    }

    func testAMalformedFieldDropsOnlyThatField() throws {
        let appearance = try XCTUnwrap(try served([
            "style": "glass",
            "border_radius": "12",
            "colors": ["background": 12, "text": "#111111"],
            "motion": 1,
        ] as [String: Any]))
        let resolved = R.resolve(appearance)
        XCTAssertEqual(resolved.style, .glass)
        XCTAssertNil(resolved.radius)
        XCTAssertEqual(colorMap(resolved.colors), ["text": "#111111"])
        XCTAssertNil(resolved.motion)
    }

    func testRadiusRoundsHalfUpLikeJavaScript() {
        XCTAssertEqual(R.resolve(NoticeAppearance(borderRadius: 12.5)).radius, 13)
        XCTAssertEqual(R.resolve(NoticeAppearance(borderRadius: 12.4)).radius, 12)
    }

    // MARK: - Host settings over the console (mergeHostSettings.test.ts)

    private let console = NoticeAppearanceResolver.resolve(NoticeAppearance(
        style: "glass",
        colors: [
            "background": "#0b1220",
            "heading": "#f8fafc",
            "accept_all_bg": "#16a34a",
            "tts_highlight_bg": "#fde68a",
        ],
        borderRadius: 20,
        selectionControl: "radio",
        confirmBeforeSubmit: true
    ))

    func testKeepsTheConsoleAppearanceWhenTheHostSetsNothing() {
        XCTAssertEqual(R.merge(console, settings: nil), console)
        XCTAssertEqual(R.merge(console, settings: ConsentSettings()), console)
    }

    func testEveryKeyTheHostSetsWinsAndOnlyThoseKeys() {
        let merged = R.merge(console, settings: ConsentSettings(
            borderRadius: "6px",
            backgroundColor: "#ffffff",
            selectionControl: .dropdown,
            confirmBeforeSubmit: false,
            theme: .soft,
            ttsHighlight: TTSHighlightSettings(textColor: "#111827")
        ))
        XCTAssertEqual(merged.style, .soft)
        XCTAssertEqual(colorMap(merged.colors), [
            "background": "#ffffff",
            "heading": "#f8fafc",
            "accept_all_bg": "#16a34a",
            "tts_highlight_bg": "#fde68a",
            "tts_highlight_text": "#111827",
        ])
        XCTAssertEqual(merged.radius, 6)
        XCTAssertEqual(merged.selectionControl, .dropdown)
        XCTAssertFalse(merged.confirmBeforeSubmit)
    }

    func testTheConsoleSelectionControlAndConfirmStepApplyUntilTheHostSetsThem() {
        let merged = R.merge(console, settings: ConsentSettings(backgroundColor: "#ffffff"))
        XCTAssertEqual(merged.selectionControl, .radio)
        XCTAssertTrue(merged.confirmBeforeSubmit)

        var settings = ConsentSettings()
        XCTAssertEqual(settings.selectionControl, .checkbox)
        XCTAssertFalse(settings.confirmBeforeSubmit)
        settings.selectionControl = .checkbox
        settings.confirmBeforeSubmit = false
        let overridden = R.merge(console, settings: settings)
        XCTAssertEqual(overridden.selectionControl, .checkbox)
        XCTAssertFalse(overridden.confirmBeforeSubmit)
    }

    func testButtonAcceptStaysTheBrandAccentAndAcceptAllsFallback() {
        let merged = R.merge(console, settings: ConsentSettings(
            button: ButtonSettings(accept: ButtonStyle(backgroundColor: "#7c3aed", textColor: "#fff"))
        ))
        XCTAssertEqual(merged.colors[.acceptAllBg], "#7c3aed")
        XCTAssertEqual(merged.colors[.acceptAllText], "#fff")
        XCTAssertEqual(merged.colors[.toggleOn], "#7c3aed")
    }

    func testAnEmptyAcceptAllColourIsUnset() {
        let merged = R.merge(console, settings: ConsentSettings(
            button: ButtonSettings(
                accept: ButtonStyle(backgroundColor: "#7c3aed", textColor: "#fff"),
                acceptAll: ButtonStyle(backgroundColor: "", textColor: "")
            )
        ))
        XCTAssertEqual(merged.colors[.acceptAllBg], "#7c3aed")
        XCTAssertEqual(merged.colors[.acceptAllText], "#fff")
    }

    func testMapsEveryConsoleOptionAHostCanSet() {
        let merged = R.merge(R.resolve(NoticeAppearance()), settings: ConsentSettings(
            button: ButtonSettings(
                decline: ButtonStyle(backgroundColor: "", textColor: "", borderColor: "#555555"),
                language: LanguageButtonStyle(backgroundColor: "", textColor: "", selectedBackgroundColor: "#666666"),
                acceptSelected: ButtonStyle(backgroundColor: "#333333", textColor: "#444444")
            ),
            surfaceColor: "#111111",
            mutedTextColor: "#222222",
            overlayColor: "#00000080",
            toggle: ToggleSettings(offColor: "#777777", knobColor: "#888888")
        ))
        XCTAssertEqual(colorMap(merged.colors), [
            "surface": "#111111",
            "muted_text": "#222222",
            "overlay": "#00000080",
            "accept_bg": "#333333",
            "accept_text": "#444444",
            "decline_border": "#555555",
            "language_selected_bg": "#666666",
            "toggle_off": "#777777",
            "toggle_knob": "#888888",
        ])
    }

    func testTheHostsLayoutKeysWinOverTheConsoles() {
        let console = R.resolve(NoticeAppearance(
            mobileLayout: "sheet",
            desktopPosition: "bottom-right",
            backdrop: "dim",
            collapsibleSections: true,
            phoneFooter: "paired",
            maxWidth: 600,
            logoSize: 40,
            textScale: "sm",
            motion: true
        ))
        let merged = R.merge(console, settings: ConsentSettings(
            controlStyle: .switch,
            mobileLayout: .modal,
            desktopPosition: .bottomBar,
            backdrop: NoticeBackdrop.none,
            collapsibleSections: false,
            phoneFooter: .stacked,
            maxWidth: "480",
            logoSize: "24px",
            textScale: .lg,
            motion: false
        ))
        XCTAssertEqual(merged.mobileLayout, .modal)
        XCTAssertEqual(merged.desktopPosition, .bottomBar)
        XCTAssertEqual(merged.backdrop, NoticeBackdrop.none)
        XCTAssertEqual(merged.collapsibleSections, false)
        XCTAssertEqual(merged.phoneFooter, .stacked)
        XCTAssertEqual(merged.controlStyle, .switch)
        XCTAssertEqual(merged.maxWidth, 480)
        XCTAssertEqual(merged.logoSize, 24)
        XCTAssertEqual(merged.textScale, .lg)
        XCTAssertEqual(merged.motion, false)
        XCTAssertTrue(merged.layout.switchControl)
        XCTAssertFalse(merged.layout.dimBackdrop)
    }

    func testAHostLengthWithNoNativeMeaningKeepsTheConsoles() {
        let console = R.resolve(NoticeAppearance(desktopPosition: "bottom-left", maxWidth: 500))
        let merged = R.merge(console, settings: ConsentSettings(backdrop: NoticeBackdrop.none, maxWidth: "42rem"))
        XCTAssertEqual(merged.desktopPosition, .bottomLeft)
        XCTAssertEqual(merged.maxWidth, 500)
        XCTAssertEqual(merged.backdrop, NoticeBackdrop.none)
    }

    func testTheHostsDarkPaletteMergesOverTheConsoles() {
        let console = R.resolve(NoticeAppearance(
            autoDark: false,
            darkColors: ["background": "#0b1220", "text": "#e5e7eb"]
        ))
        let merged = R.merge(console, settings: ConsentSettings(
            autoDark: true,
            darkPalette: ConsentSettingsPalette(textColor: "#ffffff")
        ))
        XCTAssertTrue(merged.autoDark)
        XCTAssertEqual(colorMap(merged.darkColors), ["background": "#0b1220", "text": "#ffffff"])
    }

    func testTheDarkPaletteReplacesHostLightColoursWhole() {
        let resolved = NoticeAppearance.resolve(
            console: NoticeAppearance(autoDark: true, darkColors: ["background": "#0b1220"]),
            settings: ConsentSettings(backgroundColor: "#ffffff", headingColor: "#111111"),
            colorScheme: .dark
        )
        XCTAssertEqual(colorMap(resolved.colors), ["background": "#0b1220"])
    }

    // MARK: - Derived values

    func testLayoutDefaultsFollowTheStyle() {
        XCTAssertEqual(AppearanceStyle.classic.layout, AppearanceStyle.minimal.layout)
        XCTAssertEqual(AppearanceStyle.classic.layout, AppearanceStyle.soft.layout)
        let glass = AppearanceStyle.glass.layout
        XCTAssertTrue(glass.sheet && glass.collapsibleSections && glass.pairedFooter && glass.loaderPill && glass.sheetOverlays)
        XCTAssertFalse(glass.switchControl)
        let classic = AppearanceStyle.classic.layout
        XCTAssertFalse(classic.sheet || classic.collapsibleSections || classic.pairedFooter || classic.loaderPill)
    }

    func testDockingFollowsTheLayout() {
        let sheet = ResolvedNoticeAppearance(style: .glass).layout
        XCTAssertTrue(sheet.isDocked(isPhone: true))
        XCTAssertFalse(sheet.isDocked(isPhone: false))
        let bar = ResolvedNoticeAppearance(desktopPosition: .bottomBar).layout
        XCTAssertTrue(bar.isDocked(isPhone: false))
        XCTAssertFalse(bar.isDocked(isPhone: true))
    }

    func testRadiiTextScaleAndLogoSize() {
        let soft = ResolvedNoticeAppearance(style: .soft)
        XCTAssertEqual(soft.modalRadius, 24)
        XCTAssertEqual(soft.buttonRadius, noticePillRadius)
        let set = ResolvedNoticeAppearance(style: .soft, radius: 6)
        XCTAssertEqual(set.modalRadius, 6)
        XCTAssertEqual(set.buttonRadius, 6)

        XCTAssertEqual(ResolvedNoticeAppearance().textScaleFactor, 1)
        XCTAssertEqual(ResolvedNoticeAppearance(textScale: .sm).scaled(14), 12.9)
        XCTAssertEqual(ResolvedNoticeAppearance(textScale: .lg).scaled(14), 15.4)

        XCTAssertEqual(ResolvedNoticeAppearance().logoHeight(isPhone: true), 28)
        XCTAssertEqual(ResolvedNoticeAppearance().logoHeight(isPhone: false), 32)
        XCTAssertEqual(ResolvedNoticeAppearance(logoSize: 40).logoMaxWidth(isPhone: true), 175)
    }

    func testAccentChain() {
        XCTAssertEqual(ResolvedNoticeAppearance().accentColor(primaryColor: nil), "#4f87ff")
        XCTAssertEqual(ResolvedNoticeAppearance().accentColor(primaryColor: ""), "#4f87ff")
        XCTAssertEqual(ResolvedNoticeAppearance().accentColor(primaryColor: "#123456"), "#123456")
        XCTAssertEqual(ResolvedNoticeAppearance(colors: [.acceptAllBg: "#16a34a"]).accentColor(primaryColor: "#123456"), "#16a34a")
        XCTAssertEqual(
            ResolvedNoticeAppearance(colors: [.acceptAllBg: "#16a34a", .toggleOn: "#7c3aed"]).accentColor(primaryColor: "#123456"),
            "#7c3aed"
        )
        XCTAssertEqual(ResolvedNoticeAppearance().ttsHighlightBackground, "#FFF9C4")
    }

    // MARK: - Colour helpers (appearance.test.ts)

    func testParsesCSSColours() {
        let vectors: [(String, AppearanceRGBA)] = [
            ("#fff", AppearanceRGBA(r: 255, g: 255, b: 255)),
            ("#000042", AppearanceRGBA(r: 0, g: 0, b: 66)),
            ("#00004280", AppearanceRGBA(r: 0, g: 0, b: 66, a: 128.0 / 255)),
            ("rgb(10, 20, 30)", AppearanceRGBA(r: 10, g: 20, b: 30)),
            ("rgba(10, 20, 30, 0.5)", AppearanceRGBA(r: 10, g: 20, b: 30, a: 0.5)),
            ("rgb(10 20 30 / 50%)", AppearanceRGBA(r: 10, g: 20, b: 30, a: 0.5)),
            ("rgb(100%, 0%, 50%)", AppearanceRGBA(r: 255, g: 0, b: 128)),
        ]
        for (input, expected) in vectors {
            XCTAssertEqual(AppearanceColor.parse(input), expected, input)
        }
        for input in ["red", "var(--pc-primary)", "hsl(0 0% 0%)", "", "#12", "rgb(., ., .)", "rgb(1.2.3, 0, 0)"] {
            XCTAssertNil(AppearanceColor.parse(input), input)
        }
        // Served colours are checked as sent, so a trailing newline is not hex.
        XCTAssertTrue(AppearanceColor.isServedHex("#FDE68A"))
        XCTAssertFalse(AppearanceColor.isServedHex("#fff\n"))
        XCTAssertFalse(AppearanceColor.isServedHex("#ffff"))
    }

    func testPaintableFallsBackForWhatCannotBePainted() {
        XCTAssertEqual(AppearanceColor.paintable("#e11d48", fallback: "#4f87ff"), "#e11d48")
        XCTAssertEqual(AppearanceColor.paintable("rgb(10 20 30)", fallback: "#4f87ff"), "rgb(10 20 30)")
        for input in [nil, "", "   ", "4f87ff", "ffffff", "#12345", "red;"] as [String?] {
            XCTAssertEqual(AppearanceColor.paintable(input, fallback: "#4f87ff"), "#4f87ff", input ?? "nil")
        }
    }

    func testAlphaMixAndCompositing() throws {
        XCTAssertEqual(AppearanceColor.withAlpha("#000042", 0.08), AppearanceRGBA(r: 0, g: 0, b: 66, a: 0.08))
        XCTAssertEqual(AppearanceColor.withAlpha("rgba(0, 0, 0, 0.5)", 0.5), AppearanceRGBA(r: 0, g: 0, b: 0, a: 0.25))
        XCTAssertEqual(AppearanceColor.mix("#000000", "#ffffff", 0.5), AppearanceRGBA(r: 128, g: 128, b: 128))
        let white = try XCTUnwrap(AppearanceColor.parse("#ffffff"))
        XCTAssertEqual(
            AppearanceColor.opaqueOver(try XCTUnwrap(AppearanceColor.parse("rgba(0, 0, 0, 0.5)")), white),
            AppearanceRGBA(r: 128, g: 128, b: 128)
        )
        XCTAssertEqual(
            AppearanceColor.opaqueOver(try XCTUnwrap(AppearanceColor.parse("#e11d48")), white),
            AppearanceRGBA(r: 225, g: 29, b: 72)
        )
    }

    func testGlassPaletteDerivesFromTheAccentAndTint() throws {
        let accent = try XCTUnwrap(AppearanceColor.parse("#e11d48"))
        let palette = GlassPalette(accent: accent)
        XCTAssertEqual(palette.accent, accent)
        XCTAssertEqual(palette.accentWash, AppearanceRGBA(r: 225, g: 29, b: 72, a: 0.08))
        let tinted = GlassPalette(accent: accent, tint: try XCTUnwrap(AppearanceColor.parse("#fef3c7")))
        XCTAssertEqual(tinted.sheet, AppearanceRGBA(r: 254, g: 243, b: 199, a: 0.52))
    }
}
