import Foundation

public enum OtpGateCopy {
    public static let length = 6
    public static let title = "Enter the verification code"
    public static let description = "Ask the customer to read out the code they were sent. Your selections are locked until it is confirmed."
    public static let submit = "Confirm code"
    public static let verifying = "Verifying..."
    public static let failed = "Could not verify that code."

    static func digitLabel(_ index: Int) -> String {
        "Digit \(index + 1)"
    }
}

public enum ProductPolicyCopy {
    public static let label = "Privacy policies:"
    static let translationKey = "product_privacy_policies_label"
}

public enum SelectionControlCopy {
    public static let yes = "Yes"
    public static let no = "No"
    public static let mixed = "Mixed"

    static func onRecord(_ answer: String) -> String {
        "Saved answer: \(answer)"
    }

    static func settled(_ name: String) -> String {
        "Already consented to \(name)"
    }
}

public enum ConfirmDialogCopy {
    public static let confirm = "Yes"
    public static let cancel = "No"

    public static func title(for action: ConfirmAction) -> String {
        switch action {
        case .acceptAll:
            return "Accept every purpose?"
        case .acceptSelected:
            return "Confirm your selections?"
        case .decline:
            return "Decline this notice?"
        }
    }

    public static func detail(for action: ConfirmAction) -> String {
        switch action {
        case .acceptAll:
            return "This agrees to all purposes on this notice, including any you left unselected."
        case .acceptSelected:
            return "Only the purposes you selected are recorded as agreed. The rest are recorded as not agreed."
        case .decline:
            return "Nothing is recorded as agreed, including any purposes you selected."
        }
    }
}

/// Fixed English copy of the modal notice, as the React SDK ships it.
enum NoticeCopy {
    static let bannerHeading = "Privacy Notice"
    static let purposeSectionHeading = "Manage What You Share"
    static let privacyPolicyAnchor = "Privacy Policy"
    static let privacyCenterAnchor = "Privacy Center"
    static let submitting = "Processing..."
    static let reviewContinue = "Continue"
    static let loading = "Loading..."
    static let minorVerificationRequired = "Guardian verification is required before consent can be submitted."
    static let submitFailed = "Failed to submit consent. Please try again."
    static let startTalkback = "Start audio playback"
    static let pauseTalkback = "Pause audio playback"
    static let resumeTalkback = "Resume audio playback"

    static func languageChip(_ label: String) -> String {
        "Select language. Current language: \(label)"
    }
}

/// The dialog shown in place of the notice when it cannot be read.
enum NoticeErrorCopy {
    static let title = "Error Loading Consent Notice"
    static let fallback = "Failed to load consent notice. Please try again."
    static let retry = "Refresh"
    static let retryLabel = "Refresh and retry loading consent notice"
    static let close = "Close error message"
    static let configurationTitle = "Configuration Error"
    static let configurationHint = "Please check your component props and try again."
    static let missingNoticeId = "RedactoNoticeConsent: 'noticeId' prop is required and cannot be empty"
    static let missingAccessToken = "RedactoNoticeConsent: 'accessToken' prop is required and cannot be empty"
}

/// Defaults the DPO block draws when the notice leaves a link label empty.
enum DpoCopy {
    static let grievanceAnchor = "click here"
    static let emailConnector = "or email to"
    static let dpBoardAnchor = "here"
    static let dpoAnchor = "Click here"
}

/// Guardian verification copy for a minor's notice.
enum GuardianCopy {
    static let title = "Guardian Verification"
    static let nameRequired = "Guardian name is required"
    static let contactRequired = "Guardian contact is required"
    static let relationshipRequired = "Relationship to guardian is required"
    static let invalidResponse = "Invalid response from server: missing required fields"
    static let initiateFailed = "Failed to initiate verification. Please try again."
    static let openFailed = "Unable to open DigiLocker. Please try again."
    static let verify = "Verify via DigiLocker"
    static let verifying = "Verifying..."
    static let cancel = "Cancel"
    static let completed = "Verification Completed"
    static let failed = "Verification failed"
    static let continueLabel = "Continue"
    static let changeGuardian = "Change Guardian"
    static let tryAgain = "Try Again"
    static let goBack = "Go Back"
    static let opening = "Opening DigiLocker in Safari..."
    static let waiting = "Please complete the verification in Safari. This screen will update automatically when verification is complete."
    static let takingLonger = "Verification is taking longer than expected. Please try again."
    static let noReference = "Verification completed but no reference received. Please try again."
    static let sessionGone = "Verification session not found or expired. Please try again."
    static let statusUnavailable = "Unable to check verification status. Please try again."

