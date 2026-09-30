import SwiftUI

private struct NoticeFontFamilyKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var noticeFontFamily: String? {
        get { self[NoticeFontFamilyKey.self] }
        set { self[NoticeFontFamilyKey.self] = newValue }
    }
}

private struct NoticeFontModifier: ViewModifier {
    @Environment(\.noticeFontFamily) private var family
    @Environment(\.noticeTextScale) private var scale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        // One decimal place, as the web SDK rounds its scaled px sizes.
        let scaled = (size * scale * 10).rounded() / 10 * NoticeDynamicType.factor(dynamicTypeSize)
        // The web SDK sets text at 1.5x line height (14px on 21px lines);
        // a font's own leading is about 1.15x, so the rest goes between lines.
        content
            .font(NoticeFontResolver.font(family: family, size: scaled, weight: weight))
            .lineSpacing(noticeLineGap(scaled))
    }
}

extension View {
    func noticeFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(NoticeFontModifier(size: size, weight: weight))
    }
}

/// The extra space the web's 1.5x line height puts between two lines of text
/// at `size`: inside a wrapped paragraph, and between stacked one-line items.
func noticeLineGap(_ size: CGFloat) -> CGFloat {
    size * 0.35
}

/// The user's text-size setting. At the default size the factor is exactly 1, so
/// the notice measures as the web SDK's does; a larger setting grows it along
/// iOS's body-text curve, capped where the card and its buttons still work.
enum NoticeDynamicType {
    static let maxFactor: CGFloat = 2

    static func factor(_ size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: category(size))
        let body = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: traits)
        return min(maxFactor, body / 17)
    }

    static func category(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
