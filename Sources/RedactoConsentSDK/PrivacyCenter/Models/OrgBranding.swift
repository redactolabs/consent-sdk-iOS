import Foundation

/// Workspace branding served by the user server (React api/orgBranding.ts).
public struct OrgBrandingTheme: Codable, Sendable, Equatable {
    public let primary: String?
    public let secondary: String?
    public let primaryContrast: String?
    public let link: String?
    public let surface: String?
    public let text: String?
    public let textMuted: String?
    public let border: String?
    public let success: String?
    public let warning: String?
    public let danger: String?

    enum CodingKeys: String, CodingKey {
        case primary, secondary, link, surface, text, border, success, warning, danger
        case primaryContrast = "primary_contrast"
        case textMuted = "text_muted"
    }

    public init(
        primary: String? = nil, secondary: String? = nil, primaryContrast: String? = nil, link: String? = nil,
        surface: String? = nil, text: String? = nil, textMuted: String? = nil, border: String? = nil,
        success: String? = nil, warning: String? = nil, danger: String? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.primaryContrast = primaryContrast
        self.link = link
        self.surface = surface
        self.text = text
        self.textMuted = textMuted
        self.border = border
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primary = c.optional(String.self, forKey: .primary)
        secondary = c.optional(String.self, forKey: .secondary)
        primaryContrast = c.optional(String.self, forKey: .primaryContrast)
        link = c.optional(String.self, forKey: .link)
        surface = c.optional(String.self, forKey: .surface)
        text = c.optional(String.self, forKey: .text)
        textMuted = c.optional(String.self, forKey: .textMuted)
        border = c.optional(String.self, forKey: .border)
        success = c.optional(String.self, forKey: .success)
        warning = c.optional(String.self, forKey: .warning)
        danger = c.optional(String.self, forKey: .danger)
    }
}

public struct OrgBrandingDetail: Codable, Sendable, Equatable {
    public let logoUrl: String?
    public let iconUrl: String?
    public let brandName: String?
    public let theme: OrgBrandingTheme?
    public let hidePlatformBranding: Bool

    enum CodingKeys: String, CodingKey {
        case theme
        case logoUrl = "logo_url"
        case iconUrl = "icon_url"
        case brandName = "brand_name"
        case hidePlatformBranding = "hide_platform_branding"
    }

    public init(logoUrl: String? = nil, iconUrl: String? = nil, brandName: String? = nil, theme: OrgBrandingTheme? = nil, hidePlatformBranding: Bool = false) {
        self.logoUrl = logoUrl
        self.iconUrl = iconUrl
        self.brandName = brandName
        self.theme = theme
        self.hidePlatformBranding = hidePlatformBranding
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        logoUrl = c.optional(String.self, forKey: .logoUrl)
        iconUrl = c.optional(String.self, forKey: .iconUrl)
        brandName = c.optional(String.self, forKey: .brandName)
        theme = c.optional(OrgBrandingTheme.self, forKey: .theme)
        hidePlatformBranding = c.lenient(Bool.self, forKey: .hidePlatformBranding)
    }
}
