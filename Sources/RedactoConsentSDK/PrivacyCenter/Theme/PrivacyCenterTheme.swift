import SwiftUI

public enum PrivacyCenterThemeMode: String, Sendable, Equatable {
    case light, dark
}

/// Presentation options for the Privacy Center, mirroring React's
/// `settings` prop (`PrivacyCenterSettings`).
public struct PrivacyCenterSettings: Sendable, Equatable {
    /// `"classic"` (the default) or `"glass"`; both take their colours from
    /// workspace branding. Anything unrecognised falls back to classic.
    public var theme: String?

    public init(theme: String? = nil) {
        self.theme = theme
    }

    var appearance: AppearanceStyle {
        theme.flatMap(AppearanceStyle.init(rawValue:)) ?? .classic
    }
}

public struct PrivacyCenterTheme: Sendable, Equatable {
    public let mode: PrivacyCenterThemeMode
    public let background: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let text: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let border: Color
    public let primary: Color
    public let primaryText: Color
    public let primarySoft: Color
    public let error: Color
    public let success: Color
    public let warning: Color
    public let info: Color
    public let badgeSuccessBg: Color
    public let badgeSuccessText: Color
    public let badgeErrorBg: Color
    public let badgeErrorText: Color
    public let badgeWarningBg: Color
    public let badgeWarningText: Color
    public let badgeInfoBg: Color
    public let badgeInfoText: Color
    public let badgeSecondaryBg: Color
    public let badgeSecondaryText: Color
    /// Classic or glass (React `settings.theme`).
    public var appearance: AppearanceStyle = .classic

    public var isGlass: Bool { appearance == .glass }
    /// Cards and panels: glass rounds them further (GLASS_RADIUS.panel).
    public var panelRadius: CGFloat { isGlass ? GlassPalette.Radius.panel : 12 }
    public var controlRadius: CGFloat { isGlass ? GlassPalette.Radius.control : 8 }
    public var buttonRadius: CGFloat { isGlass ? GlassPalette.Radius.pill : 10 }
    /// A frosted fill on glass, the plain surface on classic.
    public var panelFill: AnyShapeStyle { isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(surface) }

    public static let light = PrivacyCenterTheme(
        mode: .light,
        background: Color(hex: "#ffffff"),
        surface: Color(hex: "#f9fafb"),
        surfaceElevated: Color(hex: "#ffffff"),
        text: Color(hex: "#344054"),
        textSecondary: Color(hex: "#667085"),
        textTertiary: Color(hex: "#98a2b3"),
        border: Color(hex: "#d0d5dd"),
        primary: Color(hex: "#4f87ff"),
        primaryText: Color(hex: "#ffffff"),
        primarySoft: Color(hex: "#eaf1ff"),
        error: Color(hex: "#DC2626"),
        success: Color(hex: "#10B981"),
        warning: Color(hex: "#F59E0B"),
        info: Color(hex: "#3b82f6"),
        badgeSuccessBg: Color(hex: "#d1fae5"),
        badgeSuccessText: Color(hex: "#059669"),
        badgeErrorBg: Color(hex: "#fee2e2"),
        badgeErrorText: Color(hex: "#DC2626"),
        badgeWarningBg: Color(hex: "#fef3c7"),
        badgeWarningText: Color(hex: "#92400e"),
        badgeInfoBg: Color(hex: "#dbeafe"),
        badgeInfoText: Color(hex: "#1d4ed8"),
        badgeSecondaryBg: Color(hex: "#f3f4f6"),
        badgeSecondaryText: Color(hex: "#374151")
    )

