import SwiftUI

/// Constants of the appearance contract (`docs/sdk-appearance-spec.md`).
public enum NoticeAppearanceDefaults {
    public static let style: AppearanceStyle = .classic
    public static let selectionControl: SelectionControlType = .checkbox
    public static let desktopPosition: NoticeDesktopPosition = .center
    public static let textScale: NoticeTextScale = .md
    /// Brand accent when neither the host nor the notice sets one.
    public static let accentColor = "#4f87ff"
    /// The talkback highlight every platform draws when the admin sets none.
    public static let ttsHighlightBackground = "#FFF9C4"

    /// Mirror the server's clamps, so a hand-edited value still draws sensibly.
    static let radiusRange: ClosedRange<Double> = 0...28
    static let widthRange: ClosedRange<Double> = 320...960
    static let logoSizeRange: ClosedRange<Double> = 16...96

    /// Logo height when the console sets none.
    public static let logoHeight: CGFloat = 32
    public static let phoneLogoHeight: CGFloat = 28
    /// Logo width cap as a multiple of its height: classic's 140 over 32.
    public static let logoWidthRatio: CGFloat = 4.375
}

/// Layout choices a style switches on. For the notice these are only the
/// style's defaults, which the console and the host override one by one (see
/// `ResolvedNoticeLayout`). Components branch on these, never on the style name.
public struct AppearanceLayout: Equatable {
    /// Notice docks to the bottom edge on phones and floats as a card above it.
    public let sheet: Bool
    /// Notice text and the DPO block collapse into disclosures.
    public let collapsibleSections: Bool
    /// Purpose and product checkboxes render as switches.
    public let switchControl: Bool
    /// Phone footer: Accept All full width, the other two side by side.
    public let pairedFooter: Bool
    /// Loading shows a compact pill instead of an empty dialog.
    public let loaderPill: Bool
    /// Privacy Center modals and nav drawer become bottom sheets on phones.
    public let sheetOverlays: Bool

    static let classic = AppearanceLayout(
        sheet: false,
        collapsibleSections: false,
        switchControl: false,
        pairedFooter: false,
        loaderPill: false,
        sheetOverlays: false
    )

    static let glass = AppearanceLayout(
        sheet: true,
        collapsibleSections: true,
        // Checkboxes until the admin (or the host) picks switches, in every style.
        switchControl: false,
        pairedFooter: true,
        loaderPill: true,
        sheetOverlays: true
    )
}

/// Corner radii, in points, a style draws with when no radius is set.
public struct NoticeStyleRadii: Equatable {
    public let modal: CGFloat
    public let button: CGFloat
    public let panel: CGFloat
    public let control: CGFloat
}

/// A pill: any radius at least half the height rounds the ends fully.
public let noticePillRadius: CGFloat = 999

extension AppearanceStyle {
    /// Minimal and soft restyle classic's surfaces and keep its layout.
    public var layout: AppearanceLayout {
        self == .glass ? .glass : .classic
    }

    public var radii: NoticeStyleRadii {
        switch self {
        case .classic: return NoticeStyleRadii(modal: 8, button: 8, panel: 8, control: 6)
        case .minimal: return NoticeStyleRadii(modal: 4, button: 4, panel: 4, control: 4)
        case .soft: return NoticeStyleRadii(modal: 24, button: noticePillRadius, panel: 16, control: 12)
        case .glass: return NoticeStyleRadii(modal: 28, button: noticePillRadius, panel: 20, control: 12)
        }
    }
}

/// Where and how the notice is laid out, once the style's defaults, the console
/// and the host's `settings` are merged. Components branch on these, never on
/// the style name, so every layout works with every style.
public struct ResolvedNoticeLayout: Equatable {
    /// Phones: docked to the bottom edge, not a centred modal.
    public let mobileSheet: Bool
    public let desktopPosition: NoticeDesktopPosition
    /// Dim the page behind the notice.
    public let dimBackdrop: Bool
    /// Notice text and the DPO block collapse into disclosures.
    public let collapsibleSections: Bool
    /// Phone footer: Accept All full width, the other two side by side.
    public let pairedFooter: Bool
    /// Purpose and product checkboxes render as switches.
    public let switchControl: Bool
    /// Entrances and transitions play; Reduce Motion still wins.
    public let motion: Bool

    /// Docked to the bottom edge: a sheet on phones, the bottom bar elsewhere.
    public func isDocked(isPhone: Bool) -> Bool {
        isPhone ? mobileSheet : desktopPosition == .bottomBar
    }
}

