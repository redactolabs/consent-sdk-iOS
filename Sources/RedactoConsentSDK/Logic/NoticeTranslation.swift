import Foundation

enum NoticeTranslation {
    static func isEnglish(_ language: String) -> Bool {
        language == "English" || language == "en" || language == "EN"
    }

    /// English pinned first, a non-English default language second, then the
    /// rest A to Z by their English names.
    static func supportedLanguages(_ config: ActiveConfig) -> [String] {
        var languages = ["English"]
        let defaultLanguage = config.defaultLanguage
        if !defaultLanguage.isEmpty && defaultLanguage != "English" && defaultLanguage != "en" {
            languages.append(defaultLanguage)
        }
        let english = Locale(identifier: "en")
        let rest = config.supportedLanguagesAndTranslations.keys
            .filter { !languages.contains($0) }
            .sorted { $0.compare($1, locale: english) == .orderedAscending }
        return languages + rest
    }

    /// The language a freshly read notice opens in: its default language, with
    /// "en" named the way the language menu names it.
    static func openingLanguage(defaultLanguage: String) -> String? {
        guard !defaultLanguage.isEmpty else { return nil }
        return defaultLanguage == "en" || defaultLanguage == "EN" ? "English" : defaultLanguage
    }

    /// The language segment of the audio route: "English" for English, a
    /// translated language as keyed, anything else the notice's default.
    static func audioLanguage(_ language: String, config: ActiveConfig?) -> String {
        guard let config else { return "English" }
        if language == "English" || language == "en" {
            return "English"
        }
        if config.supportedLanguagesAndTranslations[language] != nil {
            return language
        }
        let fallback = config.defaultLanguage
        return fallback == "en" || fallback == "EN" || fallback.isEmpty ? "English" : fallback
    }

    static func text(
        _ config: ActiveConfig?,
        language: String,
        key: String,
        defaultText: String,
        itemId: String? = nil
    ) -> String {
        guard let config, !isEnglish(language),
              let map = config.supportedLanguagesAndTranslations[language] else { return defaultText }

        if let itemId {
            if key == "purposes.name" || key == "purposes.description" {
                return pair(map.purposes?[itemId], nameKey: "purposes.name", key: key, defaultText: defaultText)
            }
            if key == "products.name" || key == "products.description" {
                return pair(map.products?[itemId], nameKey: "products.name", key: key, defaultText: defaultText)
            }
            if key.hasPrefix("data_elements.") {
                guard let value = map.dataElements?[itemId], !value.isEmpty else { return defaultText }
                return value
            }
        }

        guard let value = map.value(forKey: key), !value.isEmpty else { return defaultText }
        return value
    }

    static func dpoText(_ config: ActiveConfig?, language: String, key: String, defaultText: String) -> String {
        guard let config, !isEnglish(language),
              let dpo = config.supportedLanguagesAndTranslations[language]?.dpoInfo else { return defaultText }
        let translated: String?
        switch key {
        case "grievance_text": translated = dpo.grievanceText
        case "grievance_anchor_text": translated = dpo.grievanceAnchorText
        case "grievance_email_connector_text": translated = dpo.grievanceEmailConnectorText
        case "dp_board_text": translated = dpo.dpBoardText
        case "dp_board_anchor_text": translated = dpo.dpBoardAnchorText
        case "dpo_text": translated = dpo.dpoText
        case "dpo_anchor_text": translated = dpo.dpoAnchorText
        default: translated = nil
        }
        guard let translated, !translated.isEmpty else { return defaultText }
        return translated
    }

    static func pair(_ translation: PurposeTranslation?, nameKey: String, key: String, defaultText: String) -> String {
        guard let translation else { return defaultText }
        let value = key == nameKey ? translation.nameValue : (translation.descriptionValue ?? "")
        return value.isEmpty ? defaultText : value
    }
}
