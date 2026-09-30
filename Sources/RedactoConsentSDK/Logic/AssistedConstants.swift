import Foundation

enum AssistedConfig {
    static let otpLength = 6
    static let resendSeconds = 30
    static let dialCode = "+91"
    static let smsChannel = "sms"
    static let emailChannel = "email"
    static let otpPurpose = "login"
    static let mobileLength = 10
    static let emailPattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    static let alreadyProvidedCode = "CONSENT_ALREADY_PROVIDED"
    /// The checked checkbox fill, fixed in React's assisted stylesheet whatever
    /// the brand colour.
    static let checkboxAccent = "#4f87ff"
    static let mobilePlaceholder = "98765 43210"
    static let emailPlaceholder = "you@example.com"
}

/// The English copy React's assisted flow falls back to when the notice sets
/// none. Flow strings the SDK draws itself live in `AssistedI18n`.
enum AssistedDefaults {
    static let noticeHeading = "Privacy Notice"
    static let purposeSectionHeading = "Manage What You Share"
    static let privacyPolicyAnchor = "Privacy Policy"
    static let additionalText = "Manage or withdraw consent anytime at"
    static let privacyCenterAnchor = "Privacy Center"
    static let grievanceAnchor = "click here"
    static let grievanceEmailConnector = "or email to"
    static let dpBoardAnchor = "click here"
    static let dpoAnchor = "Click here"
    static let chevronColor = "#323B4B"
}

/// Parse fallbacks for the OTP endpoints, as React's `api/index.ts` passes them.
/// The flow shows localized copy instead; these only name the error.
enum AssistedAPIFallback {
    static let otpSend = "Could not send the OTP. Please try again."
    static let otpVerify = "Could not verify the OTP. Please try again."
}