    public static let dark = PrivacyCenterTheme(
        mode: .dark,
        background: Color(hex: "#1a1a2e"),
        surface: Color(hex: "#16213e"),
        surfaceElevated: Color(hex: "#1e2a4a"),
        text: Color(hex: "#e2e8f0"),
        textSecondary: Color(hex: "#94a3b8"),
        textTertiary: Color(hex: "#64748b"),
        border: Color(hex: "#334155"),
        primary: Color(hex: "#4f87ff"),
        primaryText: Color(hex: "#ffffff"),
        primarySoft: Color(hex: "#1e3a8a").opacity(0.4),
        error: Color(hex: "#f87171"),
        success: Color(hex: "#34d399"),
        warning: Color(hex: "#fbbf24"),
        info: Color(hex: "#60a5fa"),
        badgeSuccessBg: Color(hex: "#10B981").opacity(0.18),
        badgeSuccessText: Color(hex: "#34d399"),
        badgeErrorBg: Color(hex: "#DC2626").opacity(0.18),
        badgeErrorText: Color(hex: "#f87171"),
        badgeWarningBg: Color(hex: "#F59E0B").opacity(0.18),
        badgeWarningText: Color(hex: "#fbbf24"),
        badgeInfoBg: Color(hex: "#3b82f6").opacity(0.18),
        badgeInfoText: Color(hex: "#60a5fa"),
        badgeSecondaryBg: Color(hex: "#334155").opacity(0.6),
        badgeSecondaryText: Color(hex: "#cbd5e1")
    )

    public static func from(mode: PrivacyCenterThemeMode) -> PrivacyCenterTheme {
        mode == .dark ? .dark : .light
    }

    /// Workspace branding over the defaults (React applyBrandingTheme). The
    /// branding palette is built for a light surface, so on dark only the
    /// identity colours (primary, status hues) apply; its surface, text and
    /// border would turn a dark Privacy Center white.
    public static func from(
        mode: PrivacyCenterThemeMode,
        branding: OrgBrandingTheme?,
        appearance: AppearanceStyle = .classic
    ) -> PrivacyCenterTheme {
        let base = from(mode: mode)
        func pick(_ raw: String?, _ fallback: Color) -> Color {
            AppearanceColor.parse(raw)?.color ?? fallback
        }
        let surfaces = mode == .light ? branding : nil
        let primary = pick(branding?.primary, base.primary)
        let primaryRGBA = AppearanceColor.parse(branding?.primary)
        var theme = PrivacyCenterTheme(
            mode: mode,
            background: pick(surfaces?.surface, base.background),
            surface: base.surface,
            surfaceElevated: pick(surfaces?.surface, base.surfaceElevated),
            text: pick(surfaces?.text, base.text),
            textSecondary: pick(surfaces?.textMuted, base.textSecondary),
            textTertiary: base.textTertiary,
            border: pick(surfaces?.border, base.border),
            primary: primary,
            primaryText: pick(branding?.primaryContrast, base.primaryText),
            primarySoft: primaryRGBA.map { AppearanceColor.withAlpha($0, mode == .light ? 0.1 : 0.25).color } ?? base.primarySoft,
            error: pick(branding?.danger, base.error),
            success: pick(branding?.success, base.success),
            warning: pick(branding?.warning, base.warning),
            info: primaryRGBA == nil ? base.info : primary,
            badgeSuccessBg: base.badgeSuccessBg,
            badgeSuccessText: base.badgeSuccessText,
            badgeErrorBg: base.badgeErrorBg,
            badgeErrorText: base.badgeErrorText,
            badgeWarningBg: base.badgeWarningBg,
            badgeWarningText: base.badgeWarningText,
            badgeInfoBg: base.badgeInfoBg,
            badgeInfoText: base.badgeInfoText,
            badgeSecondaryBg: base.badgeSecondaryBg,
            badgeSecondaryText: base.badgeSecondaryText
        )
        theme.appearance = appearance
        return theme
    }
}

private struct PrivacyCenterThemeKey: EnvironmentKey {
    static let defaultValue: PrivacyCenterTheme = .light
}

public extension EnvironmentValues {
    var privacyCenterTheme: PrivacyCenterTheme {
        get { self[PrivacyCenterThemeKey.self] }
        set { self[PrivacyCenterThemeKey.self] = newValue }
    }
}
