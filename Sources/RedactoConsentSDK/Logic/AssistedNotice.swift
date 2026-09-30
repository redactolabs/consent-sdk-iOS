import Foundation

/// What React's `RedactoNoticeAssisted.tsx` derives from the notice. Its state is
/// keyed per purpose (never per product): the list is flat, in product order.
enum AssistedNotice {
    /// Each purpose once, in the order it renders: the config's order on a
    /// single-product notice, product by product on a grouped one. A purpose
    /// that covers none of the notice's products is left out (`purposesInRenderOrder`).
    static func displayedPurposes(_ config: ActiveConfig) -> [ActiveConfigPurpose] {
        var seen = Set<String>()
        return ProductMatrix.noticePurposeRows(config.products, config.purposes, order: config.productPurposeOrder)
            .compactMap { row in seen.insert(row.purpose.uuid).inserted ? row.purpose : nil }
    }

    /// Every `required` element of every shown purpose must be ticked, a
    /// disabled one included (tsx ~516-526): the purpose toggle ticks it.
    static func allRequiredElementsChecked(_ purposes: [ActiveConfigPurpose], _ selectedDataElements: [String: Bool]) -> Bool {
        purposes.allSatisfy { purpose in
            purpose.dataElements
                .filter(\.required)
                .allSatisfy { selectedDataElements[dataElementKey(purposeUuid: purpose.uuid, elementUuid: $0.uuid)] ?? false }
        }
    }

    /// The notice's pre-selection mode (NONE unless configured), purpose-keyed.
    static func initialSelection(_ config: ActiveConfig) -> SelectionState {
        PurposePreselectionLogic.build(
            purposes: config.purposes,
            mode: PurposePreselectionLogic.resolve(config.purposePreselection)
        )
    }

    static func initialCollapsed(_ config: ActiveConfig) -> [String: Bool] {
        Dictionary(config.purposes.map { ($0.uuid, true) }, uniquingKeysWith: { first, _ in first })
    }

    /// `default_language`, with an English code read as "English".
    static func initialLanguage(_ config: ActiveConfig) -> String {
        let language = config.defaultLanguage
        return language.isEmpty || language == "en" || language == "EN" ? "English" : language
    }

    /// React's assisted `getTranslatedText`: English reads the base copy;
    /// other languages translate purposes and data elements by id and top-level
    /// keys by name. Products are never translated here.
    static func text(_ config: ActiveConfig?, language: String, key: String, fallback: String, itemId: String? = nil) -> String {
        guard let config else { return fallback }
        if NoticeTranslation.isEnglish(language) {
            return fallback
        }
        guard let map = config.supportedLanguagesAndTranslations[language] else { return fallback }
        if let itemId {
            if key == "purposes.name" || key == "purposes.description" {
                return NoticeTranslation.pair(map.purposes?[itemId], nameKey: "purposes.name", key: key, defaultText: fallback)
            }
            if key.hasPrefix("data_elements.") {
                guard let value = map.dataElements?[itemId], !value.isEmpty else { return fallback }
                return value
            }
            return fallback
        }
        guard let value = map.value(forKey: key), !value.isEmpty else { return fallback }
        return value
    }
}

/// One clip of the notice's narration and the element it reads.
struct AssistedNarrationClip: Equatable {
    let url: String
    let elementId: String
}

