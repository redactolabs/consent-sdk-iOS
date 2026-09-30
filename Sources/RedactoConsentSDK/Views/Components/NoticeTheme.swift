import SwiftUI

/// What the modal notice paints with: the resolved console appearance under the
/// host's settings, mapped onto the parts React's styles, variant patches and
/// glass skin draw. Every view of the modal reads it from the environment; a
/// view outside the modal gets `classic`, which paints as it always has.
struct NoticeTheme {
    let appearance: ResolvedNoticeAppearance
    let layout: ResolvedNoticeLayout
    let isPhone: Bool
    /// The notice's brand colour, Accept All's fallback.
    let primaryColor: String?
    /// Set only for the glass style.
    let glass: GlassPalette?

    let heading: Color
    let text: Color
    let link: Color
    /// The brand accent: Accept Selected, switches, focus.
    let accent: Color
    let accentRGBA: AppearanceRGBA
    /// A checked checkbox; the admin's toggle colour, else the SDK blue.
    let checkboxOn: Color
    let checkboxOff: Color
    let checkboxFill: Color?
    let switchOn: Color
    let switchTrack: Color
    let knob: Color
    let confirmHint: Color
    let border: Color?

    init(
        appearance: ResolvedNoticeAppearance,
        primaryColor: String?,
        secondaryColor: String?,
        isPhone: Bool,
        hasContent: Bool = true
    ) {
        let colors = appearance.colors
        self.appearance = appearance
        self.layout = appearance.layout
        self.isPhone = isPhone
        self.primaryColor = primaryColor.nonEmptyValue

        let headingHex = Self.paintable(colors[.heading], "#323B4B")
        heading = Self.color(headingHex)
        text = Self.color(Self.paintable(colors[.text], "#344054"))
        link = Self.color(Self.paintable(colors[.link] ?? secondaryColor.nonEmptyValue, "#4f87ff"))

        // Before the notice arrives its brand colour is unknown, so the accent
        // takes the neutral heading colour rather than flashing the SDK blue.
        let accentHex = colors[.toggleOn]
            ?? colors[.acceptAllBg]
            ?? primaryColor.nonEmptyValue
            ?? (hasContent ? NoticeAppearanceDefaults.accentColor : headingHex)
        let accentValue = AppearanceColor.parse(Self.paintable(accentHex, NoticeAppearanceDefaults.accentColor))
            ?? AppearanceRGBA(r: 79, g: 135, b: 255)
        accentRGBA = accentValue
        accent = accentValue.color

        let palette: GlassPalette? = appearance.style == .glass
            ? GlassPalette(
                accent: accentValue,
                tint: AppearanceColor.parse(colors[.surface] ?? colors[.background]) ?? GlassPalette.defaultTint
            )
            : nil
        glass = palette

        let themedAccent = colors[.toggleOn] ?? colors[.acceptAllBg]
        checkboxOn = Self.color(Self.paintable(themedAccent, "#4f87ff"))
        if let palette, !appearance.layout.switchControl {
            checkboxOff = AppearanceColor.color(colors[.toggleOff]) ?? AppearanceColor.withAlpha(palette.accent, 0.55).color
            checkboxFill = palette.control.color
        } else {
            checkboxOff = Self.color(Self.paintable(colors[.toggleOff], "#d0d5dd"))
            checkboxFill = nil
        }
        switchOn = palette?.accent.color ?? checkboxOn
        switchTrack = AppearanceColor.color(colors[.toggleOff]) ?? palette?.accentWashStrong.color ?? Self.color("#d0d5dd")
        knob = Self.color(Self.paintable(colors[.toggleKnob], "#ffffff"))
        if palette != nil {
            confirmHint = text.opacity(0.8)
        } else {
            confirmHint = Self.color(Self.paintable(colors[.mutedText], "#6b6b6b"))
        }
        border = AppearanceColor.color(colors[.border])
    }

