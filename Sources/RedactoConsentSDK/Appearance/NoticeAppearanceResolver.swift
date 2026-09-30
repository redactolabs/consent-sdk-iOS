import SwiftUI

/// What the notice paints with once the served appearance is validated, the
/// host's `settings` are merged over it and the colour scheme is applied.
public struct ResolvedNoticeAppearance: Equatable {
    public var style: AppearanceStyle
    /// Only the colours that were set. The served ones are checked to be hex;
    /// host colours are used as given.
    public var colors: NoticeAppearanceColors
    /// Points; `nil` keeps the style's own radii.
    public var radius: CGFloat?
    /// `nil` means the SDK default, `.checkbox` (see `effectiveSelectionControl`).
    public var selectionControl: SelectionControlType?
    /// `nil` means checkboxes, in every style.
    public var controlStyle: NoticeControlStyle?
    public var confirmBeforeSubmit: Bool
    /// Each layout choice is `nil` when unset, so the style's default applies.
    public var mobileLayout: NoticeMobileLayout?
    public var desktopPosition: NoticeDesktopPosition?
    public var backdrop: NoticeBackdrop?
    public var collapsibleSections: Bool?
    public var phoneFooter: NoticePhoneFooter?
    /// Swap in `darkColors` while the device prefers a dark scheme.
    public var autoDark: Bool
    public var darkColors: NoticeAppearanceColors
    /// Card width on wider screens, in points.
    public var maxWidth: CGFloat?
    /// Logo height, in points.
    public var logoSize: CGFloat?
    public var textScale: NoticeTextScale?
    public var motion: Bool?

    public init(
        style: AppearanceStyle = NoticeAppearanceDefaults.style,
        colors: NoticeAppearanceColors = [:],
        radius: CGFloat? = nil,
        selectionControl: SelectionControlType? = nil,
        controlStyle: NoticeControlStyle? = nil,
        confirmBeforeSubmit: Bool = false,
        mobileLayout: NoticeMobileLayout? = nil,
        desktopPosition: NoticeDesktopPosition? = nil,
        backdrop: NoticeBackdrop? = nil,
        collapsibleSections: Bool? = nil,
        phoneFooter: NoticePhoneFooter? = nil,
        autoDark: Bool = false,
        darkColors: NoticeAppearanceColors = [:],
        maxWidth: CGFloat? = nil,
        logoSize: CGFloat? = nil,
        textScale: NoticeTextScale? = nil,
        motion: Bool? = nil
    ) {
        self.style = style
        self.colors = colors
        self.radius = radius
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
    }

    // MARK: - Derived values

    /// The notice's layout: each choice the console or the host made, else the
    /// style's own default (glass docks as a sheet with collapsible sections and
    /// a paired footer; the other styles keep classic's layout). Every style
    /// keeps checkboxes until switches are asked for.
    public var layout: ResolvedNoticeLayout {
        let defaults = style.layout
        return ResolvedNoticeLayout(
            mobileSheet: mobileLayout.map { $0 == .sheet } ?? defaults.sheet,
            desktopPosition: desktopPosition ?? NoticeAppearanceDefaults.desktopPosition,
            dimBackdrop: backdrop != NoticeBackdrop.none,
            collapsibleSections: collapsibleSections ?? defaults.collapsibleSections,
            pairedFooter: phoneFooter.map { $0 == .paired } ?? defaults.pairedFooter,
            switchControl: controlStyle.map { $0 == .switch } ?? defaults.switchControl,
            motion: motion ?? true
        )
    }

    public var effectiveSelectionControl: SelectionControlType {
        selectionControl ?? NoticeAppearanceDefaults.selectionControl
    }

    public var textScaleFactor: CGFloat {
        (textScale ?? NoticeAppearanceDefaults.textScale).factor
    }

    /// A text size times `textScaleFactor`, kept to one decimal place.
    public func scaled(_ size: CGFloat) -> CGFloat {
        (size * textScaleFactor * 10).rounded() / 10
    }

    /// The card's radius: the set radius, else the style's.
    public var modalRadius: CGFloat { radius ?? style.radii.modal }
    /// The footer buttons' radius: the set radius, else the style's.
    public var buttonRadius: CGFloat { radius ?? style.radii.button }

    /// The brand accent (checkbox and switch fill, Accept Selected's outline,
    /// focus rings): `toggle_on`, then `accept_all_bg`, then the notice's
    /// `primary_color`, then the SDK default.
    public func accentColor(primaryColor: String?) -> String {
        colors[.toggleOn]
            ?? colors[.acceptAllBg]
            ?? primaryColor.flatMap { $0.isEmpty ? nil : $0 }
            ?? NoticeAppearanceDefaults.accentColor
    }

