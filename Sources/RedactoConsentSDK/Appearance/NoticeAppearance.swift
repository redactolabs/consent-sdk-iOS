import Foundation

/// Surface and layout family a notice is drawn with, chosen in the Redacto
/// console and served on `active_config.appearance.style`. Colours never come
/// from the style: they come from the admin's palette, else the notice's brand.
public enum AppearanceStyle: String, CaseIterable {
    case classic
    case glass
    case minimal
    case soft
}

/// How checkbox rows are drawn: native checkboxes, or switches.
public enum NoticeControlStyle: String, CaseIterable {
    case checkbox
    case `switch`
}

/// Phones: a centred modal, or a sheet docked to the bottom edge.
public enum NoticeMobileLayout: String, CaseIterable {
    case modal
    case sheet
}

/// Where the notice sits on wider screens.
public enum NoticeDesktopPosition: String, CaseIterable {
    case center
    case bottomRight = "bottom-right"
    case bottomLeft = "bottom-left"
    case bottomBar = "bottom-bar"
}

/// The page behind the notice: dimmed with `colors.overlay`, or left as is.
public enum NoticeBackdrop: String, CaseIterable {
    case dim
    case none
}

/// Phone footer: three stacked buttons, or Accept All over the other two.
public enum NoticePhoneFooter: String, CaseIterable {
    case stacked
    case paired
}

public enum NoticeTextScale: String, CaseIterable {
    case sm
    case md
    case lg

    /// Multiplies every text size the notice draws.
    public var factor: CGFloat {
        switch self {
        case .sm: return 0.92
        case .md: return 1
        case .lg: return 1.1
        }
    }
}

/// Every colour the console can set on a notice, in the order the server's
/// `NoticeAppearanceColorsIn` declares them. Keys outside this list are ignored,
/// so a newer console never breaks an older SDK.
public enum NoticeColorKey: String, CaseIterable {
    case background
    case surface
    case heading
    case text
    case mutedText = "muted_text"
    case link
    case border
    case overlay
    case acceptAllBg = "accept_all_bg"
    case acceptAllText = "accept_all_text"
    case acceptBg = "accept_bg"
    case acceptText = "accept_text"
    case declineBg = "decline_bg"
    case declineText = "decline_text"
    case declineBorder = "decline_border"
    case languageBg = "language_bg"
    case languageText = "language_text"
    case languageSelectedBg = "language_selected_bg"
    case languageSelectedText = "language_selected_text"
    case toggleOn = "toggle_on"
    case toggleOff = "toggle_off"
    case toggleKnob = "toggle_knob"
    case ttsHighlightBg = "tts_highlight_bg"
    case ttsHighlightText = "tts_highlight_text"
}

/// Only the colours that were set, keyed by the console's colour keys.
public typealias NoticeAppearanceColors = [NoticeColorKey: String]

/// `active_config.appearance` as served. Every key is optional and may be
/// unknown to this SDK version, so it is read through `NoticeAppearance.resolve`
/// and never trusted directly; an empty object is classic.
///
/// Each field decodes on its own: a value of the wrong JSON type reads as unset
/// instead of dropping the appearance (or the notice) with it.
public struct NoticeAppearance: Codable, Equatable {
    public var version: Int?
    public var style: String?
    public var template: String?
    public var colorMode: String?
    public var brandColor: String?
    /// String-valued entries only; the resolver keeps the known hex ones.
    public var colors: [String: String]?
    public var borderRadius: Double?
    public var selectionControl: String?
    public var controlStyle: String?
    public var confirmBeforeSubmit: Bool?
    public var mobileLayout: String?
    public var desktopPosition: String?
    public var backdrop: String?
    public var collapsibleSections: Bool?
    public var phoneFooter: String?
    public var autoDark: Bool?
    public var darkColors: [String: String]?
    public var maxWidth: Double?
    public var logoSize: Double?
    public var textScale: String?
    public var motion: Bool?
    /// Served for web SDKs; native notices have no CSS and ignore it.
    public var customCss: String?

