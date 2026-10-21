import Foundation

/// Host overrides for `RedactoPrivacyCenter`'s `settings`, mirroring React's
/// `settings` prop. Each group is merged field by field over the settings
/// published in the Redacto console, so a host can change one value and keep
/// the rest. A field left nil keeps the published value; an empty string asks
/// for the built-in one. Overrides are validated like the published values.
public struct PrivacyCenterSettings: Sendable, Equatable {
    /// `"classic"` (the default) or `"glass"`, kept as an alias for
    /// `branding.style`. Anything unrecognised falls back to classic.
    public var theme: String?
    public var branding: Branding?
    public var signIn: SignIn?
    public var portal: Portal?
    public var languages: Languages?
    public var footer: Footer?

    public init(
        theme: String? = nil,
        branding: Branding? = nil,
        signIn: SignIn? = nil,
        portal: Portal? = nil,
        languages: Languages? = nil,
        footer: Footer? = nil
    ) {
        self.theme = theme
        self.branding = branding
        self.signIn = signIn
        self.portal = portal
        self.languages = languages
        self.footer = footer
    }

    var appearance: AppearanceStyle {
        theme.flatMap(AppearanceStyle.init(rawValue:)) == .glass ? .glass : .classic
    }

    /// Whether these overrides change anything beyond the legacy theme.
    var overridesPublishedSettings: Bool {
        branding != nil || signIn != nil || portal != nil || languages != nil || footer != nil
    }

    public struct Branding: Sendable, Equatable {
        public var inheritIdentity: Bool?
        public var displayName: String?
        public var logoUrl: String?
        /// `.some(nil)` asks for the built-in size.
        public var logoHeight: Int??
        public var inheritColors: Bool?
        public var primaryColor: String?
        public var accentColor: String?
        public var inheritFont: Bool?
        public var fontFamily: String?
        /// `"classic"` or `"glass"`; wins over `theme`.
        public var style: String?
        /// `.some(nil)` asks for the built-in radii.
        public var cornerRadius: Int??

        public init(
            inheritIdentity: Bool? = nil,
            displayName: String? = nil,
            logoUrl: String? = nil,
            logoHeight: Int?? = nil,
            inheritColors: Bool? = nil,
            primaryColor: String? = nil,
            accentColor: String? = nil,
            inheritFont: Bool? = nil,
            fontFamily: String? = nil,
            style: String? = nil,
            cornerRadius: Int?? = nil
        ) {
            self.inheritIdentity = inheritIdentity
            self.displayName = displayName
            self.logoUrl = logoUrl
            self.logoHeight = logoHeight
            self.inheritColors = inheritColors
            self.primaryColor = primaryColor
            self.accentColor = accentColor
            self.inheritFont = inheritFont
            self.fontFamily = fontFamily
            self.style = style
            self.cornerRadius = cornerRadius
        }
    }

    public struct SignIn: Sendable, Equatable {
        public var layout: PrivacyCenterSignInLayout?
        public var align: PrivacyCenterSignInAlign?
        public var backgroundType: PrivacyCenterSignInBackground?
        public var backgroundFrom: String?
        public var backgroundTo: String?
        public var backgroundColor: String?
        public var backgroundImageUrl: String?
        public var highlights: [String]?
        public var showLogo: Bool?
        public var title: String?
        public var tagline: String?
        public var heading: String?
        public var description: String?
        public var channels: PrivacyCenterSignInChannels?
        public var defaultCountryCode: String?
        public var fieldLabel: String?
        public var placeholder: String?
        public var helpText: String?
        public var buttonText: String?
        public var showNoticeLine: Bool?
        public var noticeLine: String?
        public var showSupportLink: Bool?
        public var supportText: String?
        public var supportLinkText: String?
        public var otpHeading: String?
        public var otpDescription: String?
        public var otpButtonText: String?
        public var otpResendText: String?

