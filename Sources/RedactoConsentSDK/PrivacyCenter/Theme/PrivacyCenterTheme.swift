import SwiftUI

public enum PrivacyCenterThemeMode: String, Sendable, Equatable {
    case light, dark
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