    enum CodingKeys: String, CodingKey {
        case version, style, template, colors, backdrop, motion
        case colorMode = "color_mode"
        case brandColor = "brand_color"
        case borderRadius = "border_radius"
        case selectionControl = "selection_control"
        case controlStyle = "control_style"
        case confirmBeforeSubmit = "confirm_before_submit"
        case mobileLayout = "mobile_layout"
        case desktopPosition = "desktop_position"
        case collapsibleSections = "collapsible_sections"
        case phoneFooter = "phone_footer"
        case autoDark = "auto_dark"
        case darkColors = "dark_colors"
        case maxWidth = "max_width"
        case logoSize = "logo_size"
        case textScale = "text_scale"
        case customCss = "custom_css"
    }

    public init(
        version: Int? = nil,
        style: String? = nil,
        template: String? = nil,
        colorMode: String? = nil,
        brandColor: String? = nil,
        colors: [String: String]? = nil,
        borderRadius: Double? = nil,
        selectionControl: String? = nil,
        controlStyle: String? = nil,
        confirmBeforeSubmit: Bool? = nil,
        mobileLayout: String? = nil,
        desktopPosition: String? = nil,
        backdrop: String? = nil,
        collapsibleSections: Bool? = nil,
        phoneFooter: String? = nil,
        autoDark: Bool? = nil,
        darkColors: [String: String]? = nil,
        maxWidth: Double? = nil,
        logoSize: Double? = nil,
        textScale: String? = nil,
        motion: Bool? = nil,
        customCss: String? = nil
    ) {
        self.version = version
        self.style = style
        self.template = template
        self.colorMode = colorMode
        self.brandColor = brandColor
        self.colors = colors
        self.borderRadius = borderRadius
        self.selectionControl = selectionControl
        self.controlStyle = controlStyle
        self.confirmBeforeSubmit = confirmBeforeSubmit
        self.mobileLayout = mobileLayout
        self.desktopPosition = desktopPosition
        self.backdrop = backdrop
        self.collapsibleSections = collapsibleSections
        self.phoneFooter = phoneFooter
        self.autoDark = autoDark
        self.darkColors = darkColors
        self.maxWidth = maxWidth
        self.logoSize = logoSize
        self.textScale = textScale
        self.motion = motion
        self.customCss = customCss
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.optional(Int.self, forKey: .version)
        style = c.optional(String.self, forKey: .style)
        template = c.optional(String.self, forKey: .template)
        colorMode = c.optional(String.self, forKey: .colorMode)
        brandColor = c.optional(String.self, forKey: .brandColor)
        colors = c.stringEntries(forKey: .colors)
        borderRadius = c.optional(Double.self, forKey: .borderRadius)
        selectionControl = c.optional(String.self, forKey: .selectionControl)
        controlStyle = c.optional(String.self, forKey: .controlStyle)
        confirmBeforeSubmit = c.optional(Bool.self, forKey: .confirmBeforeSubmit)
        mobileLayout = c.optional(String.self, forKey: .mobileLayout)
        desktopPosition = c.optional(String.self, forKey: .desktopPosition)
        backdrop = c.optional(String.self, forKey: .backdrop)
        collapsibleSections = c.optional(Bool.self, forKey: .collapsibleSections)
        phoneFooter = c.optional(String.self, forKey: .phoneFooter)
        autoDark = c.optional(Bool.self, forKey: .autoDark)
        darkColors = c.stringEntries(forKey: .darkColors)
        maxWidth = c.optional(Double.self, forKey: .maxWidth)
        logoSize = c.optional(Double.self, forKey: .logoSize)
        textScale = c.optional(String.self, forKey: .textScale)
        motion = c.optional(Bool.self, forKey: .motion)
        customCss = c.optional(String.self, forKey: .customCss)
    }
}

private struct AppearanceDynamicKey: CodingKey {
    let stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer {
    /// An object's string entries, one by one: a non-string value drops only
    /// that key, and a non-object reads as `nil`.
    func stringEntries(forKey key: Key) -> [String: String]? {
        guard let nested = try? nestedContainer(keyedBy: AppearanceDynamicKey.self, forKey: key) else {
            return nil
        }
        var entries: [String: String] = [:]
        for entryKey in nested.allKeys {
            if let value = try? nested.decode(String.self, forKey: entryKey) {
                entries[entryKey.stringValue] = value
            }
        }
        return entries
    }
}
