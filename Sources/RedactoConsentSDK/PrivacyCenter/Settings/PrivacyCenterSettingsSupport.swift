import Foundation

/// Which language the Privacy Center shows, and which way it reads (React
/// `settings/languages.ts`).
enum PrivacyCenterLanguagePolicy {
    static func isRightToLeft(_ code: String?) -> Bool {
        guard let code else { return false }
        return PrivacyCenterSettingsLimits.rtlLanguages.contains(code)
    }

    /// A language the visitor picked wins while it stays enabled; otherwise the
    /// current language is kept when detection is on and it is enabled;
    /// otherwise the configured default. A disabled language is never returned.
    static func pick(current: String?, languages: PrivacyCenterLanguageSettings, userChoice: String?) -> String {
        if let userChoice, languages.enabled.contains(userChoice) {
            return userChoice
        }
        if languages.autoDetect, let current, languages.enabled.contains(current) {
            return current
        }
        return languages.defaultLanguage
    }

    /// The settings endpoint only localises into the languages the SDK ships.
    static func requestLanguage(_ language: String) -> String {
        PrivacyCenterSettingsLimits.languageCodes.contains(language) ? language : "en"
    }
}

/// What the `{brand}`-style tokens in custom copy resolve to.
struct PrivacyCenterPlaceholderContext: Equatable {
    var brand: String
    var legal: String?
    var year: Int?
    var contact: String?
    var name: String?
}