    static let classic = NoticeTheme(
        appearance: ResolvedNoticeAppearance(),
        primaryColor: nil,
        secondaryColor: nil,
        isPhone: true
    )

    var isGlass: Bool { glass != nil }
    var style: AppearanceStyle { appearance.style }
    var colors: NoticeAppearanceColors { appearance.colors }

    // MARK: - Card

    var modalRadius: CGFloat { appearance.modalRadius }
    var buttonRadius: CGFloat { appearance.buttonRadius }
    var panelRadius: CGFloat { appearance.radius ?? appearance.style.radii.panel }
    var controlRadius: CGFloat { appearance.radius ?? appearance.style.radii.control }

    /// The card's surface; glass lets the page show through a material.
    @ViewBuilder
    var cardBackground: some View {
        if let glass {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(glass.sheet.color)
            }
        } else {
            Rectangle().fill(Self.color(Self.paintable(colors[.background], "#ffffff")))
        }
    }

    /// The card's edge: a hairline for minimal, the sheet edge for glass.
    var cardEdge: Color? {
        if let glass { return glass.sheetEdge.color }
        if style == .minimal { return border ?? Self.color("#e4e7ec") }
        return nil
    }

    func cardShadow(docked: Bool) -> AppearanceShadow? {
        if let glass { return docked ? glass.shadow : glass.floatShadow }
        switch style {
        case .classic:
            return AppearanceShadow(color: AppearanceRGBA(r: 0, g: 0, b: 0, a: 0.25), x: 4, y: 0, blur: 4, spread: 0)
        case .soft:
            return AppearanceShadow(color: AppearanceRGBA(r: 16, g: 24, b: 40, a: 0.22), x: 0, y: 24, blur: 48, spread: -12)
        case .minimal, .glass:
            return nil
        }
    }

    /// The page dim, or nil when the backdrop is off (the page stays blocked).
    var overlay: Color? {
        guard layout.dimBackdrop else { return nil }
        if let overlay = AppearanceColor.color(colors[.overlay]) { return overlay }
        if let glass { return glass.dim.color }
        return Color.black.opacity(0.5)
    }

    /// The card's width on wider screens.
    var desktopWidth: CGFloat {
        appearance.maxWidth ?? (isGlass ? 640 : 700)
    }

    // MARK: - Type

    /// A text role's size before the text scale, which `noticeFont` applies.
    func size(_ role: NoticeTextRole) -> CGFloat {
        switch role {
        case .title: return isGlass ? (isPhone ? 19 : 21) : (isPhone ? 16 : 18)
        case .subTitle: return isGlass ? 14 : (isPhone ? 14 : 16)
        case .optionTitle: return isGlass ? (isPhone ? 14 : 15) : (isPhone ? 14 : 16)
        case .optionDescription: return isGlass ? (isPhone ? 12 : 13) : (isPhone ? 12 : 14)
        case .dataElement: return isGlass ? 13 : (isPhone ? 12 : 14)
        case .privacyText: return isGlass ? (isPhone ? 13 : 14) : (isPhone ? 14 : 16)
        case .dpo: return isPhone ? 13 : 14
        case .button: return isGlass ? 15 : (isPhone ? 14 : 16)
        case .chip: return isPhone ? 11 : 12
        case .confirmHint: return isGlass ? 12 : 13
        }
    }

    func weight(_ role: NoticeTextRole) -> Font.Weight {
        switch role {
        case .title: return isGlass ? .heavy : .bold
        case .subTitle: return isGlass ? .bold : .semibold
        case .optionTitle: return isGlass ? .bold : .medium
        case .dataElement: return isGlass ? .medium : .regular
        case .chip: return isGlass ? .semibold : .regular
        case .button:
            switch style {
            case .classic: return .regular
            case .minimal: return .medium
            case .soft: return .semibold
            case .glass: return .bold
            }
        case .optionDescription, .privacyText, .dpo, .confirmHint: return .regular
        }
    }

    /// A product heading: the purpose title's size, a heading's weight.
    var sectionTitleWeight: Font.Weight { isGlass ? .bold : .semibold }

    // MARK: - Buttons

    var acceptAll: NoticeButtonPaint {
        NoticeButtonPaint(
            background: Self.color(Self.paintable(
                colors[.acceptAllBg] ?? colors[.toggleOn] ?? primaryColor,
                NoticeAppearanceDefaults.accentColor
            )),
            foreground: Self.color(Self.paintable(colors[.acceptAllText], "#ffffff")),
            border: nil,
            shadow: glass?.primaryShadow
        )
    }

    var acceptSelected: NoticeButtonPaint {
        let textColor = AppearanceColor.color(colors[.acceptText]) ?? accent
        return NoticeButtonPaint(
            background: AppearanceColor.color(colors[.acceptBg]) ?? glass?.accentWash.color ?? .white,
            foreground: textColor,
            border: isGlass ? nil : textColor,
            shadow: nil
        )
    }

    var decline: NoticeButtonPaint {
        NoticeButtonPaint(
            background: AppearanceColor.color(colors[.declineBg]) ?? (isGlass ? .clear : .white),
            foreground: AppearanceColor.color(colors[.declineText]) ?? (isGlass ? text : .black),
            border: AppearanceColor.color(colors[.declineBorder]) ?? border ?? glass?.outline.color ?? Self.color("#d0d5dd"),
            shadow: nil
        )
    }

    /// The language chip and the talkback button beside it.
    var chip: NoticeChipPaint {
        NoticeChipPaint(
            background: AppearanceColor.color(colors[.languageBg]) ?? glass?.control.color ?? .white,
            foreground: AppearanceColor.color(colors[.languageText]) ?? (isGlass ? heading : Self.color("#344054")),
            border: border ?? glass?.hairline.color ?? Self.color("#d0d5dd"),
            radius: isGlass && appearance.radius == nil ? noticePillRadius : buttonRadius,
            height: isGlass ? 32 : nil
        )
    }

    // MARK: - Panels

    /// The OTP step's panel.
    var otpPanel: NoticePanelPaint {
        if let glass {
            return NoticePanelPaint(fill: glass.panel.color, edge: glass.panelEdge.color, radius: GlassPalette.Radius.panel)
        }
        let surface = AppearanceColor.color(colors[.surface] ?? colors[.background]) ?? Self.color("#f9fafb")
        let edge = border ?? Self.color("#e5e7eb")
        switch style {
        case .minimal: return NoticePanelPaint(fill: surface, edge: edge, radius: 4)
        case .soft: return NoticePanelPaint(fill: AppearanceColor.withAlpha(accentRGBA, 0.06).color, edge: edge, radius: 16)
        default: return NoticePanelPaint(fill: surface, edge: edge, radius: 8)
        }
    }

    var otpTitle: Color { AppearanceColor.color(colors[.heading]) ?? (isGlass ? heading : Self.color("#111827")) }
    var otpDescription: Color {
        if isGlass { return text.opacity(0.85) }
        return AppearanceColor.color(colors[.mutedText]) ?? Self.color("#6b7280")
    }

    /// The surface the layout parts (disclosures, grabber) draw on.
    var sectionPanel: NoticePanelPaint {
        if let glass {
            return NoticePanelPaint(fill: glass.panel.color, edge: glass.panelEdge.color, radius: GlassPalette.Radius.panel)
        }
        return NoticePanelPaint(
            fill: AppearanceColor.color(colors[.surface] ?? colors[.background]) ?? .white,
            edge: border ?? Self.color("#e4e7ec"),
            radius: panelRadius
        )
    }

    var accentWash: Color { AppearanceColor.withAlpha(accentRGBA, 0.08).color }

    var grabber: Color {
        glass?.outline.color ?? AppearanceColor.color(colors[.toggleOff]) ?? Self.color("#d0d5dd")
    }

    /// The purposes list's own panel: glass groups the rows on one.
    var purposesPanel: NoticePanelPaint? {
        guard let glass else { return nil }
        return NoticePanelPaint(fill: glass.panel.color, edge: glass.panelEdge.color, radius: GlassPalette.Radius.panel)
    }

    var rowSeparator: Color? { glass?.hairline.color }

    /// A purpose row's own surface.
    var optionRow: NoticeOptionRowPaint {
        if isGlass {
            return NoticeOptionRowPaint(
                insets: isPhone ? EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 14)
                    : EdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 16),
                fill: nil, radius: 0, bottomRule: nil
            )
        }
        switch style {
        case .minimal:
            return NoticeOptionRowPaint(
                insets: EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0),
                fill: nil, radius: 0, bottomRule: border ?? Self.color("#e4e7ec")
            )
        case .soft:
            return NoticeOptionRowPaint(
                insets: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14),
                fill: AppearanceColor.withAlpha(accentRGBA, 0.06).color, radius: 16, bottomRule: nil
            )
        default:
            return NoticeOptionRowPaint(insets: EdgeInsets(), fill: nil, radius: 0, bottomRule: nil)
        }
    }

    /// Glass sets data elements on inset rows.
    var dataElementRow: NoticePanelPaint? {
        guard let glass else { return nil }
        return NoticePanelPaint(fill: glass.inset.color, edge: nil, radius: GlassPalette.Radius.row)
    }

    // MARK: - Talkback

    var ttsHighlight: Color { Self.color(Self.paintable(appearance.ttsHighlightBackground, NoticeAppearanceDefaults.ttsHighlightBackground)) }
    var ttsText: Color? { AppearanceColor.color(colors[.ttsHighlightText]) }

    /// The colour of a text the talkback may highlight.
    func ttsColor(_ base: Color, highlighted: Bool) -> Color {
        highlighted ? (ttsText ?? base) : base
    }

    // MARK: - Private

    static func paintable(_ value: String?, _ fallback: String) -> String {
        AppearanceColor.paintable(value, fallback: fallback)
    }

    static func color(_ value: String) -> Color {
        AppearanceColor.color(value) ?? .black
    }
}