    /// The talkback highlight; its text colour, when `nil`, is each element's own.
    public var ttsHighlightBackground: String {
        colors[.ttsHighlightBg] ?? NoticeAppearanceDefaults.ttsHighlightBackground
    }

    public func logoHeight(isPhone: Bool) -> CGFloat {
        logoSize ?? (isPhone ? NoticeAppearanceDefaults.phoneLogoHeight : NoticeAppearanceDefaults.logoHeight)
    }

    public func logoMaxWidth(isPhone: Bool) -> CGFloat {
        logoHeight(isPhone: isPhone) * NoticeAppearanceDefaults.logoWidthRatio
    }

    /// A set colour as a SwiftUI colour; `nil` when unset or unpaintable.
    public func color(_ key: NoticeColorKey) -> Color? {
        AppearanceColor.color(colors[key])
    }
}

extension NoticeAppearance {
    /// The one entry point the notice screens call: the served appearance under
    /// the host's `settings` (which win key by key), painted with the dark
    /// palette when the scheme is dark and the appearance asks for automatic
    /// dark mode.
    ///
    /// Before the notice arrives, pass the last appearance served for it (or
    /// `nil`, which is classic).
    public static func resolve(
        console: NoticeAppearance?,
        settings: ConsentSettings?,
        colorScheme: ColorScheme
    ) -> ResolvedNoticeAppearance {
        NoticeAppearanceResolver.withColorScheme(
            NoticeAppearanceResolver.merge(NoticeAppearanceResolver.resolve(console), settings: settings),
            prefersDark: colorScheme == .dark
        )
    }
}

/// The three steps behind `NoticeAppearance.resolve`, ported from the React
/// SDK's `resolveNoticeAppearance`, `mergeHostSettings` and `withColorScheme`.
enum NoticeAppearanceResolver {
    /// Validates the served appearance. The server already normalises it, but an
    /// older ledger row, a proxy or a hand edit can still serve junk, and a
    /// notice must render whatever arrives: anything unrecognised is dropped, and
    /// a missing value leaves the classic default.
    static func resolve(_ served: NoticeAppearance?) -> ResolvedNoticeAppearance {
        guard let served else { return ResolvedNoticeAppearance() }
        return ResolvedNoticeAppearance(
            style: option(served.style) ?? NoticeAppearanceDefaults.style,
            colors: pickColors(served.colors),
            radius: pickPoints(served.borderRadius, NoticeAppearanceDefaults.radiusRange),
            selectionControl: option(served.selectionControl),
            controlStyle: option(served.controlStyle),
            confirmBeforeSubmit: served.confirmBeforeSubmit == true,
            mobileLayout: option(served.mobileLayout),
            desktopPosition: option(served.desktopPosition),
            backdrop: option(served.backdrop),
            collapsibleSections: served.collapsibleSections,
            phoneFooter: option(served.phoneFooter),
            autoDark: served.autoDark == true,
            darkColors: pickColors(served.darkColors),
            maxWidth: pickPoints(served.maxWidth, NoticeAppearanceDefaults.widthRange),
            logoSize: pickPoints(served.logoSize, NoticeAppearanceDefaults.logoSizeRange),
            textScale: option(served.textScale),
            motion: served.motion
        )
    }

    /// Host `settings` over the console appearance, key by key: whatever the
    /// integrator sets in code wins, and everything they leave unset keeps the
    /// console's value. `settings.darkPalette` merges over the console's dark
    /// palette the same way.
    ///
    /// `button.accept` keeps the meaning it has always had: the brand accent,
    /// and Accept All's colour when `acceptAll` is unset.
    static func merge(_ resolved: ResolvedNoticeAppearance, settings: ConsentSettings?) -> ResolvedNoticeAppearance {
        guard let settings else { return resolved }
        var merged = resolved
        merged.style = settings.theme ?? resolved.style
        merged.colors = resolved.colors.merging(hostColors(settings.palette)) { _, host in host }
        merged.radius = length(settings.borderRadius) ?? resolved.radius
        merged.selectionControl = settings.selectionControlOverride ?? resolved.selectionControl
        merged.controlStyle = settings.controlStyle ?? resolved.controlStyle
        merged.confirmBeforeSubmit = settings.confirmBeforeSubmitOverride ?? resolved.confirmBeforeSubmit
        merged.mobileLayout = settings.mobileLayout ?? resolved.mobileLayout
        merged.desktopPosition = settings.desktopPosition ?? resolved.desktopPosition
        merged.backdrop = settings.backdrop ?? resolved.backdrop
        merged.collapsibleSections = settings.collapsibleSections ?? resolved.collapsibleSections
        merged.phoneFooter = settings.phoneFooter ?? resolved.phoneFooter
        merged.autoDark = settings.autoDark ?? resolved.autoDark
        merged.darkColors = resolved.darkColors.merging(hostColors(settings.darkPalette)) { _, host in host }
        merged.maxWidth = length(settings.maxWidth) ?? resolved.maxWidth
        merged.logoSize = length(settings.logoSize) ?? resolved.logoSize
        merged.textScale = settings.textScale ?? resolved.textScale
        merged.motion = settings.motion ?? resolved.motion
        return merged
    }

