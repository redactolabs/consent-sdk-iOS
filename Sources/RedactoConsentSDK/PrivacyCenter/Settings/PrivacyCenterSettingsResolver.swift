import Foundation

/// The settings the Privacy Center renders with (React `resolve.ts`): the
/// published payload, or nothing when none was fetched, validated field by
/// field, with the host's overrides merged over each group. Anything missing or
/// malformed takes the default, so a bad payload can never break the centre or
/// change it from its built-in look by accident.
enum PrivacyCenterSettingsResolver {
    typealias Record = [String: PCJSONValue]

    private static let defaults = ResolvedPrivacyCenterSettings.defaults
    private static let hexColor = try! NSRegularExpression(pattern: "^#[0-9A-Fa-f]{6}$")
    private static let httpsUrlPattern = try! NSRegularExpression(
        pattern: #"^https://[^\s"'<>()\\]+$"#,
        options: [.caseInsensitive]
    )
    private static let emailPattern = try! NSRegularExpression(pattern: #"^[^\s@<>()"]+@[^\s@<>()"]+\.[^\s@<>()"]+$"#)

    static func resolve(published: PCJSONValue?, overrides: PrivacyCenterSettings? = nil) -> ResolvedPrivacyCenterSettings {
        let source = published?.objectValue ?? [:]
        let host = overrides.map(PrivacyCenterSettingsOverrides.groups) ?? [:]
        return ResolvedPrivacyCenterSettings(
            branding: branding(merge(source["branding"], host["branding"])),
            signIn: signIn(merge(source["sign_in"], host["sign_in"])),
            portal: portal(merge(source["portal"], host["portal"])),
            languages: languages(merge(source["languages"], host["languages"])),
            footer: footer(merge(source["footer"], host["footer"]))
        )
    }

    /// The opt-in Brand Identity details, each checked like its field.
    static func brandContact(_ raw: PCJSONValue?) -> PrivacyCenterBrandContact {
        let source = raw?.objectValue ?? [:]
        let email = nullableText(source["grievance_email"], fallback: nil)
        return PrivacyCenterBrandContact(
            legalEntityName: nullableText(source["legal_entity_name"], fallback: nil),
            privacyPolicyUrl: httpsUrl(source["privacy_policy_url"]),
            grievanceEmail: email.flatMap { matches(emailPattern, $0) ? $0 : nil },
            grievanceUrl: httpsUrl(source["grievance_url"]),
            dpBoardUrl: httpsUrl(source["dp_board_url"])
        )
    }

    /// One published group with the host's overrides for it laid over.
    static func merge(_ published: PCJSONValue?, _ override: Record?) -> Record {
        (published?.objectValue ?? [:]).merging(override ?? [:]) { _, host in host }
    }

    // MARK: - Groups

    private static func branding(_ raw: Record) -> PrivacyCenterBrandingSettings {
        let base = defaults.branding
        let font = raw["font_family"]
        let style: AppearanceStyle
        if let rawStyle = raw["style"] {
            style = rawStyle.stringValue.flatMap(AppearanceStyle.init(rawValue:)) == .glass ? .glass : .classic
        } else {
            style = base.style
        }
        return PrivacyCenterBrandingSettings(
            inheritIdentity: bool(raw["inherit_identity"], fallback: base.inheritIdentity),
            displayName: nullableText(raw["display_name"], fallback: base.displayName),
            logoUrl: nullableUrl(raw["logo_url"], fallback: base.logoUrl),
            logoHeight: clampedInt(raw["logo_height"], PrivacyCenterSettingsLimits.logoHeight, fallback: base.logoHeight),
            inheritColors: bool(raw["inherit_colors"], fallback: base.inheritColors),
            primaryColor: hex(raw["primary_color"], fallback: base.primaryColor),
            accentColor: hex(raw["accent_color"], fallback: base.accentColor),
            inheritFont: bool(raw["inherit_font"], fallback: base.inheritFont),
            fontFamily: font?.isNull == true
                ? nil
                : PrivacyCenterSettingsLimits.fontFamilies.first { $0 == font?.stringValue } ?? base.fontFamily,
            style: style,
            cornerRadius: clampedInt(raw["corner_radius"], PrivacyCenterSettingsLimits.cornerRadius, fallback: base.cornerRadius)
        )
    }

    private static func signIn(_ raw: Record) -> PrivacyCenterSignInSettings {
        let base = defaults.signIn
        return PrivacyCenterSignInSettings(
            layout: option(raw["layout"], fallback: base.layout),
            align: option(raw["align"], fallback: base.align),
            backgroundType: option(raw["background_type"], fallback: base.backgroundType),
            backgroundFrom: hex(raw["background_from"], fallback: base.backgroundFrom) ?? base.backgroundFrom,
            backgroundTo: hex(raw["background_to"], fallback: base.backgroundTo) ?? base.backgroundTo,
            backgroundColor: hex(raw["background_color"], fallback: base.backgroundColor) ?? base.backgroundColor,
            backgroundImageUrl: nullableUrl(raw["background_image_url"], fallback: base.backgroundImageUrl),
            highlights: raw["highlights"].map { stringList($0, max: PrivacyCenterSettingsLimits.maxHighlights) } ?? base.highlights,
            showLogo: bool(raw["show_logo"], fallback: base.showLogo),
            title: text(raw["title"], fallback: base.title),
            tagline: nullableText(raw["tagline"], fallback: base.tagline),
            heading: text(raw["heading"], fallback: base.heading),
            description: nullableText(raw["description"], fallback: base.description),
            channels: option(raw["channels"], fallback: base.channels),
            defaultCountryCode: PrivacyCenterSettingsLimits.countryCodes.first { $0 == raw["default_country_code"]?.stringValue }
                ?? base.defaultCountryCode,
            fieldLabel: nullableText(raw["field_label"], fallback: base.fieldLabel),
            placeholder: nullableText(raw["placeholder"], fallback: base.placeholder),
            helpText: nullableText(raw["help_text"], fallback: base.helpText),
            buttonText: text(raw["button_text"], fallback: base.buttonText),
            showNoticeLine: bool(raw["show_notice_line"], fallback: base.showNoticeLine),
            noticeLine: nullableText(raw["notice_line"], fallback: base.noticeLine),
            showSupportLink: bool(raw["show_support_link"], fallback: base.showSupportLink),
            supportText: text(raw["support_text"], fallback: base.supportText),
            supportLinkText: text(raw["support_link_text"], fallback: base.supportLinkText),
            otpHeading: text(raw["otp_heading"], fallback: base.otpHeading),
            otpDescription: nullableText(raw["otp_description"], fallback: base.otpDescription),
            otpButtonText: text(raw["otp_button_text"], fallback: base.otpButtonText),
            otpResendText: text(raw["otp_resend_text"], fallback: base.otpResendText)
        )
    }

    private static func portal(_ raw: Record) -> PrivacyCenterPortalSettings {
        let base = defaults.portal
        let revoke = raw["revoke_consents_on_erasure"]
        let sections = orderedToggles(raw["sections"], keys: PrivacyCenterSectionKey.allCases) { key, label, enabled in
            PrivacyCenterSection(key: key, label: label, enabled: enabled)
        }
        let requestTypes = orderedToggles(raw["request_types"], keys: PrivacyCenterRequestTypeKey.allCases) { key, label, enabled in
            PrivacyCenterRequestTypeSetting(key: key, label: label, enabled: enabled)
        }
        return PrivacyCenterPortalSettings(
            sections: sections.flatMap { $0.contains(where: \.enabled) ? $0 : nil } ?? base.sections,
            welcomeEnabled: bool(raw["welcome_enabled"], fallback: base.welcomeEnabled),
            welcomeTitle: text(raw["welcome_title"], fallback: base.welcomeTitle),
            welcomeMessage: text(raw["welcome_message"], fallback: base.welcomeMessage),
            requestTypes: requestTypes.flatMap { $0.contains(where: \.enabled) ? $0 : nil } ?? base.requestTypes,
            grievanceCategories: grievanceCategories(raw["grievance_categories"]) ?? base.grievanceCategories,
            revokeConsentsOnErasure: revoke?.boolValue ?? (revoke?.isNull == true ? nil : base.revokeConsentsOnErasure),
            withdrawWarning: nullableText(raw["withdraw_warning"], fallback: base.withdrawWarning),
            sessionTimeoutMinutes: sessionTimeout(raw["session_timeout_minutes"], fallback: base.sessionTimeoutMinutes)
        )
    }

    private static func languages(_ raw: Record) -> PrivacyCenterLanguageSettings {
        let base = defaults.languages
        var enabled = base.enabled
        if let listed = raw["enabled"]?.arrayValue {
            let codes = Set(listed.compactMap(\.stringValue))
            enabled = PrivacyCenterSettingsLimits.languageCodes.filter(codes.contains)
        }
        if enabled.isEmpty {
            enabled = base.enabled
        }
        let requested = raw["default"]?.stringValue ?? base.defaultLanguage
        return PrivacyCenterLanguageSettings(
            enabled: enabled,
            defaultLanguage: enabled.contains(requested) ? requested : enabled[0],
            autoDetect: bool(raw["auto_detect"], fallback: base.autoDetect),
            showSwitcher: bool(raw["show_switcher"], fallback: base.showSwitcher)
        )
    }

    private static func footer(_ raw: Record) -> PrivacyCenterFooterSettings {
        let base = defaults.footer
        var links = base.links
        if let listed = raw["links"]?.arrayValue {
            links = listed.compactMap { entry -> PrivacyCenterFooterLink? in
                let record = entry.objectValue ?? [:]
                guard let label = nullableText(record["label"], fallback: nil),
                      let url = httpsUrl(record["url"]) else { return nil }
                return PrivacyCenterFooterLink(label: label, url: url)
            }
            links = Array(links.prefix(PrivacyCenterSettingsLimits.maxFooterLinks))
        }
        return PrivacyCenterFooterSettings(
            links: links,
            showPrivacyPolicy: bool(raw["show_privacy_policy"], fallback: base.showPrivacyPolicy),
            showContact: bool(raw["show_contact"], fallback: base.showContact),
            copyright: nullableText(raw["copyright"], fallback: base.copyright),
            showPoweredBy: bool(raw["show_powered_by"], fallback: base.showPoweredBy)
        )
    }

    // MARK: - Fields

    private static func bool(_ raw: PCJSONValue?, fallback: Bool) -> Bool {
        raw?.boolValue ?? fallback
    }

    /// A trimmed, non-empty string, or the fallback.
    private static func text(_ raw: PCJSONValue?, fallback: String) -> String {
        guard let value = raw?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    /// A trimmed string; empty or an explicit null means "use the built-in".
    static func nullableText(_ raw: PCJSONValue?, fallback: String?) -> String? {
        guard let raw else { return fallback }
        if raw.isNull { return nil }
        guard let value = raw.stringValue else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func option<T: RawRepresentable>(_ raw: PCJSONValue?, fallback: T) -> T where T.RawValue == String {
        raw?.stringValue.flatMap(T.init(rawValue:)) ?? fallback
    }

    private static func hex(_ raw: PCJSONValue?, fallback: String?) -> String? {
        guard let raw else { return fallback }
        if raw.isNull { return nil }
        guard let value = raw.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), matches(hexColor, value) else {
            return fallback
        }
        return value
    }

    static func httpsUrl(_ raw: PCJSONValue?) -> String? {
        guard let value = raw?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.count <= PrivacyCenterSettingsLimits.maxUrlLength,
              matches(httpsUrlPattern, value) else { return nil }
        return value
    }

    private static func nullableUrl(_ raw: PCJSONValue?, fallback: String?) -> String? {
        guard let raw else { return fallback }
        if raw.isNull || raw.stringValue == "" { return nil }
        return httpsUrl(raw)
    }

    private static func clampedInt(_ raw: PCJSONValue?, _ range: ClosedRange<Int>, fallback: Int?) -> Int? {
        guard let raw else { return fallback }
        if raw.isNull { return nil }
        guard let number = raw.numberValue, number.isFinite else { return fallback }
        // Clamped as a Double first: `Int(_:)` traps on a value out of range.
        return Int(min(Double(range.upperBound), max(Double(range.lowerBound), number.rounded())))
    }

    private static func sessionTimeout(_ raw: PCJSONValue?, fallback: Int?) -> Int? {
        guard let raw else { return fallback }
        if raw.isNull { return nil }
        guard let number = raw.numberValue, number.isFinite, number > 0 else { return fallback }
        // Under half a minute rounds to 0, which leaves the timer off.
        return Int(min(Double(PrivacyCenterSettingsLimits.sessionTimeoutMaxMinutes), number.rounded()))
    }

    private static func stringList(_ raw: PCJSONValue, max: Int) -> [String] {
        let items = (raw.arrayValue ?? [])
            .compactMap(\.stringValue)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(items.prefix(max))
    }

    private static func grievanceCategories(_ raw: PCJSONValue?) -> [GrievanceType]? {
        guard let listed = raw?.arrayValue else { return nil }
        let values = Set(listed.compactMap(\.stringValue))
        let picked = GrievanceType.allCases.filter { values.contains($0.rawValue) }
        return picked.isEmpty ? nil : picked
    }

    /// Each known key once, in the order given, then any key the payload left
    /// out with its default, so a payload from an older or newer console still
    /// renders every section. Nil when the payload sent no list.
    private static func orderedToggles<Key: RawRepresentable & CaseIterable & Hashable, Item>(
        _ raw: PCJSONValue?,
        keys: Key.AllCases,
        make: (Key, String?, Bool) -> Item
    ) -> [Item]? where Key.RawValue == String {
        guard let listed = raw?.arrayValue else { return nil }
        var seen: Set<Key> = []
        var items: [Item] = []
        for entry in listed {
            let record = entry.objectValue ?? [:]
            guard let key = record["key"]?.stringValue.flatMap(Key.init(rawValue:)), !seen.contains(key) else { continue }
            seen.insert(key)
            items.append(make(key, nullableText(record["label"], fallback: nil), bool(record["enabled"], fallback: true)))
        }
        for key in keys where !seen.contains(key) {
            items.append(make(key, nil, true))
        }
        return items
    }

    private static func matches(_ pattern: NSRegularExpression, _ value: String) -> Bool {
        pattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}

/// The host's typed overrides as the published payload's groups, so both run
/// through the same validation.
enum PrivacyCenterSettingsOverrides {
    static func groups(_ settings: PrivacyCenterSettings) -> [String: PrivacyCenterSettingsResolver.Record] {
        var groups: [String: PrivacyCenterSettingsResolver.Record] = [:]
        var branding = settings.branding.map(brandingRecord) ?? [:]
        if branding["style"] == nil, let theme = settings.theme {
            branding["style"] = .string(theme)
        }
        if !branding.isEmpty { groups["branding"] = branding }
        if let signIn = settings.signIn { groups["sign_in"] = signInRecord(signIn) }
        if let portal = settings.portal { groups["portal"] = portalRecord(portal) }
        if let languages = settings.languages { groups["languages"] = languagesRecord(languages) }
        if let footer = settings.footer { groups["footer"] = footerRecord(footer) }
        return groups
    }

    private static func put(_ record: inout PrivacyCenterSettingsResolver.Record, _ key: String, _ value: String?) {
        if let value { record[key] = .string(value) }
    }

    private static func put(_ record: inout PrivacyCenterSettingsResolver.Record, _ key: String, _ value: Bool?) {
        if let value { record[key] = .bool(value) }
    }

    private static func put(_ record: inout PrivacyCenterSettingsResolver.Record, _ key: String, _ value: Int?) {
        if let value { record[key] = .number(Double(value)) }
    }

    /// A double optional: nil keeps the published value, `.some(nil)` clears it.
    private static func put(_ record: inout PrivacyCenterSettingsResolver.Record, _ key: String, nullable value: Int??) {
        guard let value else { return }
        record[key] = value.map { .number(Double($0)) } ?? .null
    }

    private static func brandingRecord(_ branding: PrivacyCenterSettings.Branding) -> PrivacyCenterSettingsResolver.Record {
        var record: PrivacyCenterSettingsResolver.Record = [:]
        put(&record, "inherit_identity", branding.inheritIdentity)
        put(&record, "display_name", branding.displayName)
        put(&record, "logo_url", branding.logoUrl)
        put(&record, "logo_height", nullable: branding.logoHeight)
        put(&record, "inherit_colors", branding.inheritColors)
        put(&record, "primary_color", branding.primaryColor)
        put(&record, "accent_color", branding.accentColor)
        put(&record, "inherit_font", branding.inheritFont)
        put(&record, "font_family", branding.fontFamily)
        put(&record, "style", branding.style)
        put(&record, "corner_radius", nullable: branding.cornerRadius)
        return record
    }

    private static func signInRecord(_ signIn: PrivacyCenterSettings.SignIn) -> PrivacyCenterSettingsResolver.Record {
        var record: PrivacyCenterSettingsResolver.Record = [:]
        put(&record, "layout", signIn.layout?.rawValue)
        put(&record, "align", signIn.align?.rawValue)
        put(&record, "background_type", signIn.backgroundType?.rawValue)
        put(&record, "background_from", signIn.backgroundFrom)
        put(&record, "background_to", signIn.backgroundTo)
        put(&record, "background_color", signIn.backgroundColor)
        put(&record, "background_image_url", signIn.backgroundImageUrl)
        if let highlights = signIn.highlights {
            record["highlights"] = .array(highlights.map(PCJSONValue.string))
        }
        put(&record, "show_logo", signIn.showLogo)
        put(&record, "title", signIn.title)
        put(&record, "tagline", signIn.tagline)
        put(&record, "heading", signIn.heading)
        put(&record, "description", signIn.description)
        put(&record, "channels", signIn.channels?.rawValue)
        put(&record, "default_country_code", signIn.defaultCountryCode)
        put(&record, "field_label", signIn.fieldLabel)
        put(&record, "placeholder", signIn.placeholder)
        put(&record, "help_text", signIn.helpText)
        put(&record, "button_text", signIn.buttonText)
        put(&record, "show_notice_line", signIn.showNoticeLine)
        put(&record, "notice_line", signIn.noticeLine)
        put(&record, "show_support_link", signIn.showSupportLink)
        put(&record, "support_text", signIn.supportText)
        put(&record, "support_link_text", signIn.supportLinkText)
        put(&record, "otp_heading", signIn.otpHeading)
        put(&record, "otp_description", signIn.otpDescription)
        put(&record, "otp_button_text", signIn.otpButtonText)
        put(&record, "otp_resend_text", signIn.otpResendText)
        return record
    }

    private static func toggle(_ key: String, _ label: String?, _ enabled: Bool) -> PCJSONValue {
        .object(["key": .string(key), "label": label.map(PCJSONValue.string) ?? .null, "enabled": .bool(enabled)])
    }

    private static func portalRecord(_ portal: PrivacyCenterSettings.Portal) -> PrivacyCenterSettingsResolver.Record {
        var record: PrivacyCenterSettingsResolver.Record = [:]
        if let sections = portal.sections {
            record["sections"] = .array(sections.map { toggle($0.key.rawValue, $0.label, $0.enabled) })
        }
        put(&record, "welcome_enabled", portal.welcomeEnabled)
        put(&record, "welcome_title", portal.welcomeTitle)
        put(&record, "welcome_message", portal.welcomeMessage)
        if let types = portal.requestTypes {
            record["request_types"] = .array(types.map { toggle($0.key.rawValue, $0.label, $0.enabled) })
        }
        if let categories = portal.grievanceCategories {
            record["grievance_categories"] = .array(categories.map { .string($0.rawValue) })
        }
        if let revoke = portal.revokeConsentsOnErasure {
            record["revoke_consents_on_erasure"] = revoke.map(PCJSONValue.bool) ?? .null
        }
        put(&record, "withdraw_warning", portal.withdrawWarning)
        put(&record, "session_timeout_minutes", nullable: portal.sessionTimeoutMinutes)
        return record
    }

    private static func languagesRecord(_ languages: PrivacyCenterSettings.Languages) -> PrivacyCenterSettingsResolver.Record {
        var record: PrivacyCenterSettingsResolver.Record = [:]
        if let enabled = languages.enabled {
            record["enabled"] = .array(enabled.map(PCJSONValue.string))
        }
        put(&record, "default", languages.defaultLanguage)
        put(&record, "auto_detect", languages.autoDetect)
        put(&record, "show_switcher", languages.showSwitcher)
        return record
    }

    private static func footerRecord(_ footer: PrivacyCenterSettings.Footer) -> PrivacyCenterSettingsResolver.Record {
        var record: PrivacyCenterSettingsResolver.Record = [:]
        if let links = footer.links {
            record["links"] = .array(links.map { .object(["label": .string($0.label), "url": .string($0.url)]) })
        }
        put(&record, "show_privacy_policy", footer.showPrivacyPolicy)
        put(&record, "show_contact", footer.showContact)
        put(&record, "copyright", footer.copyright)
        put(&record, "show_powered_by", footer.showPoweredBy)
        return record
    }
}
