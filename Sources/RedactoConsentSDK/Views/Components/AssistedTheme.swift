import SwiftUI

/// What the assisted notice paints with: React's `buildVariantStyles` over the
/// assisted styles, from the console appearance under the host's `settings`
/// and the notice's brand colours (tsx ~614-733). Display only.
struct AssistedTheme {
    let appearance: ResolvedNoticeAppearance
    let isMobile: Bool
    /// `accept_all_bg`, then the notice's `primary_color`: Accept All, the
    /// verify step's primary button, links and focus in the verify panel.
    let primaryHex: String
    /// `link`, then the notice's `secondary_color`.
    let linkHex: String

    init(appearance: ResolvedNoticeAppearance, config: ActiveConfig?, isMobile: Bool) {
        self.appearance = appearance
        self.isMobile = isMobile
        primaryHex = Self.first(appearance.colors[.acceptAllBg], config?.primaryColor) ?? NoticeAppearanceDefaults.accentColor
        linkHex = Self.first(appearance.colors[.link], config?.secondaryColor) ?? NoticeAppearanceDefaults.accentColor
    }

    var primary: Color { color(primaryHex) }
    var link: Color { color(linkHex) }
    var background: Color { appearance.color(.background) ?? .white }
    var heading: Color { appearance.color(.heading) ?? Color(hex: "#101828") }
    var text: Color { appearance.color(.text) ?? Color(hex: "#344054") }
    var mutedText: Color { appearance.color(.mutedText) ?? Color(hex: "#475467") }
    var border: Color { appearance.color(.border) ?? Color(hex: "#d0d5dd") }
    var chevron: Color { appearance.color(.heading) ?? Color(hex: AssistedDefaults.chevronColor) }
    var highlightBackground: Color { color(appearance.ttsHighlightBackground) }
    var highlightText: Color? { appearance.color(.ttsHighlightText) }
    /// The filled OTP box: the primary colour at 8%.
    var primaryTint: Color {
        AppearanceColor.parse(primaryHex).map { AppearanceColor.withAlpha($0, 0.08).color } ?? Color(hex: "#F5F8FF")
    }

    var buttonRadius: CGFloat { appearance.buttonRadius }

    var buttonWeight: Font.Weight {
        switch appearance.style {
        case .minimal: return .medium
        case .soft: return .semibold
        default: return .regular
        }
    }

    // Text sizes, phone then wider, times the console's text scale.
    var titleSize: CGFloat { scaled(18, 16) }
    var subTitleSize: CGFloat { scaled(16, 14) }
    var privacyTextSize: CGFloat { scaled(16, 14) }
    var footerSize: CGFloat { scaled(14, 13) }
    var buttonSize: CGFloat { scaled(16, 14) }
    var pillSize: CGFloat { scaled(12, 11) }

    func scaled(_ wide: CGFloat, _ phone: CGFloat) -> CGFloat {
        appearance.scaled(isMobile ? phone : wide)
    }

    func rowStyle(ts: AssistedI18n, isHighlighted: @escaping (String) -> Bool) -> PairRowStyle {
        var style = PairRowStyle()
        style.titleSize = scaled(16, 14)
        style.descriptionSize = scaled(14, 12)
        style.elementSize = scaled(14, 12)
        style.descriptionColor = mutedText
        style.chevronColor = chevron
        style.hidesEmptyDescription = true
        style.purposeBoxSize = 20
        style.elementBoxSize = 16
        style.lockedOpacity = 0.55
        style.collapseLabel = { collapsed, name in
            collapsed ? ts(.expandDetails, ["name": name]) : ts(.collapseDetails, ["name": name])
        }
        style.purposeControlLabel = { ts(.selectAllFor, ["name": $0]) }
        style.elementLabel = { name, required in
            required ? ts(.selectElementRequired, ["name": name]) : ts(.selectElement, ["name": name])
        }
        style.requiredLabel = ts(.required)
        style.isHighlighted = isHighlighted
        style.highlightBackground = highlightBackground
        style.highlightText = highlightText
        switch appearance.style {
        case .minimal:
            style.rowPadding = EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
            style.rowDivider = appearance.color(.border) ?? Color(hex: "#e4e7ec")
        case .soft:
            style.rowPadding = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
            style.rowCornerRadius = 16
            style.rowBackground = AppearanceColor.parse(primaryHex).map { AppearanceColor.withAlpha($0, 0.06).color }
        default:
            break
        }
        return style
    }

    private func color(_ hex: String) -> Color {
        AppearanceColor.color(hex) ?? Color(hex: hex)
    }

    private static func first(_ values: String?...) -> String? {
        values.lazy.compactMap { $0 }.first { !$0.isEmpty }
    }
}