        public init(
            layout: PrivacyCenterSignInLayout? = nil,
            align: PrivacyCenterSignInAlign? = nil,
            backgroundType: PrivacyCenterSignInBackground? = nil,
            backgroundFrom: String? = nil,
            backgroundTo: String? = nil,
            backgroundColor: String? = nil,
            backgroundImageUrl: String? = nil,
            highlights: [String]? = nil,
            showLogo: Bool? = nil,
            title: String? = nil,
            tagline: String? = nil,
            heading: String? = nil,
            description: String? = nil,
            channels: PrivacyCenterSignInChannels? = nil,
            defaultCountryCode: String? = nil,
            fieldLabel: String? = nil,
            placeholder: String? = nil,
            helpText: String? = nil,
            buttonText: String? = nil,
            showNoticeLine: Bool? = nil,
            noticeLine: String? = nil,
            showSupportLink: Bool? = nil,
            supportText: String? = nil,
            supportLinkText: String? = nil,
            otpHeading: String? = nil,
            otpDescription: String? = nil,
            otpButtonText: String? = nil,
            otpResendText: String? = nil
        ) {
            self.layout = layout
            self.align = align
            self.backgroundType = backgroundType
            self.backgroundFrom = backgroundFrom
            self.backgroundTo = backgroundTo
            self.backgroundColor = backgroundColor
            self.backgroundImageUrl = backgroundImageUrl
            self.highlights = highlights
            self.showLogo = showLogo
            self.title = title
            self.tagline = tagline
            self.heading = heading
            self.description = description
            self.channels = channels
            self.defaultCountryCode = defaultCountryCode
            self.fieldLabel = fieldLabel
            self.placeholder = placeholder
            self.helpText = helpText
            self.buttonText = buttonText
            self.showNoticeLine = showNoticeLine
            self.noticeLine = noticeLine
            self.showSupportLink = showSupportLink
            self.supportText = supportText
            self.supportLinkText = supportLinkText
            self.otpHeading = otpHeading
            self.otpDescription = otpDescription
            self.otpButtonText = otpButtonText
            self.otpResendText = otpResendText
        }
    }

    public struct Portal: Sendable, Equatable {
        public var sections: [PrivacyCenterSection]?
        public var welcomeEnabled: Bool?
        public var welcomeTitle: String?
        public var welcomeMessage: String?
        public var requestTypes: [PrivacyCenterRequestTypeSetting]?
        public var grievanceCategories: [GrievanceType]?
        /// `.some(nil)` asks the data principal.
        public var revokeConsentsOnErasure: Bool??
        public var withdrawWarning: String?
        /// `.some(nil)` never signs out for inactivity.
        public var sessionTimeoutMinutes: Int??

        public init(
            sections: [PrivacyCenterSection]? = nil,
            welcomeEnabled: Bool? = nil,
            welcomeTitle: String? = nil,
            welcomeMessage: String? = nil,
            requestTypes: [PrivacyCenterRequestTypeSetting]? = nil,
            grievanceCategories: [GrievanceType]? = nil,
            revokeConsentsOnErasure: Bool?? = nil,
            withdrawWarning: String? = nil,
            sessionTimeoutMinutes: Int?? = nil
        ) {
            self.sections = sections
            self.welcomeEnabled = welcomeEnabled
            self.welcomeTitle = welcomeTitle
            self.welcomeMessage = welcomeMessage
            self.requestTypes = requestTypes
            self.grievanceCategories = grievanceCategories
            self.revokeConsentsOnErasure = revokeConsentsOnErasure
            self.withdrawWarning = withdrawWarning
            self.sessionTimeoutMinutes = sessionTimeoutMinutes
        }
    }

    public struct Languages: Sendable, Equatable {
        /// Language codes, such as `"en"` and `"hi"`.
        public var enabled: [String]?
        public var defaultLanguage: String?
        public var autoDetect: Bool?
        public var showSwitcher: Bool?

        public init(enabled: [String]? = nil, defaultLanguage: String? = nil, autoDetect: Bool? = nil, showSwitcher: Bool? = nil) {
            self.enabled = enabled
            self.defaultLanguage = defaultLanguage
            self.autoDetect = autoDetect
            self.showSwitcher = showSwitcher
        }
    }

    public struct Footer: Sendable, Equatable {
        public var links: [PrivacyCenterFooterLink]?
        public var showPrivacyPolicy: Bool?
        public var showContact: Bool?
        public var copyright: String?
        public var showPoweredBy: Bool?

        public init(
            links: [PrivacyCenterFooterLink]? = nil,
            showPrivacyPolicy: Bool? = nil,
            showContact: Bool? = nil,
            copyright: String? = nil,
            showPoweredBy: Bool? = nil
        ) {
            self.links = links
            self.showPrivacyPolicy = showPrivacyPolicy
            self.showContact = showContact
            self.copyright = copyright
            self.showPoweredBy = showPoweredBy
        }
    }
}
