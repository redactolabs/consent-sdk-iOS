import Foundation

/// Code-side styling for the notice. Everything here is optional and overrides,
/// key by key, the appearance set in the Redacto console
/// (`active_config.appearance`): host settings, then the console, then the
/// notice's brand colours and the SDK defaults. Colours are CSS hex or
/// `rgb()`/`rgba()`; lengths are points, written `"12"` or `"12px"`.
public struct ConsentSettings {
    public var button: ButtonSettings?
    public var link: String?
    public var borderRadius: String?
    public var backgroundColor: String?
    /// Raised surfaces: menus and panels, and the tint of the glass style.
    public var surfaceColor: String?
    public var headingColor: String?
    public var textColor: String?
    /// Descriptions and hints.
    public var mutedTextColor: String?
    public var borderColor: String?
    /// The page dim behind the notice.
    public var overlayColor: String?
    public var toggle: ToggleSettings?
    /// The element being read aloud by text-to-speech.
    public var ttsHighlight: TTSHighlightSettings?
    public var font: String?
    /// Visual style. Unset, the console's style (else classic) applies.
    public var theme: AppearanceStyle?
    /// How checkbox rows are drawn, in any style. Unset keeps checkboxes.
    public var controlStyle: NoticeControlStyle?
    /// Phones: `.modal` (centred) or `.sheet` (docked to the bottom edge).
    public var mobileLayout: NoticeMobileLayout?
    /// Wider screens: where the notice card sits.
    public var desktopPosition: NoticeDesktopPosition?
    /// `.dim` darkens the page behind the notice; `.none` leaves it as is.
    public var backdrop: NoticeBackdrop?
    /// Collapse the notice text and the DPO block into disclosures.
    public var collapsibleSections: Bool?
    /// Phones: `.stacked` buttons, or `.paired` (Accept All over the other two).
    public var phoneFooter: NoticePhoneFooter?
    /// Follow the device's dark mode with `darkPalette` (else the console's).
    public var autoDark: Bool?
    public var darkPalette: ConsentSettingsPalette?
    /// Card width on wider screens.
    public var maxWidth: String?
    /// Logo height.
    public var logoSize: String?
    /// Scales every text size.
    public var textScale: NoticeTextScale?
    /// `false` turns entrances and transitions off.
    public var motion: Bool?

    // Optional underneath so "unset" is distinguishable from the default: an
    // unset value lets the console's choice through.
    var selectionControlOverride: SelectionControlType?
    var confirmBeforeSubmitOverride: Bool?

    /// Defaults to `.checkbox`. Applies to the purpose rows and the product
    /// section headings, not to individual data elements.
    public var selectionControl: SelectionControlType {
        get { selectionControlOverride ?? NoticeAppearanceDefaults.selectionControl }
        set { selectionControlOverride = newValue }
    }

    /// Asks "are you sure" before Accept All, Accept Selected or Decline submits.
    public var confirmBeforeSubmit: Bool {
        get { confirmBeforeSubmitOverride ?? false }
        set { confirmBeforeSubmitOverride = newValue }
    }

    public init(
        button: ButtonSettings? = nil,
        link: String? = nil,
        borderRadius: String? = nil,
        backgroundColor: String? = nil,
        headingColor: String? = nil,
        textColor: String? = nil,
        borderColor: String? = nil,
        font: String? = nil,
        selectionControl: SelectionControlType? = nil,
        confirmBeforeSubmit: Bool? = nil,
        theme: AppearanceStyle? = nil,
        surfaceColor: String? = nil,
        mutedTextColor: String? = nil,
        overlayColor: String? = nil,
        toggle: ToggleSettings? = nil,
        ttsHighlight: TTSHighlightSettings? = nil,
        controlStyle: NoticeControlStyle? = nil,
        mobileLayout: NoticeMobileLayout? = nil,
        desktopPosition: NoticeDesktopPosition? = nil,
        backdrop: NoticeBackdrop? = nil,
        collapsibleSections: Bool? = nil,
        phoneFooter: NoticePhoneFooter? = nil,
        autoDark: Bool? = nil,
        darkPalette: ConsentSettingsPalette? = nil,
        maxWidth: String? = nil,
        logoSize: String? = nil,
        textScale: NoticeTextScale? = nil,
        motion: Bool? = nil
    ) {
        self.button = button
        self.link = link
        self.borderRadius = borderRadius
        self.backgroundColor = backgroundColor
        self.headingColor = headingColor
        self.textColor = textColor
        self.borderColor = borderColor
        self.font = font
        self.selectionControlOverride = selectionControl
        self.confirmBeforeSubmitOverride = confirmBeforeSubmit
        self.theme = theme
        self.surfaceColor = surfaceColor
        self.mutedTextColor = mutedTextColor
        self.overlayColor = overlayColor
        self.toggle = toggle
        self.ttsHighlight = ttsHighlight
        self.controlStyle = controlStyle
        self.mobileLayout = mobileLayout
        self.desktopPosition = desktopPosition
        self.backdrop = backdrop
        self.collapsibleSections = collapsibleSections
        self.phoneFooter = phoneFooter
        self.autoDark = autoDark
        self.darkPalette = darkPalette
        self.maxWidth = maxWidth
        self.logoSize = logoSize
        self.textScale = textScale
        self.motion = motion
    }

