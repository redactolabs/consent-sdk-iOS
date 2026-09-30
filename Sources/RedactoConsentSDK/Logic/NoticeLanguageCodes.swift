import Foundation

/// Language names as the notice keys them (`supported_languages_and_translations`
/// and the language menu), mapped the way the React SDK's `language-codes.ts` does.
/// Covers English and the 22 languages of the 8th Schedule (DPDP Act 2023, §5-6).
enum NoticeLanguageCodes {
    static let nameToBcp47: [String: String] = [
        "English": "en",
        "Assamese": "as",
        "Bengali": "bn",
        "Bodo": "brx",
        "Dogri": "doi",
        "Gujarati": "gu",
        "Hindi": "hi",
        "Kannada": "kn",
        "Kashmiri": "ks",
        "Goan Konkani": "gom",
        "Maithili": "mai",
        "Malayalam": "ml",
        "Manipuri": "mni-Mtei",
        "Marathi": "mr",
        "Nepali": "ne",
        "Odia": "or",
        "Punjabi": "pa",
        "Sanskrit": "sa",
        "Santali": "sat",
        "Sindhi": "sd",
        "Tamil": "ta",
        "Telugu": "te",
        "Urdu": "ur",
    ]

    /// "Native script (English)" menu labels; English stays as is.
    static let nativeLabels: [String: String] = [
        "English": "English",
        "Assamese": "অসমীয়া (Assamese)",
        "Bengali": "বাংলা (Bengali)",
        "Bodo": "बड़ो (Bodo)",
        "Dogri": "डोगरी (Dogri)",
        "Gujarati": "ગુજરાતી (Gujarati)",
        "Hindi": "हिन्दी (Hindi)",
        "Kannada": "ಕನ್ನಡ (Kannada)",
        "Kashmiri": "كٲشُر (Kashmiri)",
        "Goan Konkani": "कोंकणी (Goan Konkani)",
        "Maithili": "मैथिली (Maithili)",
        "Malayalam": "മലയാളം (Malayalam)",
        "Manipuri": "ꯃꯩꯇꯩꯂꯣꯟ (Manipuri)",
        "Marathi": "मराठी (Marathi)",
        "Nepali": "नेपाली (Nepali)",
        "Odia": "ଓଡ଼ିଆ (Odia)",
        "Punjabi": "ਪੰਜਾਬੀ (Punjabi)",
        "Sanskrit": "संस्कृतम् (Sanskrit)",
        "Santali": "ᱥᱟᱱᱛᱟᱲᱤ (Santali)",
        "Sindhi": "سنڌي (Sindhi)",
        "Tamil": "தமிழ் (Tamil)",
        "Telugu": "తెలుగు (Telugu)",
        "Urdu": "اردو (Urdu)",
    ]

    private static let knownCodes = Set(nameToBcp47.values)

    private static let tagPattern = try! NSRegularExpression(pattern: "^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\\z")

    /// A language name or code as the BCP-47 code the submit payload carries:
    /// a known name ("Punjabi", any case) maps to its code, a known code or any
    /// well-formed tag ("en-US", "zh-Hans") passes through, anything else is "en".
    static func toBcp47Code(_ language: String) -> String {
        if let code = nameToBcp47[language] {
            return code
        }
        if knownCodes.contains(language) {
            return language
        }
        let lower = language.lowercased()
        if let match = nameToBcp47.first(where: { $0.key.lowercased() == lower }) {
            return match.value
        }
        let range = NSRange(language.startIndex..., in: language)
        if tagPattern.firstMatch(in: language, range: range) != nil {
            return language
        }
        return "en"
    }

    /// The "Native (English)" menu label for a language name, else the name itself.
    static func nativeLabel(_ name: String) -> String {
        nativeLabels[name] ?? name
    }
}
