import Foundation

public struct PrivacyCenterLanguage: Identifiable, Hashable, Sendable {
    public let code: String
    public let label: String
    public var id: String { code }

    public init(code: String, label: String) {
        self.code = code
        self.label = label
    }
}

public enum PrivacyCenterLanguages {
    /// 24 languages mirroring `consent-sdk-react-native/src/RedactoPrivacyCenter/lib/constants.ts:8-33`.
    public static let all: [PrivacyCenterLanguage] = [
        .init(code: "en", label: "English"),
        .init(code: "hi", label: "हिन्दी (Hindi)"),
        .init(code: "te", label: "తెలుగు (Telugu)"),
        .init(code: "mr", label: "मराठी (Marathi)"),
        .init(code: "ta", label: "தமிழ் (Tamil)"),
        .init(code: "ur", label: "اردو (Urdu)"),
        .init(code: "gu", label: "ગુજરાતી (Gujarati)"),
        .init(code: "kn", label: "ಕನ್ನಡ (Kannada)"),
        .init(code: "ml", label: "മലയാളം (Malayalam)"),
        .init(code: "pa", label: "ਪੰਜਾਬੀ (Punjabi)"),
        .init(code: "or", label: "ଓଡ଼ିଆ (Odia)"),
        .init(code: "as", label: "অসমীয়া (Assamese)"),
        .init(code: "bn", label: "বাংলা (Bengali)"),
        .init(code: "mai", label: "मैथिली (Maithili)"),
        .init(code: "ne", label: "नेपाली (Nepali)"),
        .init(code: "sd", label: "سنڌي (Sindhi)"),
        .init(code: "doi", label: "डोगरी (Dogri)"),
        .init(code: "mni-Mtei", label: "ꯃꯩꯇꯩꯂꯣꯟ (Manipuri)"),
        .init(code: "gom", label: "कोंकणी (Goan Konkani)"),
        .init(code: "sa", label: "संस्कृतम् (Sanskrit)"),
        .init(code: "bho", label: "भोजपुरी (Bhojpuri)"),
        .init(code: "brx", label: "बड़ो (Bodo)"),
        .init(code: "ks", label: "كٲشُر (Kashmiri)"),
        .init(code: "sat", label: "ᱥᱟᱱᱛᱟᱲᱤ (Santali)"),
    ]

    public static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code.uppercased()
    }
}

public enum PCFormatting {
    /// Humanize a snake_case status like `in_progress` → `In progress`.
    public static func humanize(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        let cleaned = raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let lowered = cleaned.lowercased()
        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}
