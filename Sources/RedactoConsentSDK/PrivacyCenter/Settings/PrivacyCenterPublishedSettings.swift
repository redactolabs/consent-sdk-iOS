import Foundation

/// A Privacy Center menu section, keyed by the page it opens.
public enum PrivacyCenterSectionKey: String, CaseIterable, Sendable {
    case consentManager = "consent-manager"
    case form
    case activity
    case receipts
    case notifications

    /// The built-in, translated label a section without its own label shows.
    var labelKey: String {
        switch self {
        case .consentManager: return "consentManager"
        case .form: return "grievance"
        case .activity: return "activity"
        case .receipts: return "myReceipt"
        case .notifications: return "notifications"
        }
    }
}

/// A request type, keyed by the lower-case value a case is created with.
public enum PrivacyCenterRequestTypeKey: String, CaseIterable, Sendable {
    case access
    case correction
    case erasure
    case nomination
    case grievance

    var requestType: RequestType {
        switch self {
        case .access: return .access
        case .correction: return .correction
        case .erasure: return .erasure
        case .nomination: return .nomination
        case .grievance: return .grievance
        }
    }

    init(_ type: RequestType) {
        switch type {
        case .access: self = .access
        case .correction: self = .correction
        case .erasure: self = .erasure
        case .nomination: self = .nomination
        case .grievance: self = .grievance
        }
    }
}

public enum PrivacyCenterSignInLayout: String, CaseIterable, Sendable {
    case card, split, minimal
}

public enum PrivacyCenterSignInAlign: String, CaseIterable, Sendable {
    case center, left
}

public enum PrivacyCenterSignInBackground: String, CaseIterable, Sendable {
    case gradient, solid, image
}

public enum PrivacyCenterSignInChannels: String, CaseIterable, Sendable {
    case both, email, sms
}

public struct PrivacyCenterSection: Equatable, Sendable {
    public var key: PrivacyCenterSectionKey
    /// Nil uses the built-in, translated label.
    public var label: String?
    public var enabled: Bool

    public init(key: PrivacyCenterSectionKey, label: String? = nil, enabled: Bool = true) {
        self.key = key
        self.label = label
        self.enabled = enabled
    }
}

public struct PrivacyCenterRequestTypeSetting: Equatable, Sendable {
    public var key: PrivacyCenterRequestTypeKey
    /// Nil uses the built-in, translated label.
    public var label: String?
    public var enabled: Bool

    public init(key: PrivacyCenterRequestTypeKey, label: String? = nil, enabled: Bool = true) {
        self.key = key
        self.label = label
        self.enabled = enabled
    }
}

public struct PrivacyCenterFooterLink: Equatable, Sendable {
    public var label: String
    public var url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public struct PrivacyCenterBrandingSettings: Equatable, Sendable {
    public var inheritIdentity: Bool
    public var displayName: String?
    public var logoUrl: String?
    /// 28-96 points; nil keeps the built-in size.
    public var logoHeight: Int?
    public var inheritColors: Bool
    public var primaryColor: String?
    public var accentColor: String?
    public var inheritFont: Bool
    public var fontFamily: String?
    /// Classic or glass.
    public var style: AppearanceStyle
    /// 0-24 points; nil keeps the built-in radii.
    public var cornerRadius: Int?
}

public struct PrivacyCenterSignInSettings: Equatable, Sendable {
    public var layout: PrivacyCenterSignInLayout
    public var align: PrivacyCenterSignInAlign
    public var backgroundType: PrivacyCenterSignInBackground
    public var backgroundFrom: String
    public var backgroundTo: String
    public var backgroundColor: String
    public var backgroundImageUrl: String?
    public var highlights: [String]
    public var showLogo: Bool
    public var title: String
    public var tagline: String?
    public var heading: String
    public var description: String?
    public var channels: PrivacyCenterSignInChannels
    public var defaultCountryCode: String
    public var fieldLabel: String?
    public var placeholder: String?
    public var helpText: String?
    public var buttonText: String
    public var showNoticeLine: Bool
    public var noticeLine: String?
    public var showSupportLink: Bool
    public var supportText: String
    public var supportLinkText: String
    public var otpHeading: String
    public var otpDescription: String?
    public var otpButtonText: String
    public var otpResendText: String
}

public struct PrivacyCenterPortalSettings: Equatable, Sendable {
    public var sections: [PrivacyCenterSection]
    public var welcomeEnabled: Bool
    public var welcomeTitle: String
    public var welcomeMessage: String
    public var requestTypes: [PrivacyCenterRequestTypeSetting]
    public var grievanceCategories: [GrievanceType]
    /// Nil asks the data principal, as before settings existed.
    public var revokeConsentsOnErasure: Bool?
    /// Nil uses the built-in warning; a purpose's own message still wins.
    public var withdrawWarning: String?
    /// Nil never signs out for inactivity.
    public var sessionTimeoutMinutes: Int?
}

public struct PrivacyCenterLanguageSettings: Equatable, Sendable {
    public var enabled: [String]
    public var defaultLanguage: String
    public var autoDetect: Bool
    public var showSwitcher: Bool
}

public struct PrivacyCenterFooterSettings: Equatable, Sendable {
    public var links: [PrivacyCenterFooterLink]
    public var showPrivacyPolicy: Bool
    public var showContact: Bool
    public var copyright: String?
    public var showPoweredBy: Bool
}

/// The Privacy Center settings published from the Redacto console, every field
/// filled in. The web-only groups (`seo`, `custom_css`, `embed`) have no native
/// equivalent and are not read.
public struct ResolvedPrivacyCenterSettings: Equatable, Sendable {
    public var branding: PrivacyCenterBrandingSettings
    public var signIn: PrivacyCenterSignInSettings
    public var portal: PrivacyCenterPortalSettings
    public var languages: PrivacyCenterLanguageSettings
    public var footer: PrivacyCenterFooterSettings
}

/// Brand Identity details the public settings carry only when the published
/// settings use them (a `{legal}` placeholder, the footer's policy or contact
/// lines). Each is nil otherwise.
public struct PrivacyCenterBrandContact: Equatable, Sendable {
    public var legalEntityName: String?
    public var privacyPolicyUrl: String?
    public var grievanceEmail: String?
    public var grievanceUrl: String?
    public var dpBoardUrl: String?