    /// The colour keys, in the shape `darkPalette` takes.
    var palette: ConsentSettingsPalette {
        ConsentSettingsPalette(
            button: button,
            link: link,
            backgroundColor: backgroundColor,
            surfaceColor: surfaceColor,
            headingColor: headingColor,
            textColor: textColor,
            mutedTextColor: mutedTextColor,
            borderColor: borderColor,
            overlayColor: overlayColor,
            toggle: toggle,
            ttsHighlight: ttsHighlight
        )
    }
}

/// The colours `settings` can set: the top-level palette, and the dark palette
/// under `ConsentSettings.darkPalette`.
public struct ConsentSettingsPalette {
    public var button: ButtonSettings?
    public var link: String?
    public var backgroundColor: String?
    public var surfaceColor: String?
    public var headingColor: String?
    public var textColor: String?
    public var mutedTextColor: String?
    public var borderColor: String?
    public var overlayColor: String?
    public var toggle: ToggleSettings?
    public var ttsHighlight: TTSHighlightSettings?

    public init(
        button: ButtonSettings? = nil,
        link: String? = nil,
        backgroundColor: String? = nil,
        surfaceColor: String? = nil,
        headingColor: String? = nil,
        textColor: String? = nil,
        mutedTextColor: String? = nil,
        borderColor: String? = nil,
        overlayColor: String? = nil,
        toggle: ToggleSettings? = nil,
        ttsHighlight: TTSHighlightSettings? = nil
    ) {
        self.button = button
        self.link = link
        self.backgroundColor = backgroundColor
        self.surfaceColor = surfaceColor
        self.headingColor = headingColor
        self.textColor = textColor
        self.mutedTextColor = mutedTextColor
        self.borderColor = borderColor
        self.overlayColor = overlayColor
        self.toggle = toggle
        self.ttsHighlight = ttsHighlight
    }
}

public struct ButtonSettings {
    /// The brand accent (checkboxes, switches, Accept Selected's outline), and
    /// Accept All's colour when `acceptAll` is unset.
    public var accept: ButtonStyle?
    /// The Accept All button; falls back to `accept`.
    public var acceptAll: ButtonStyle?
    /// The Accept Selected button itself.
    public var acceptSelected: ButtonStyle?
    public var decline: ButtonStyle?
    public var language: LanguageButtonStyle?

    public init(
        accept: ButtonStyle? = nil,
        decline: ButtonStyle? = nil,
        language: LanguageButtonStyle? = nil,
        acceptAll: ButtonStyle? = nil,
        acceptSelected: ButtonStyle? = nil
    ) {
        self.accept = accept
        self.decline = decline
        self.language = language
        self.acceptAll = acceptAll
        self.acceptSelected = acceptSelected
    }
}

/// An empty string leaves that colour unset.
public struct ButtonStyle {
    public var backgroundColor: String
    public var textColor: String
    /// Read for `decline` only.
    public var borderColor: String?

    public init(backgroundColor: String, textColor: String, borderColor: String? = nil) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.borderColor = borderColor
    }
}

public struct LanguageButtonStyle {
    public var backgroundColor: String
    public var textColor: String
    public var selectedBackgroundColor: String?
    public var selectedTextColor: String?

    public init(backgroundColor: String, textColor: String, selectedBackgroundColor: String? = nil, selectedTextColor: String? = nil) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.selectedTextColor = selectedTextColor
    }
}

/// Checkbox and switch states.
public struct ToggleSettings {
    public var onColor: String?
    public var offColor: String?
    public var knobColor: String?

    public init(onColor: String? = nil, offColor: String? = nil, knobColor: String? = nil) {
        self.onColor = onColor
        self.offColor = offColor
        self.knobColor = knobColor
    }
}

public struct TTSHighlightSettings {
    public var backgroundColor: String?
    public var textColor: String?

    public init(backgroundColor: String? = nil, textColor: String? = nil) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
}