    /// The palette to paint with: the dark one while the device prefers a dark
    /// scheme and automatic dark mode is on with a dark palette set. The dark
    /// palette replaces the light one whole, so a light colour never leaks onto
    /// a dark surface.
    static func withColorScheme(_ appearance: ResolvedNoticeAppearance, prefersDark: Bool) -> ResolvedNoticeAppearance {
        guard appearance.autoDark, prefersDark, !appearance.darkColors.isEmpty else {
            return appearance
        }
        var dark = appearance
        dark.colors = appearance.darkColors
        return dark
    }

    /// A host palette in the console's colour keys; unset (or empty) colours are
    /// dropped, so a host value only replaces a console value it names.
    static func hostColors(_ palette: ConsentSettingsPalette?) -> NoticeAppearanceColors {
        guard let palette else { return [:] }
        let button = palette.button
        let entries: [(NoticeColorKey, String?)] = [
            (.background, palette.backgroundColor),
            (.surface, palette.surfaceColor),
            (.heading, palette.headingColor),
            (.text, palette.textColor),
            (.mutedText, palette.mutedTextColor),
            (.link, palette.link),
            (.border, palette.borderColor),
            (.overlay, palette.overlayColor),
            (.acceptAllBg, set(button?.acceptAll?.backgroundColor) ?? set(button?.accept?.backgroundColor)),
            (.acceptAllText, set(button?.acceptAll?.textColor) ?? set(button?.accept?.textColor)),
            (.acceptBg, button?.acceptSelected?.backgroundColor),
            (.acceptText, button?.acceptSelected?.textColor),
            (.declineBg, button?.decline?.backgroundColor),
            (.declineText, button?.decline?.textColor),
            (.declineBorder, button?.decline?.borderColor),
            (.languageBg, button?.language?.backgroundColor),
            (.languageText, button?.language?.textColor),
            (.languageSelectedBg, button?.language?.selectedBackgroundColor),
            (.languageSelectedText, button?.language?.selectedTextColor),
            (.toggleOn, set(palette.toggle?.onColor) ?? set(button?.accept?.backgroundColor)),
            (.toggleOff, palette.toggle?.offColor),
            (.toggleKnob, palette.toggle?.knobColor),
            (.ttsHighlightBg, palette.ttsHighlight?.backgroundColor),
            (.ttsHighlightText, palette.ttsHighlight?.textColor),
        ]
        var colors: NoticeAppearanceColors = [:]
        for (key, value) in entries {
            if let value = set(value) {
                colors[key] = value
            }
        }
        return colors
    }

    /// A host length in points: `"12"`, `"12px"` or `"12pt"`. Anything else
    /// (`"1rem"`, `"50%"`) has no native meaning and reads as unset.
    static func length(_ raw: String?) -> CGFloat? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else {
            return nil
        }
        if value.hasSuffix("px") || value.hasSuffix("pt") {
            value.removeLast(2)
        }
        guard let number = Double(value.trimmingCharacters(in: .whitespaces)), number.isFinite else {
            return nil
        }
        return CGFloat(number)
    }

    // MARK: - Private

    private static func set(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func option<T: RawRepresentable>(_ raw: String?) -> T? where T.RawValue == String {
        raw.flatMap(T.init(rawValue:))
    }

    private static func pickColors(_ raw: [String: String]?) -> NoticeAppearanceColors {
        guard let raw else { return [:] }
        var colors: NoticeAppearanceColors = [:]
        for key in NoticeColorKey.allCases {
            if let value = raw[key.rawValue], AppearanceColor.isServedHex(value) {
                colors[key] = value
            }
        }
        return colors
    }

    /// A number clamped into range; anything non-finite is unset. Rounds half
    /// up, as JavaScript's `Math.round` does.
    private static func pickPoints(_ raw: Double?, _ range: ClosedRange<Double>) -> CGFloat? {
        guard let raw, raw.isFinite else { return nil }
        let rounded = (raw + 0.5).rounded(.down)
        return CGFloat(min(range.upperBound, max(range.lowerBound, rounded)))
    }
}