    public static let empty = PrivacyCenterBrandContact()

    public init(
        legalEntityName: String? = nil,
        privacyPolicyUrl: String? = nil,
        grievanceEmail: String? = nil,
        grievanceUrl: String? = nil,
        dpBoardUrl: String? = nil
    ) {
        self.legalEntityName = legalEntityName
        self.privacyPolicyUrl = privacyPolicyUrl
        self.grievanceEmail = grievanceEmail
        self.grievanceUrl = grievanceUrl
        self.dpBoardUrl = dpBoardUrl
    }
}

enum PrivacyCenterSettingsLimits {
    /// Same order as the language switcher.
    static let languageCodes = [
        "en", "hi", "te", "mr", "ta", "ur", "gu", "kn", "ml", "pa", "or", "as",
        "bn", "mai", "ne", "sd", "doi", "mni-Mtei", "gom", "sa", "brx", "ks", "sat",
    ]
    static let rtlLanguages: Set<String> = ["ur", "sd", "ks"]
    static let countryCodes = ["+91", "+971", "+65", "+44", "+1"]
    static let fontFamilies = [
        "Inter", "Montserrat", "Poppins", "Lato", "Arial", "Verdana", "Trebuchet MS", "Georgia", "Times New Roman",
    ]
    static let sessionTimeoutMaxMinutes = 24 * 60
    static let logoHeight = 28...96
    static let cornerRadius = 0...24
    static let maxHighlights = 3
    static let maxFooterLinks = 5
    static let maxUrlLength = 2000
    /// How long a fetched copy of the published settings is reused.
    static let cacheLifetime: TimeInterval = 5 * 60
}

extension ResolvedPrivacyCenterSettings {
    /// Reproduces the Privacy Center as it was before settings existed: with
    /// nothing published, every value here renders exactly what it did.
    public static let defaults = ResolvedPrivacyCenterSettings(
        branding: PrivacyCenterBrandingSettings(
            inheritIdentity: true,
            displayName: nil,
            logoUrl: nil,
            logoHeight: nil,
            inheritColors: true,
            primaryColor: nil,
            accentColor: nil,
            inheritFont: true,
            fontFamily: nil,
            style: .classic,
            cornerRadius: nil
        ),
        signIn: PrivacyCenterSignInSettings(
            layout: .card,
            align: .center,
            backgroundType: .gradient,
            backgroundFrom: "#FFFFFF",
            backgroundTo: "#BFDBFE",
            backgroundColor: "#F4F6F8",
            backgroundImageUrl: nil,
            highlights: [],
            showLogo: true,
            title: "{brand} Privacy Center",
            tagline: "Your rights over your data, simplified",
            heading: "Let's confirm it's you",
            description: "Sign in with your mobile number or email to access your privacy centre.",
            channels: .both,
            defaultCountryCode: "+91",
            fieldLabel: nil,
            placeholder: nil,
            helpText: nil,
            buttonText: "Send OTP",
            showNoticeLine: false,
            noticeLine: nil,
            showSupportLink: true,
            supportText: "Trouble signing in?",
            supportLinkText: "Contact support",
            otpHeading: "OTP Verification",
            otpDescription: nil,
            otpButtonText: "Verify OTP",
            otpResendText: "Resend OTP"
        ),
        portal: PrivacyCenterPortalSettings(
            sections: PrivacyCenterSectionKey.allCases.map { PrivacyCenterSection(key: $0) },
            welcomeEnabled: false,
            welcomeTitle: "Welcome to the {brand} Privacy Center",
            welcomeMessage: "See every consent you have given and change any of it whenever you like.",
            requestTypes: PrivacyCenterRequestTypeKey.allCases.map { PrivacyCenterRequestTypeSetting(key: $0) },
            grievanceCategories: [.consentViolation, .unlawfulProcessing, .dataBreach],
            revokeConsentsOnErasure: nil,
            withdrawWarning: nil,
            sessionTimeoutMinutes: nil
        ),
        languages: PrivacyCenterLanguageSettings(
            enabled: PrivacyCenterSettingsLimits.languageCodes,
            defaultLanguage: "en",
            autoDetect: true,
            showSwitcher: true
        ),
        footer: PrivacyCenterFooterSettings(
            links: [],
            showPrivacyPolicy: false,
            showContact: false,
            copyright: nil,
            showPoweredBy: true
        )
    )
}