/// React's `audioSequence` / `elementIdSequence`: the clips in on-screen order,
/// each paired with the id of the text it reads.
enum AssistedNarration {
    static func sequence(_ audio: TTSAudioDetail, config: ActiveConfig, purposes: [ActiveConfigPurpose]) -> [AssistedNarrationClip] {
        var clips: [AssistedNarrationClip] = []
        func add(_ url: String?, _ elementId: String) {
            if let url, !url.isEmpty {
                clips.append(AssistedNarrationClip(url: url, elementId: elementId))
            }
        }

        add(audio.noticeBannerHeadingAudioUrl, AssistedElementId.title)
        add(audio.noticeTextAudioUrl, AssistedElementId.noticeText)
        add(audio.privacyPolicyPrefixTextAudioUrl, AssistedElementId.privacyPolicyText)
        add(audio.privacyPolicyAnchorTextAudioUrl, AssistedElementId.privacyPolicyLink)
        add(audio.purposeSectionHeadingAudioUrl, AssistedElementId.purposeSectionHeading)

        for purpose in purposes {
            add(audio.purposesAudio[purpose.uuid]?.nameAudioUrl, AssistedElementId.purposeName(purpose.uuid))
            add(audio.purposesAudio[purpose.uuid]?.descriptionAudioUrl, AssistedElementId.purposeDescription(purpose.uuid))
            for element in purpose.dataElements {
                add(audio.dataElementsAudio[element.uuid]?.nameAudioUrl, AssistedElementId.dataElement(purpose.uuid, element.uuid))
            }
        }

        if !config.additionalText.isEmpty {
            add(audio.additionalTextAudioUrl, AssistedElementId.additionalText)
        }
        if !config.privacyCenterUrl.isEmpty {
            add(audio.privacyCenterAnchorTextAudioUrl, AssistedElementId.privacyCenterLink)
        }
        if config.dpoInfo != nil, let dpo = audio.dpoInfoAudio {
            add(dpo.grievanceTextAudioUrl, AssistedElementId.dpoGrievanceText)
            add(dpo.grievanceAnchorTextAudioUrl, AssistedElementId.dpoGrievanceLink)
            add(dpo.grievanceEmailConnectorTextAudioUrl, AssistedElementId.dpoGrievanceEmailConnector)
            add(dpo.grievanceEmailAudioUrl, AssistedElementId.dpoGrievanceEmail)
            add(dpo.dpBoardTextAudioUrl, AssistedElementId.dpoBoardText)
            add(dpo.dpBoardAnchorTextAudioUrl, AssistedElementId.dpoBoardLink)
            add(dpo.dpoTextAudioUrl, AssistedElementId.dpoText)
            add(dpo.dpoAnchorTextAudioUrl, AssistedElementId.dpoLink)
        }

        add(audio.confirmButtonTextAudioUrl, AssistedElementId.confirmButton)
        add(audio.declineButtonTextAudioUrl, AssistedElementId.declineButton)
        return clips
    }

    /// The purpose whose name, description or data element a clip reads.
    static func purpose(for elementId: String, in purposes: [ActiveConfigPurpose]) -> ActiveConfigPurpose? {
        purposes.first { purpose in
            elementId == AssistedElementId.purposeName(purpose.uuid)
                || elementId == AssistedElementId.purposeDescription(purpose.uuid)
                || elementId.hasPrefix("data-element-\(purpose.uuid)-")
        }
    }
}

/// The element ids React's assisted notice gives the text it narrates.
enum AssistedElementId {
    static let title = "privacy-notice-title"
    static let noticeText = "privacy-notice-text"
    static let privacyPolicyText = "privacy-policy-text"
    static let privacyPolicyLink = "privacy-policy-link"
    static let purposeSectionHeading = "purpose-section-heading"
    static let additionalText = "additional-text"
    static let privacyCenterLink = "privacy-center-link"
    static let dpoGrievanceText = "dpo-grievance-text"
    static let dpoGrievanceLink = "dpo-grievance-link"
    static let dpoGrievanceEmailConnector = "dpo-grievance-email-connector"
    static let dpoGrievanceEmail = "dpo-grievance-email"
    static let dpoBoardText = "dpo-dp-board-text"
    static let dpoBoardLink = "dpo-dp-board-link"
    static let dpoText = "dpo-dpo-text"
    static let dpoLink = "dpo-dpo-link"
    static let confirmButton = "confirm-button-text"
    static let declineButton = "decline-button-text"

    static func purposeName(_ uuid: String) -> String { "purpose-name-\(uuid)" }
    static func purposeDescription(_ uuid: String) -> String { "purpose-description-\(uuid)" }
    static func dataElement(_ purposeUuid: String, _ elementUuid: String) -> String {
        "data-element-\(purposeUuid)-\(elementUuid)"
    }
}