enum NoticeTextRole {
    case title
    case subTitle
    case optionTitle
    case optionDescription
    case dataElement
    case privacyText
    case dpo
    case button
    case chip
    case confirmHint
}

struct NoticeButtonPaint {
    let background: Color
    let foreground: Color
    let border: Color?
    let shadow: AppearanceShadow?
}

struct NoticeChipPaint {
    let background: Color
    let foreground: Color
    let border: Color
    let radius: CGFloat
    let height: CGFloat?
}

struct NoticePanelPaint {
    let fill: Color
    let edge: Color?
    let radius: CGFloat
}

struct NoticeOptionRowPaint {
    let insets: EdgeInsets
    let fill: Color?
    let radius: CGFloat
    let bottomRule: Color?
}

private struct NoticeThemeKey: EnvironmentKey {
    static let defaultValue: NoticeTheme? = nil
}

private struct NoticeTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    /// Set only inside the modal notice.
    var noticeTheme: NoticeTheme? {
        get { self[NoticeThemeKey.self] }
        set { self[NoticeThemeKey.self] = newValue }
    }

    /// Multiplies every `noticeFont` size.
    var noticeTextScale: CGFloat {
        get { self[NoticeTextScaleKey.self] }
        set { self[NoticeTextScaleKey.self] = newValue }
    }
}

extension View {
    func noticeShadow(_ shadow: AppearanceShadow?) -> some View {
        self.shadow(
            color: shadow?.color.color ?? .clear,
            radius: (shadow?.blur ?? 0) / 2,
            x: shadow?.x ?? 0,
            y: shadow?.y ?? 0
        )
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyValue: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}