enum PrivacyCenterCopy {
    private static let placeholder = try! NSRegularExpression(pattern: #"\{(brand|legal|year|contact|name)\}"#)
    private static let cleanups: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: "[ \\t]{2,}"), " "),
        (try! NSRegularExpression(pattern: #"\s+([,.!?;:])"#), "$1"),
        (try! NSRegularExpression(pattern: "[,;:]+([,.!?;:])"), "$1"),
        (try! NSRegularExpression(pattern: #"^[\s,;:]+"#), ""),
    ]

    /// Built-in English copy mapped to its string key, so a default the console
    /// never changed reads in the visitor's language rather than in English.
    static let defaultCopyKeys: [String: String] = [
        "{brand} Privacy Center": "signInTitle",
        "Your rights over your data, simplified": "yourRightsOverDataSimplified",
        "Let's confirm it's you": "signInHeading",
        "Sign in with your mobile number or email to access your privacy centre.": "signInDescription",
        "Send OTP": "signInButton",
        "Trouble signing in?": "signInSupportText",
        "Contact support": "signInSupportLink",
        "OTP Verification": "otpHeading",
        "Verify OTP": "otpVerifyButton",
        "Resend OTP": "otpResend",
        "Welcome to the {brand} Privacy Center": "welcomeTitleDefault",
        "See every consent you have given and change any of it whenever you like.": "welcomeMessageDefault",
    ]

    /// Fills `{brand}`, `{legal}`, `{year}`, `{contact}` and `{name}`. `{legal}`
    /// falls back to the brand, and an unknown value collapses cleanly:
    /// "Welcome back, {name}!" reads "Welcome back!".
    static func fillPlaceholders(_ text: String?, _ context: PrivacyCenterPlaceholderContext, now: Date = Date()) -> String {
        guard let text, !text.isEmpty else { return "" }
        let year = context.year ?? Calendar(identifier: .gregorian).component(.year, from: now)
        let values: [String: String] = [
            "brand": context.brand,
            "legal": context.legal.flatMap { $0.isEmpty ? nil : $0 } ?? context.brand,
            "year": String(year),
            "contact": context.contact ?? "",
            "name": context.name ?? "",
        ]
        var result = ""
        var cursor = text.startIndex
        for match in placeholder.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let token = Range(match.range(at: 1), in: text) else { continue }
            result += text[cursor..<whole.lowerBound]
            result += values[String(text[token])] ?? ""
            cursor = whole.upperBound
        }
        result += text[cursor...]
        for (pattern, template) in cleanups {
            result = pattern.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A piece of settings copy as shown: an unchanged built-in default through
    /// the translated strings, then its placeholders filled.
    static func render(
        _ value: String?,
        _ context: PrivacyCenterPlaceholderContext,
        translate: (String) -> String? = PrivacyCenterCopy.translated
    ) -> String {
        guard let value, !value.isEmpty else { return "" }
        let localised = defaultCopyKeys[value].flatMap(translate) ?? value
        return fillPlaceholders(localised, context)
    }

    /// The Privacy Center string for a key, or nil when no bundle carries it.
    static func translated(_ key: String) -> String? {
        let value = PCStrings.t(key)
        return value == key ? nil : value
    }

    /// The data principal's first name when the token carries one. The session
    /// token today holds only contact identifiers, so `{name}` usually
    /// collapses out of the copy.
    static func principalFirstName(_ claims: [String: Any]?) -> String? {
        func firstWord(_ value: Any?) -> String? {
            guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return nil
            }
            return text.split(whereSeparator: \.isWhitespace).first.map(String.init)
        }
        let userData = claims?["user_data"] as? [String: Any]
        return firstWord(userData?["first_name"])
            ?? firstWord(userData?["given_name"])
            ?? firstWord(userData?["name"])
            ?? firstWord(claims?["given_name"])
            ?? firstWord(claims?["name"])
    }
}

/// The request types and grievance categories the form offers (React
/// `settings/requests.ts`).
enum PrivacyCenterRequestOptions {
    struct Option: Equatable {
        let type: RequestType
        /// The custom label, or nil for the built-in one.
        let label: String?
    }

    /// Those the settings enable, in their order, narrowed to the server's own
    /// list when it sends one. Until anything is published the built-in order
    /// is kept, so the list reads as it always did.
    static func requestTypes(
        _ types: [PrivacyCenterRequestTypeSetting],
        serverEnabled: [String]?,
        keepLegacyOrder: Bool = false
    ) -> [Option] {
        let options = types
            .filter { $0.enabled && (serverEnabled?.contains($0.key.rawValue) ?? true) }
            .map { Option(type: $0.key.requestType, label: $0.label) }
        guard keepLegacyOrder else { return options }
        let legacy = RequestType.allCases
        return options.sorted { (legacy.firstIndex(of: $0.type) ?? 0) < (legacy.firstIndex(of: $1.type) ?? 0) }
    }

    static func grievanceOptions(_ options: [GrievanceOption], allowed: [GrievanceType]) -> [GrievanceOption] {
        options.filter { allowed.contains($0.value) }
    }
}

/// The menu the settings describe: enabled sections in their order.
enum PrivacyCenterSections {
    static func isEnabled(_ key: PrivacyCenterSectionKey, in sections: [PrivacyCenterSection]) -> Bool {
        sections.first { $0.key == key }?.enabled ?? true
    }

    static func label(_ key: PrivacyCenterSectionKey, in sections: [PrivacyCenterSection], translate: (String) -> String) -> String {
        sections.first { $0.key == key }?.label ?? translate(key.labelKey)
    }

    /// The tabs: enabled sections other than notifications, which the bell opens.
    static func tabs(_ sections: [PrivacyCenterSection]) -> [PrivacyCenterSection] {
        sections.filter { $0.enabled && $0.key != .notifications }
    }
}

/// The built-in sign-in's contact rules (React `SignIn/contact.ts`).
enum PrivacyCenterSignInContact {
    enum Channel: String, Equatable {
        case email
        case sms
    }

    private static let email = try! NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)
    private static let phoneCharacters = try! NSRegularExpression(pattern: #"^[+\d\s()-]+$"#)
    private static let e164 = try! NSRegularExpression(pattern: #"^\+[1-9]\d{6,14}$"#)
    private static let indiaMobile = try! NSRegularExpression(pattern: #"^[6-9]\d{9}$"#)
    private static let letter = try! NSRegularExpression(pattern: "[a-z]", options: [.caseInsensitive])
    static let indiaCode = "+91"

    /// With both channels on, anything with an `@` or a letter is an email and
    /// anything made of digits is a phone; with one channel on, it is that one.
    static func detectChannel(_ raw: String, channels: PrivacyCenterSignInChannels) -> Channel? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        switch channels {
        case .email: return .email
        case .sms: return .sms
        case .both:
            if value.contains("@") || matches(letter, value) { return .email }
            return matches(phoneCharacters, value) ? .sms : nil
        }
    }

    /// A lower-cased email, or an E.164 number; a local number takes the code.
    static func normalize(_ raw: String, channel: Channel, countryCode: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if channel == .email {
            return value.lowercased()
        }
        let phone = value.filter { !" \t()-".contains($0) }
        if phone.hasPrefix("+") {
            return phone
        }
        if phone.hasPrefix("00") {
            return "+" + phone.dropFirst(2)
        }
        return countryCode + phone.drop(while: { $0 == "0" })
    }

    /// An Indian number needs ten digits starting 6-9.
    static func isValid(_ contact: String, channel: Channel) -> Bool {
        if channel == .email {
            return matches(email, contact) && !contact.contains("..")
        }
        guard matches(e164, contact) else { return false }
        return contact.hasPrefix(indiaCode) ? matches(indiaMobile, String(contact.dropFirst(indiaCode.count))) : true
    }

    /// `+91XXXXXX3210`: enough to recognise the number without showing it.
    static func maskPhone(_ phone: String) -> String {
        guard phone.count > 4 else { return phone }
        let prefix = phone.hasPrefix("+") ? 3 : 2
        let hidden = max(0, phone.count - prefix - 4)
        return String(phone.prefix(prefix)) + String(repeating: "X", count: hidden) + String(phone.suffix(4))
    }

    /// The string key for a failed OTP request: by the server's `error_code`,
    /// else by status, else a generic message.
    static func errorKey(code: String?, status: Int?) -> String {
        let byCode = [
            "RATE_LIMIT_EXCEEDED": "otpErrorRateLimit",
            "OTP_SEND_FAILED": "otpErrorSendFailed",
            "INVALID_CONTACT": "otpErrorInvalidContact",
            "OTP_NOT_FOUND": "otpErrorNotFound",
            "OTP_EXPIRED": "otpErrorExpired",
            "OTP_INVALID": "otpErrorInvalid",
            "USER_NOT_FOUND": "otpErrorUserNotFound",
            "INTERNAL_ERROR": "otpErrorInternal",
        ]
        let byStatus = [422: "otpErrorInvalidContact", 429: "otpErrorRateLimit", 503: "otpErrorSendFailed"]
        if let code, let key = byCode[code] { return key }
        if let status, let key = byStatus[status] { return key }
        return "otpErrorFallback"
    }

    private static func matches(_ pattern: NSRegularExpression, _ value: String) -> Bool {
        pattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}

/// Signs the visitor out after a stretch without activity (React
/// `createInactivityTimer`). One deadline: activity only moves the last-active
/// time, and a check re-arms for whatever idle time is left.
struct PrivacyCenterInactivityClock: Equatable {
    enum Check: Equatable {
        case fire
        case wait(TimeInterval)
        case done
    }

    let timeout: TimeInterval
    private(set) var lastActive: Date
    private(set) var fired = false

    init(timeout: TimeInterval, now: Date) {
        self.timeout = timeout
        self.lastActive = now
    }

    mutating func activity(at now: Date) {
        if !fired { lastActive = now }
    }

    /// Fires once the idle time reaches the timeout; otherwise says how long
    /// to wait before checking again.
    mutating func check(at now: Date) -> Check {
        if fired { return .done }
        let idle = now.timeIntervalSince(lastActive)
        if idle >= timeout {
            fired = true
            return .fire
        }
        return .wait(timeout - idle)
    }

    /// The app came back to the foreground. A suspended app's timers did not
    /// run, so the deadline is checked first; returning counts as activity only
    /// when the session had not already run out.
    mutating func resume(at now: Date) -> Check {
        guard !fired else { return .done }
        if check(at: now) == .fire { return .fire }
        lastActive = now
        return .wait(timeout)
    }
}

/// Colour arithmetic the settings' brand colours need (React
/// `applyBrandingTheme.ts`).
enum PrivacyCenterBrandColors {
    static let darkText = "#101828"
    static let lightText = "#FFFFFF"

    /// White or near-black, whichever has the higher WCAG contrast on `hex`.
    static func contrastText(_ hex: String) -> String {
        guard let background = luminance(hex), let dark = luminance(darkText) else { return lightText }
        let withWhite = 1.05 / (background + 0.05)
        let withDark = (background + 0.05) / (dark + 0.05)
        return withWhite >= withDark ? lightText : darkText
    }

    private static func luminance(_ hex: String) -> Double? {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        func channel(_ shift: Int) -> Double {
            let c = Double((value >> shift) & 0xff) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}

/// What the footer shows (React `ui/Footer.tsx`): the settings' links, the
/// privacy policy and contact lines, a copyright, and "Powered by".
struct PrivacyCenterFooterContent: Equatable {
    var links: [PrivacyCenterFooterLink] = []
    var showsContact = false
    var grievanceEmail: String?
    var grievanceUrl: String?
    var dpBoardUrl: String?
    var copyright: String?
    var showsPoweredBy = true

    var hasExtras: Bool {
        !links.isEmpty || showsContact || copyright != nil
    }

    var isEmpty: Bool {
        !hasExtras && !showsPoweredBy
    }

    /// The settings endpoint serves Brand Identity's details only when the
    /// footer asks for them; public workspace branding is the fallback for
    /// older servers.
    static func make(
        footer: PrivacyCenterFooterSettings,
        brandContact: PrivacyCenterBrandContact,
        brandingPrivacyPolicyUrl: String?,
        brandingDpoEmail: String?,
        hidePlatformBranding: Bool,
        privacyPolicyLabel: String,
        copyright: (String) -> String
    ) -> PrivacyCenterFooterContent {
        var content = PrivacyCenterFooterContent()
        content.showsPoweredBy = footer.showPoweredBy && !hidePlatformBranding
        content.links = footer.links
        let policyUrl = brandContact.privacyPolicyUrl ?? brandingPrivacyPolicyUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if footer.showPrivacyPolicy, let policyUrl, PrivacyCenterSettingsResolver.httpsUrl(.string(policyUrl)) != nil {
            content.links.append(PrivacyCenterFooterLink(label: privacyPolicyLabel, url: policyUrl))
        }
        if footer.showContact {
            content.showsContact = true
            let email = brandContact.grievanceEmail ?? brandingDpoEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            content.grievanceEmail = email.flatMap { $0.isEmpty ? nil : $0 }
            content.grievanceUrl = brandContact.grievanceUrl
            content.dpBoardUrl = brandContact.dpBoardUrl
        }
        if let template = footer.copyright {
            let filled = copyright(template)
            content.copyright = filled.isEmpty ? nil : filled
        }
        return content
    }
}
