import Foundation

/// Every static string the assisted flow draws, keyed as React's
/// `RedactoNoticeAssisted/i18n.ts` keys them.
enum AssistedStaticKey: String, CaseIterable {
    case expandDetails
    case collapseDetails
    case selectAllFor
    case selectElement
    case selectElementRequired
    case required
    case logoAlt
    case selectLanguage
    case selectLanguageCurrent
    case opensInNewTab
    case audioStart
    case audioPause
    case talkbackStart
    case talkbackPause
    case mobileNumber
    case otpHelper
    case otpSentTo
    case changeMobile
    case enterNDigitOtp
    case otpDigit
    case resendIn
    case sending
    case resendOtp
    case getOtp
    case verifying
    case verifyOtp
    case emailAddress
    case otpHelperEmail
    case changeEmail
    case useEmailInstead
    case useMobileInstead
    case sendOtp
    case confirmOtp
    case verifyWithOtp
    case editSelections
    case otpIncorrect
    case otpExpired
    case otpNotFound
    case otpVerifyFailed
    case otpSendFailed
    case consentConfirmed
    case recordedUnder
    case recordedUnderAt
    case consentReferenceId
    case proceed
    case loadingNotice
    case loadFailedTitle
    case tryAgain
    case close
}

/// The assisted flow's static copy in the notice's language: React's
/// `makeStaticT(toBcp47Code(selectedLanguage))`. The notice's own content is
/// translated from the notice; these are the strings the SDK itself draws.
struct AssistedI18n {
    static let fallbackCode = "en"

    let code: String

    /// `language` is a notice language name ("Hindi") or code; it resolves
    /// through `NoticeLanguageCodes.toBcp47Code`, as React's does.
    init(language: String) {
        code = NoticeLanguageCodes.toBcp47Code(language)
    }

    /// The key in this language, else in English, with each `{token}` replaced
    /// from `vars`. A token with no value is left as written.
    func callAsFunction(_ key: AssistedStaticKey, _ vars: [String: CustomStringConvertible] = [:]) -> String {
        let template = Self.tables[code]?[key] ?? Self.tables[Self.fallbackCode]?[key] ?? key.rawValue
        return Self.interpolate(template, vars)
    }

    static func interpolate(_ template: String, _ vars: [String: CustomStringConvertible]) -> String {
        guard !vars.isEmpty else { return template }
        var result = ""
        var remainder = Substring(template)
        while let open = remainder.firstIndex(of: "{") {
            result += remainder[..<open]
            let afterOpen = remainder.index(after: open)
            guard let close = remainder[afterOpen...].firstIndex(of: "}") else {
                result += remainder[open...]
                return result
            }
            let token = remainder[afterOpen..<close]
            if !token.isEmpty, token.allSatisfy(isWordCharacter), let value = vars[String(token)] {
                result += value.description
            } else {
                result += remainder[open...close]
            }
            remainder = remainder[remainder.index(after: close)...]
        }
        result += remainder
        return result
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character == "_" || (character.isASCII && (character.isLetter || character.isNumber))
    }
}