    static func message(errorCode: String?, fallback: String?) -> String {
        switch errorCode {
        case "GUARDIAN_UNDER_18":
            return "The guardian must be 18 years or older. Please provide details of a different guardian."
        case "TOKEN_FAILED":
            return "DigiLocker verification could not be completed. Please try again."
        case "DIGILOCKER_AUTH_FAILED":
            return "DigiLocker authorization was cancelled or failed. Please try again."
        case "NO_AUTH_CODE":
            return "DigiLocker did not return an authorization code. Please try again."
        case "SESSION_EXPIRED":
            return "Verification session has expired. Please try again."
        default:
            if let fallback, !fallback.isEmpty { return fallback }
            return "Verification failed. Please try again."
        }
    }
}

/// Titles of the two collapsible notice sections.
struct NoticeSectionLabels: Equatable {
    let about: String
    let dpo: String
}

enum NoticeSectionCopy {
    static let english = NoticeSectionLabels(about: "About this notice", dpo: "Grievances & your DPO")

    /// Keyed by BCP-47 code. Bodo, Kashmiri, Manipuri and Santali have none
    /// until a native speaker supplies them, and fall back to notice copy.
    private static let labels: [String: NoticeSectionLabels] = [
        "en": english,
        "as": NoticeSectionLabels(about: "এই জাননীৰ বিষয়ে", dpo: "অভিযোগ আৰু যোগাযোগ"),
        "bn": NoticeSectionLabels(about: "এই বিজ্ঞপ্তি সম্পর্কে", dpo: "অভিযোগ ও যোগাযোগ"),
        "doi": NoticeSectionLabels(about: "इस सूचना बारै", dpo: "शिकायत ते संपर्क"),
        "gom": NoticeSectionLabels(about: "ह्या सुचनेविशीं", dpo: "तक्रार आनी संपर्क"),
        "gu": NoticeSectionLabels(about: "આ સૂચના વિશે", dpo: "ફરિયાદ અને સંપર્ક"),
        "hi": NoticeSectionLabels(about: "इस सूचना के बारे में", dpo: "शिकायत और संपर्क"),
        "kn": NoticeSectionLabels(about: "ಈ ಸೂಚನೆಯ ಬಗ್ಗೆ", dpo: "ಕುಂದುಕೊರತೆ ಮತ್ತು ಸಂಪರ್ಕ"),
        "mai": NoticeSectionLabels(about: "एहि सूचनाक विषयमे", dpo: "शिकायत आ संपर्क"),
        "ml": NoticeSectionLabels(about: "ഈ അറിയിപ്പിനെക്കുറിച്ച്", dpo: "പരാതിയും ബന്ധപ്പെടലും"),
        "mr": NoticeSectionLabels(about: "या सूचनेबद्दल", dpo: "तक्रार आणि संपर्क"),
        "ne": NoticeSectionLabels(about: "यस सूचनाबारे", dpo: "गुनासो र सम्पर्क"),
        "or": NoticeSectionLabels(about: "ଏହି ବିଜ୍ଞପ୍ତି ବିଷୟରେ", dpo: "ଅଭିଯୋଗ ଏବଂ ଯୋଗାଯୋଗ"),
        "pa": NoticeSectionLabels(about: "ਇਸ ਸੂਚਨਾ ਬਾਰੇ", dpo: "ਸ਼ਿਕਾਇਤ ਅਤੇ ਸੰਪਰਕ"),
        "sa": NoticeSectionLabels(about: "अस्याः सूचनायाः विषये", dpo: "परिवादः सम्पर्कश्च"),
        "sd": NoticeSectionLabels(about: "هن نوٽيس بابت", dpo: "شڪايت ۽ رابطو"),
        "ta": NoticeSectionLabels(about: "இந்த அறிவிப்பு பற்றி", dpo: "புகார் மற்றும் தொடர்பு"),
        "te": NoticeSectionLabels(about: "ఈ నోటీసు గురించి", dpo: "ఫిర్యాదు మరియు సంప్రదింపు"),
        "ur": NoticeSectionLabels(about: "اس نوٹس کے بارے میں", dpo: "شکایت اور رابطہ"),
    ]

    /// Labels for a notice language (display name or code), or nil for one the
    /// SDK has none for. English must be asked for by name or code: any name
    /// `toBcp47Code` does not know maps to "en".
    static func labels(for language: String) -> NoticeSectionLabels? {
        let code = NoticeLanguageCodes.toBcp47Code(language)
        let lower = language.lowercased()
        let isEnglish = lower == "english" || lower == "en" || lower.hasPrefix("en-")
        if code == "en" && !isEnglish {
            return nil
        }
        if let exact = labels[code] {
            return exact
        }
        return code.split(separator: "-").first.flatMap { labels[String($0)] }
    }
}
