import Foundation

/// The notice frame's own copy, which the server never translates: the yes/no
/// controls, the confirm dialog, the verification panel, the privacy policy
/// label and the confirm hints (React `chromeCopy.ts`).
struct NoticeChromeCopy: Equatable {
    let yes: String
    let no: String
    /// The part-answered dropdown row. One short word, so it fits the
    /// control's fixed slot in every script.
    let mixed: String
    /// Carries an `{answer}` placeholder.
    let savedAnswer: String
    let confirmAcceptAllTitle: String
    let confirmAcceptAllDetail: String
    let confirmAcceptSelectedTitle: String
    let confirmAcceptSelectedDetail: String
    let confirmDeclineTitle: String
    let confirmDeclineDetail: String
    let otpTitle: String
    let otpDescription: String
    let otpSubmit: String
    let otpVerifying: String
    let otpFailed: String
    let productPoliciesLabel: String
    let hintNothingChosen: String
    let hintNothingEngaged: String
    let hintRequiredOutstanding: String

    /// The copy for the language the notice is read in: its display name
    /// ("Hindi") or a BCP-47 code. An unknown language answers in English.
    /// "mni" and "mni-Mtei" are one bundle, as are "pa" and "pa-IN": the exact
    /// code matches first, then the primary subtag, whatever its case.
    static func forLanguage(_ language: String?) -> NoticeChromeCopy {
        guard let language, !language.isEmpty else { return english }
        return bundle(for: NoticeLanguageCodes.toBcp47Code(language)) ?? english
    }

    /// The languages this copy covers, for tests and tooling.
    static var languages: [String] { Array(translations.keys) }

    private static func bundle(for code: String) -> NoticeChromeCopy? {
        if let exact = translations[code] {
            return exact
        }
        let primary = primarySubtag(code)
        return translations.first { primarySubtag($0.key) == primary }?.value
    }

    private static func primarySubtag(_ tag: String) -> String {
        String(tag.split(separator: "-").first ?? Substring(tag)).lowercased()
    }

    func savedAnswer(_ answer: String) -> String {
        savedAnswer.replacingOccurrences(of: "{answer}", with: answer)
    }

    func confirmTitle(_ action: ConfirmAction) -> String {
        switch action {
        case .acceptAll: return confirmAcceptAllTitle
        case .acceptSelected: return confirmAcceptSelectedTitle
        case .decline: return confirmDeclineTitle
        }
    }

    func confirmDetail(_ action: ConfirmAction) -> String {
        switch action {
        case .acceptAll: return confirmAcceptAllDetail
        case .acceptSelected: return confirmAcceptSelectedDetail
        case .decline: return confirmDeclineDetail
        }
    }
}