/// Shared motion timings, used by every style so classic animates too.
public enum NoticeMotion {
    /// iOS sheet spring: fast start, long soft settle. `cubic-bezier(0.32, 0.72, 0, 1)`.
    public static let sheetCurve: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.32, 0.72, 0, 1)
    /// `cubic-bezier(0.22, 1, 0.36, 1)`.
    public static let outCurve: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.22, 1, 0.36, 1)
    public static let sheetDuration: Double = 0.62
    public static let dimDuration: Double = 0.42
    public static let collapseDuration: Double = 0.38
    /// Classic modals fade out quickly; glass sheets take `dimDuration`.
    public static let fadeDuration: Double = 0.2
    /// Classic Privacy Center accordions; never longer than `collapseDuration`.
    public static let classicCollapseDuration: Double = 0.3

    public static var sheet: Animation { curve(sheetCurve, sheetDuration) }
    public static var dim: Animation { curve(outCurve, dimDuration) }
    public static var collapse: Animation { curve(sheetCurve, collapseDuration) }
    public static var fade: Animation { curve(outCurve, fadeDuration) }

    /// Motion plays only when the notice allows it and the OS does not ask for
    /// reduced motion.
    public static func isEnabled(_ layout: ResolvedNoticeLayout, reduceMotion: Bool) -> Bool {
        layout.motion && !reduceMotion
    }

    /// `animation`, or `nil` (no animation) when motion is off.
    public static func animation(_ animation: Animation, enabled: Bool) -> Animation? {
        enabled ? animation : nil
    }

    private static func curve(_ c: (CGFloat, CGFloat, CGFloat, CGFloat), _ duration: Double) -> Animation {
        .timingCurve(c.0, c.1, c.2, c.3, duration: duration)
    }
}

/// A CSS box-shadow as its parts, in points.
public struct AppearanceShadow: Equatable {
    public let color: AppearanceRGBA
    public let x: CGFloat
    public let y: CGFloat
    public let blur: CGFloat
    public let spread: CGFloat
}

/// Every glass colour, derived from the brand accent and a surface tint so the
/// style inherits whatever palette the workspace configured.
public struct GlassPalette: Equatable {
    public static let defaultTint = AppearanceRGBA(r: 255, g: 255, b: 255)
    /// Near-black the accent is darkened toward for dims and shadows.
    static let shadeBase = AppearanceRGBA(r: 5, g: 5, b: 15)

    public enum Radius {
        public static let sheet: CGFloat = 28
        public static let panel: CGFloat = 20
        public static let control: CGFloat = 12
        public static let row: CGFloat = 10
        public static let pill: CGFloat = noticePillRadius
    }

    public let accent: AppearanceRGBA
    /// The sheet itself: most of what is behind shows through.
    public let sheet: AppearanceRGBA
    /// Sheets over dense text, and the fallback where no blur is drawn.
    public let sheetDense: AppearanceRGBA
    public let sheetEdge: AppearanceRGBA
    /// Grouped panels on the sheet (accordions, purpose list).
    public let panel: AppearanceRGBA
    public let panelEdge: AppearanceRGBA
    /// Rows nested inside a panel.
    public let inset: AppearanceRGBA
    /// Inputs, selects, menus: opaque enough to read typed text.
    public let control: AppearanceRGBA
    /// Footer band: a vertical gradient from `footerTop` to `footerBottom`,
    /// reached at `footerBottomStop` of the height.
    public let footerTop: AppearanceRGBA
    public let footerBottom: AppearanceRGBA
    public let footerBottomStop: CGFloat
    public let accentFaint: AppearanceRGBA
    public let accentWash: AppearanceRGBA
    public let accentWashStrong: AppearanceRGBA
    public let hairline: AppearanceRGBA
    public let outline: AppearanceRGBA
    /// Backdrop behind the sheet.
    public let dim: AppearanceRGBA
    public let shadow: AppearanceShadow
    public let floatShadow: AppearanceShadow
    public let primaryShadow: AppearanceShadow

    /// - Parameters:
    ///   - accent: the notice's resolved accent.
    ///   - tint: `surface`, else `background`, else white. Kept translucent.
    public init(accent: AppearanceRGBA, tint: AppearanceRGBA = GlassPalette.defaultTint) {
        let shade = AppearanceColor.mix(accent, Self.shadeBase, 0.7)
        func alpha(_ color: AppearanceRGBA, _ value: Double) -> AppearanceRGBA {
            AppearanceColor.withAlpha(color, value)
        }
        self.accent = accent
        sheet = alpha(tint, 0.52)
        sheetDense = alpha(tint, 0.86)
        sheetEdge = alpha(tint, 0.6)
        panel = alpha(tint, 0.5)
        panelEdge = alpha(tint, 0.55)
        inset = alpha(tint, 0.55)
        control = alpha(tint, 0.72)
        footerTop = alpha(tint, 0.35)
        footerBottom = alpha(tint, 0.9)
        footerBottomStop = 0.6
        accentFaint = alpha(accent, 0.04)
        accentWash = alpha(accent, 0.08)
        accentWashStrong = alpha(accent, 0.22)
        hairline = alpha(shade, 0.08)
        outline = alpha(shade, 0.14)
        dim = alpha(shade, 0.3)
        shadow = AppearanceShadow(color: alpha(shade, 0.35), x: 0, y: -18, blur: 50, spread: -12)
        floatShadow = AppearanceShadow(color: alpha(shade, 0.45), x: 0, y: 24, blur: 60, spread: -18)
        primaryShadow = AppearanceShadow(color: alpha(accent, 0.6), x: 0, y: 10, blur: 24, spread: -10)
    }
}
