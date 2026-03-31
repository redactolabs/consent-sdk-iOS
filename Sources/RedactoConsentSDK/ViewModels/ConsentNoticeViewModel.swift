import Foundation
import SwiftUI
import AVFoundation

struct TTSQueueItem: Equatable {
    let segmentKey: String
    let url: String
}

enum TTSQueueBuilder {
    static let dpoAudioKeyOrder: [String] = [
        "dpo_grievance_text",
        "dpo_grievance_anchor_text",
        "dpo_grievance_email_connector_text",
        "dpo_grievance_email",
        "dpo_dp_board_text",
        "dpo_dp_board_anchor_text",
        "dpo_dpo_text",
        "dpo_dpo_anchor_text",
    ]

    private static func appendIfPresent(_ key: String, urls: [String: String], queue: inout [TTSQueueItem]) {
        guard let url = urls[key], !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        queue.append(TTSQueueItem(segmentKey: key, url: url))
    }

    static func buildQueue(
        urls: [String: String],
        purposes: [ActiveConfigPurpose],
        hasAdditionalText: Bool,
        hasPrivacyCenterUrl: Bool,
        hasDpoInfo: Bool
    ) -> [TTSQueueItem] {
        var queue: [TTSQueueItem] = []

        appendIfPresent("notice_banner_heading", urls: urls, queue: &queue)
        appendIfPresent("notice_text", urls: urls, queue: &queue)
        appendIfPresent("privacy_policy_prefix_text", urls: urls, queue: &queue)
        appendIfPresent("privacy_policy_anchor_text", urls: urls, queue: &queue)
        appendIfPresent("purpose_section_heading", urls: urls, queue: &queue)

        for purpose in purposes {
            appendIfPresent("purpose_name_\(purpose.uuid)", urls: urls, queue: &queue)
            appendIfPresent("purpose_desc_\(purpose.uuid)", urls: urls, queue: &queue)
            for dataElement in purpose.dataElements {
                appendIfPresent("element_\(dataElement.uuid)", urls: urls, queue: &queue)
            }
        }

        if hasAdditionalText {
            appendIfPresent("additional_text", urls: urls, queue: &queue)
        }
        if hasPrivacyCenterUrl {
            appendIfPresent("privacy_center_anchor_text", urls: urls, queue: &queue)
        }

        if hasDpoInfo {
            for key in dpoAudioKeyOrder {
                appendIfPresent(key, urls: urls, queue: &queue)
            }
        }

        appendIfPresent("confirm_button_text", urls: urls, queue: &queue)
        appendIfPresent("decline_button_text", urls: urls, queue: &queue)

        return queue
    }
}

/// ViewModel for the modal RedactoNoticeConsent view.
/// Port of RedactoNoticeConsent.tsx state management and business logic.
@MainActor
public class ConsentNoticeViewModel: ObservableObject {
    // MARK: - Configuration
    let noticeId: String
    let accessToken: String
    let refreshToken: String
    let baseUrl: String?
    let settings: ConsentSettings?
    let initialLanguage: String
    let blockUI: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onError: ((Error) -> Void)?
    let applicationId: String?
    let validateAgainst: String
    let includeFullyConsentedData: Bool
    let reviewModeButtonText: String?

    // MARK: - Published State
    @Published var content: ConsentContent?
    @Published var isLoading = true
    @Published var isSubmitting = false
    @Published var selectedLanguage: String
    @Published var collapsedPurposes: [String: Bool] = [:]
    @Published var selectedPurposes: [String: Bool] = [:]
    @Published var selectedDataElements: [String: Bool] = [:]
    @Published var initialDataElementSelections: [String: Bool] = [:]
    @Published var errorMessage: String?
    @Published var isVisible = false

    // Reconsent / review / age
    @Published var isReconsentMode = false
    @Published var isReviewMode = false
    @Published var showAgeVerification = false
    @Published var showGuardianForm = false
    @Published var isMinor = false
    @Published var guardianFormData = GuardianFormData()
    @Published var guardianFormErrors: [String: String] = [:]
    @Published var isSubmittingGuardian = false

    // TTS
    @Published var isTTSAvailable = false
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var activeTTSSegmentKey: String?
    var ttsAudioUrls: [String: String] = [:]
    private var audioPlayer: AVPlayer?
    private var ttsQueue: [TTSQueueItem] = []
    private var ttsIndex = 0
    private var playerObserver: Any?

    // Guardian verification
    @Published var isMinorFlow = false
    @Published var showVerificationScreen = false
    @Published var isInitiatingVerification = false
    @Published var isPollingStatus = false
    @Published var isVerificationComplete = false
    @Published var isAutoTransitioning = false
    @Published var verificationError: String?
    @Published var verificationErrorCode: String?
    @Published var canRetryVerification = false
    private var verificationReference: String?
    private var selfDeclaredAdult = false
    private var verificationSessionToken: String?
    private var pollingTask: Task<Void, Never>?
    private var autoTransitionTask: Task<Void, Never>?

    // Language dropdown
    @Published var isLanguageDropdownOpen = false

    private var hasBootstrappedLanguage = false
    private var fetchTask: Task<Void, Never>?

    public struct GuardianFormData {
        public var guardianName = ""
        public var guardianContact = ""
        public var guardianRelationship = ""
    }

    // MARK: - Init

    public init(
        noticeId: String,
        accessToken: String,
        refreshToken: String,
        baseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        blockUI: Bool = true,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void,
        onError: ((Error) -> Void)? = nil,
        applicationId: String? = nil,
        validateAgainst: String = "all",
        includeFullyConsentedData: Bool = false,
        reviewModeButtonText: String? = nil
    ) {
        self.noticeId = noticeId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.baseUrl = baseUrl
        self.settings = settings
        self.initialLanguage = language
        self.selectedLanguage = language
        self.blockUI = blockUI
        self.onAccept = onAccept
        self.onDecline = onDecline
        self.onError = onError
        self.applicationId = applicationId
        self.validateAgainst = validateAgainst
        self.includeFullyConsentedData = includeFullyConsentedData
        self.reviewModeButtonText = reviewModeButtonText
    }

    deinit {
        fetchTask?.cancel()
        pollingTask?.cancel()
        autoTransitionTask?.cancel()
        audioPlayer?.pause()
        audioPlayer = nil
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Fetch Content

    func fetchContent() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
    }

    private func performFetch() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await ConsentAPI.fetchConsentContent(.init(
                noticeId: noticeId,
                accessToken: accessToken,
                baseUrl: baseUrl,
                language: selectedLanguage,
                specificUuid: applicationId,
                validateAgainst: validateAgainst,
                includeFullyConsentedData: includeFullyConsentedData
            ))

            if Task.isCancelled { return }

            let activeConfig = data.detail.activeConfig
            let purposeSelections = data.detail.purposeSelections
            let reconsentRequired = data.detail.reconsentRequired ?? false
            let noticeIsMinor = data.detail.isMinor ?? false

            isMinor = noticeIsMinor

            // Initialize collapsed/selected states
            var initialCollapsed: [String: Bool] = [:]
            var initialPurposeState: [String: Bool] = [:]
            var initialDataElementState: [String: Bool] = [:]
            var initialDataElementSelectionsMap: [String: Bool] = [:]

            for purpose in activeConfig.purposes {
                initialCollapsed[purpose.uuid] = true
                let sel = purposeSelections?[purpose.uuid]
                let purposeSelected = sel?.selected ?? false
                initialPurposeState[purpose.uuid] = purposeSelected

                for el in purpose.dataElements {
                    let combinedId = "\(purpose.uuid)-\(el.uuid)"
                    let elementSel = sel?.dataElements[el.uuid]?.selected ?? false
                    initialDataElementState[combinedId] = elementSel
                    initialDataElementSelectionsMap[combinedId] = elementSel
                }
            }

            collapsedPurposes = initialCollapsed
            selectedPurposes = initialPurposeState
            selectedDataElements = initialDataElementState
            initialDataElementSelections = initialDataElementSelectionsMap

            if !hasBootstrappedLanguage {
                hasBootstrappedLanguage = true
                if !activeConfig.defaultLanguage.isEmpty && activeConfig.defaultLanguage != selectedLanguage {
                    selectedLanguage = activeConfig.defaultLanguage
                }
            }

            content = data
            isReconsentMode = reconsentRequired

            // Review mode: if includeFullyConsentedData AND all purposes are fully consented
            if includeFullyConsentedData && !reconsentRequired {
                let allFullyConsented = activeConfig.purposes.allSatisfy { purpose in
                    let sel = purposeSelections?[purpose.uuid]
                    return (sel?.selected ?? false) && !(sel?.needsReconsent ?? false)
                }
                if allFullyConsented && !activeConfig.purposes.isEmpty {
                    isReviewMode = true
                }
            }

            if noticeIsMinor {
                showAgeVerification = true
                isMinorFlow = true
            }

            isVisible = true

            // Fetch TTS audio
            await fetchTTS()

        } catch let error as RedactoAPIError {
            if Task.isCancelled { return }

            if error.statusCode == 409 {
                onAccept()
                return
            }

            if error.statusCode == 401 {
                errorMessage = "Unauthorized: Invalid or expired token"
            } else {
                errorMessage = error.localizedDescription
            }
            onError?(error)
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            onError?(error)
        }

        isLoading = false
    }

    // MARK: - TTS

    private func fetchTTS() async {
        guard let content else { return }

        // Map language for TTS API — English uses "English", others use their key
        let languageCode: String
        if selectedLanguage == "en" || selectedLanguage == "EN" {
            languageCode = "English"
        } else {
            languageCode = selectedLanguage
        }

        do {
            let data = try await ConsentAPI.fetchTTSAudioUrls(.init(
                accessToken: accessToken,
                baseUrl: baseUrl,
                noticeUuid: content.detail.activeConfig.noticeUuid,
                language: languageCode
            ))

            var urls: [String: String] = [:]
            urls["notice_text"] = data.detail.noticeTextAudioUrl
            urls["additional_text"] = data.detail.additionalTextAudioUrl
            urls["notice_banner_heading"] = data.detail.noticeBannerHeadingAudioUrl
            urls["purpose_section_heading"] = data.detail.purposeSectionHeadingAudioUrl
            urls["privacy_policy_prefix_text"] = data.detail.privacyPolicyPrefixTextAudioUrl
            urls["privacy_policy_anchor_text"] = data.detail.privacyPolicyAnchorTextAudioUrl
            urls["privacy_center_anchor_text"] = data.detail.privacyCenterAnchorTextAudioUrl
            urls["confirm_button_text"] = data.detail.confirmButtonTextAudioUrl
            urls["decline_button_text"] = data.detail.declineButtonTextAudioUrl

            for p in content.detail.activeConfig.purposes {
                if let pa = data.detail.purposesAudio[p.uuid] {
                    urls["purpose_name_\(p.uuid)"] = pa.nameAudioUrl
                    urls["purpose_desc_\(p.uuid)"] = pa.descriptionAudioUrl
                }
                for el in p.dataElements {
                    if let ea = data.detail.dataElementsAudio[el.uuid] {
                        urls["element_\(el.uuid)"] = ea.nameAudioUrl
                    }
                }
            }

            if let dpoAudio = data.detail.dpoInfoAudio {
                urls["dpo_grievance_text"] = dpoAudio.grievanceTextAudioUrl
                urls["dpo_grievance_anchor_text"] = dpoAudio.grievanceAnchorTextAudioUrl
                urls["dpo_grievance_email_connector_text"] = dpoAudio.grievanceEmailConnectorTextAudioUrl
                urls["dpo_grievance_email"] = dpoAudio.grievanceEmailAudioUrl
                urls["dpo_dp_board_text"] = dpoAudio.dpBoardTextAudioUrl
                urls["dpo_dp_board_anchor_text"] = dpoAudio.dpBoardAnchorTextAudioUrl
                urls["dpo_dpo_text"] = dpoAudio.dpoTextAudioUrl
                urls["dpo_dpo_anchor_text"] = dpoAudio.dpoAnchorTextAudioUrl
            }

            ttsAudioUrls = urls
            isTTSAvailable = !urls.isEmpty
        } catch {
            #if DEBUG
            print("[RedactoConsentSDK] TTS fetch failed for language '\(languageCode)': \(error.localizedDescription)")
            #endif
            isTTSAvailable = false
        }
    }

    func toggleAudio() {
        if isPlaying && !isPaused {
            audioPlayer?.pause()
            activeTTSSegmentKey = nil
            isPaused = true
        } else if isPaused {
            audioPlayer?.play()
            if ttsIndex > 0, ttsIndex - 1 < ttsQueue.count {
                activeTTSSegmentKey = ttsQueue[ttsIndex - 1].segmentKey
            }
            isPaused = false
        } else {
            startAudio()
        }
    }

    private func startAudio() {
        guard let content else { return }
        let ac = content.detail.activeConfig
        ttsQueue = TTSQueueBuilder.buildQueue(
            urls: ttsAudioUrls,
            purposes: ac.purposes,
            hasAdditionalText: !ac.additionalText.isEmpty,
            hasPrivacyCenterUrl: !ac.privacyCenterUrl.isEmpty,
            hasDpoInfo: ac.dpoInfo != nil
        )
        ttsIndex = 0
        isPlaying = true
        isPaused = false
        playNextInQueue()
    }

    private func playNextInQueue() {
        guard ttsIndex < ttsQueue.count else {
            stopAudio()
            return
        }

        let queueItem = ttsQueue[ttsIndex]
        ttsIndex += 1
        activeTTSSegmentKey = queueItem.segmentKey
        autoExpandPurposeIfNeeded(for: queueItem.segmentKey)

        guard let url = URL(string: queueItem.url) else {
            playNextInQueue()
            return
        }

        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)

        // Remove existing observer
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.playNextInQueue()
        }

        audioPlayer?.play()
    }

    func stopAudio() {
        stopAudioSync()
        isPlaying = false
        isPaused = false
        activeTTSSegmentKey = nil
        ttsIndex = 0
    }

    private func stopAudioSync() {
        audioPlayer?.pause()
        audioPlayer = nil
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
    }

    // MARK: - Translation Helper

    /// Check if the given language is the default/base language.
    /// Matching the React SDK's `isDefaultLanguage()` — only English is treated as default.
    private func isDefaultLanguage(_ lang: String) -> Bool {
        guard content != nil else { return true }
        return lang == "English" || lang == "en" || lang == "EN"
    }

    func getTranslatedText(_ key: String, defaultText: String, itemId: String? = nil) -> String {
        guard let content else { return defaultText }
        let activeConfig = content.detail.activeConfig

        // For default language, return the base text from activeConfig directly
        if isDefaultLanguage(selectedLanguage) {
            return defaultText
        }

        guard let translationMap = activeConfig.supportedLanguagesAndTranslations[selectedLanguage] else {
            return defaultText
        }

        if let itemId {
            if key == "purposes.name" || key == "purposes.description" {
                if let purposeData = translationMap.purposes?[itemId] {
                    switch purposeData {
                    case .name(let str):
                        return key == "purposes.name" ? (str.isEmpty ? defaultText : str) : defaultText
                    case .full(let name, let description):
                        if key == "purposes.name" {
                            return name.isEmpty ? defaultText : name
                        }
                        return description.isEmpty ? defaultText : description
                    }
                }
                return defaultText
            }
            if key.hasPrefix("data_elements.") {
                if let translated = translationMap.dataElements?[itemId], !translated.isEmpty {
                    return translated
                }
                return defaultText
            }
        }

        if let value = translationMap.value(forKey: key), !value.isEmpty {
            return value
        }
        return defaultText
    }

    /// Translate DPO info text fields.
    /// Port of `getTranslatedDpoText` from the React SDK.
    func getTranslatedDpoText(_ key: String, defaultText: String) -> String {
        guard let content else { return defaultText }
        let activeConfig = content.detail.activeConfig

        // For default language, return default text
        if isDefaultLanguage(selectedLanguage) {
            return defaultText
        }

        // Check if we have a translation map for the selected language
        guard let translationMap = activeConfig.supportedLanguagesAndTranslations[selectedLanguage] else {
            return defaultText
        }

        // Look up the DPO translation
        if let dpoTranslation = translationMap.dpoInfo {
            let translated: String?
            switch key {
            case "grievance_text": translated = dpoTranslation.grievanceText
            case "grievance_anchor_text": translated = dpoTranslation.grievanceAnchorText
            case "grievance_email_connector_text": translated = dpoTranslation.grievanceEmailConnectorText
            case "dp_board_text": translated = dpoTranslation.dpBoardText
            case "dp_board_anchor_text": translated = dpoTranslation.dpBoardAnchorText
            case "dpo_text": translated = dpoTranslation.dpoText
            case "dpo_anchor_text": translated = dpoTranslation.dpoAnchorText
            default: translated = nil
            }
            if let translated, !translated.isEmpty {
                return translated
            }
        }

        return defaultText
    }

    /// Called when selectedLanguage changes to re-fetch TTS audio.
    func onLanguageChanged() {
        guard content != nil else { return }
        // Reset TTS and re-fetch for new language
        isTTSAvailable = false
        ttsAudioUrls = [:]
        stopAudio()
        Task { [weak self] in
            await self?.fetchTTS()
        }
    }

    // MARK: - Purpose/Element Toggles

    func handlePurposeToggle(_ purposeUuid: String) {
        let newState = !(selectedPurposes[purposeUuid] ?? false)
        selectedPurposes[purposeUuid] = newState

        guard let purposes = content?.detail.activeConfig.purposes,
              let purpose = purposes.first(where: { $0.uuid == purposeUuid }) else { return }

        for el in purpose.dataElements {
            selectedDataElements["\(purposeUuid)-\(el.uuid)"] = newState
        }
    }

    func handlePurposeCollapse(_ purposeUuid: String) {
        collapsedPurposes[purposeUuid] = !(collapsedPurposes[purposeUuid] ?? true)
    }

    private func autoExpandPurposeIfNeeded(for segmentKey: String) {
        guard let purposeUuid = purposeUUID(for: segmentKey) else {
            return
        }
        if collapsedPurposes[purposeUuid] == true {
            collapsedPurposes[purposeUuid] = false
        }
    }

    private func purposeUUID(for segmentKey: String) -> String? {
        if segmentKey.hasPrefix("purpose_name_") {
            return String(segmentKey.dropFirst("purpose_name_".count))
        }
        if segmentKey.hasPrefix("purpose_desc_") {
            return String(segmentKey.dropFirst("purpose_desc_".count))
        }
        if segmentKey.hasPrefix("element_") {
            let dataElementUUID = String(segmentKey.dropFirst("element_".count))
            return content?.detail.activeConfig.purposes.first(where: { purpose in
                purpose.dataElements.contains(where: { $0.uuid == dataElementUUID })
            })?.uuid
        }
        return nil
    }

    func handleDataElementToggle(_ elementUuid: String, purposeUuid: String) {
        guard let purposes = content?.detail.activeConfig.purposes,
              let purpose = purposes.first(where: { $0.uuid == purposeUuid }) else { return }

        let combinedId = "\(purposeUuid)-\(elementUuid)"
        selectedDataElements[combinedId] = !(selectedDataElements[combinedId] ?? false)

        let requiredElements = purpose.dataElements.filter { $0.required }
        let shouldCheckPurpose: Bool
        if !requiredElements.isEmpty {
            shouldCheckPurpose = requiredElements.allSatisfy { el in
                selectedDataElements["\(purposeUuid)-\(el.uuid)"] ?? false
            }
        } else {
            shouldCheckPurpose = purpose.dataElements.contains { el in
                selectedDataElements["\(purposeUuid)-\(el.uuid)"] ?? false
            }
        }
        selectedPurposes[purposeUuid] = shouldCheckPurpose
    }

    // MARK: - Submit

    func handleAccept() {
        guard let content else { return }

        // Block if minor flow active but verification reference missing
        if isMinorFlow && verificationReference == nil {
            errorMessage = "Guardian verification is required before consent can be submitted."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            self.isSubmitting = true
            self.errorMessage = nil

            do {
                let activeConfig = content.detail.activeConfig
                let purposeSelections = content.detail.purposeSelections

                let purposes = activeConfig.purposes.map { purpose -> Purpose in
                    // Check if this is an already-consented purpose
                    let sel = purposeSelections?[purpose.uuid]
                    let isAlreadyConsented = (sel?.selected ?? false) && !(sel?.needsReconsent ?? false)

                    var purposeSelected = self.selectedPurposes[purpose.uuid] ?? false

                    // For already-consented purposes, check if any data element was modified
                    if isAlreadyConsented {
                        let wasModified = purpose.dataElements.contains { el in
                            let combinedId = "\(purpose.uuid)-\(el.uuid)"
                            let current = self.selectedDataElements[combinedId] ?? false
                            let initial = self.initialDataElementSelections[combinedId] ?? false
                            return current != initial
                        }
                        if wasModified {
                            purposeSelected = true
                        }
                    }

                    return Purpose(
                        uuid: purpose.uuid,
                        name: purpose.name,
                        description: purpose.description,
                        industries: purpose.industries,
                        selected: purposeSelected,
                        dataElements: purpose.dataElements.map { el in
                            DataElement(
                                uuid: el.uuid,
                                name: el.name,
                                description: el.description,
                                industries: el.industries,
                                enabled: el.enabled,
                                required: el.required,
                                selected: el.required ? true : (self.selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false)
                            )
                        }
                    )
                }

                try await ConsentAPI.submitConsentEvent(.init(
                    accessToken: self.accessToken,
                    baseUrl: self.baseUrl,
                    noticeUuid: activeConfig.noticeUuid,
                    purposes: purposes,
                    declined: false,
                    metaData: self.applicationId.map { MetaData(specificUuid: $0) },
                    guardianVerificationReference: self.verificationReference,
                    selfDeclaredAdult: self.selfDeclaredAdult ? true : nil
                ))

                self.stopAudio()
                await ConsentAPI.clearCache()
                self.isVisible = false
                self.onAccept()
            } catch {
                let apiError = error as? RedactoAPIError
                self.errorMessage = apiError?.statusCode == 500
                    ? "An error occurred. Please try again later."
                    : error.localizedDescription
                self.onError?(error)
            }

            self.isSubmitting = false
        }
    }

    func handleDecline() {
        stopPolling()
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        stopAudio()
        isVisible = false
        onDecline()
    }

    // MARK: - Guardian Form

    func handleGuardianFormChange(_ field: String, _ value: String) {
        switch field {
        case "guardianName":
            guardianFormData.guardianName = value
        case "guardianContact":
            guardianFormData.guardianContact = value
        case "guardianRelationship":
            guardianFormData.guardianRelationship = value
        default:
            break
        }
        guardianFormErrors[field] = nil
    }

    func handleGuardianFormNext() {
        var errors: [String: String] = [:]
        if guardianFormData.guardianName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianName"] = "Guardian name is required"
        }
        if guardianFormData.guardianContact.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianContact"] = "Guardian contact is required"
        }
        if guardianFormData.guardianRelationship.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianRelationship"] = "Relationship is required"
        }
        guard errors.isEmpty else {
            guardianFormErrors = errors
            return
        }

        Task { [weak self] in
            guard let self else { return }
            self.isSubmittingGuardian = true
            self.guardianFormErrors = [:]
            self.verificationError = nil

            do {
                let response = try await ConsentAPI.initiateGuardianVerification(.init(
                    accessToken: self.accessToken,
                    baseUrl: self.baseUrl,
                    guardianName: self.guardianFormData.guardianName,
                    guardianContact: self.guardianFormData.guardianContact,
                    guardianRelationship: self.guardianFormData.guardianRelationship
                ))

                self.isSubmittingGuardian = false

                if response.alreadyVerified == true {
                    // Guardian already verified — show success flash and auto-transition
                    self.verificationReference = response.verificationReference
                    self.showGuardianForm = false
                    self.showVerificationScreen = true
                    self.isVerificationComplete = true
                    self.isAutoTransitioning = true

                    self.autoTransitionTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        guard let self, !Task.isCancelled else { return }
                        self.showVerificationScreen = false
                        self.isVerificationComplete = false
                        self.isAutoTransitioning = false
                    }
                } else if let sessionToken = response.sessionToken,
                          let redirectUrl = response.digilockerRedirectUrl,
                          let url = URL(string: redirectUrl) {
                    // New verification: show verification screen, open DigiLocker, start polling
                    self.showGuardianForm = false
                    self.showVerificationScreen = true
                    self.isInitiatingVerification = true

                    await UIApplication.shared.open(url)

                    self.isInitiatingVerification = false
                    self.isPollingStatus = true
                    self.startStatusPolling(sessionToken: sessionToken)
                } else if response.verificationReference != nil {
                    // Direct verification reference (no DigiLocker needed)
                    self.verificationReference = response.verificationReference
                    self.showGuardianForm = false
                    self.showVerificationScreen = true
                    self.isVerificationComplete = true
                    self.isAutoTransitioning = true

                    self.autoTransitionTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        guard let self, !Task.isCancelled else { return }
                        self.showVerificationScreen = false
                        self.isVerificationComplete = false
                        self.isAutoTransitioning = false
                    }
                } else {
                    self.guardianFormErrors["general"] = "Invalid response from server: missing required fields"
                }
            } catch {
                self.isSubmittingGuardian = false
                let apiError = error as? RedactoAPIError

                if apiError?.statusCode == 422 {
                    // Validation error — parse field-specific errors
                    let message = error.localizedDescription
                    if message.contains("guardian_contact") {
                        self.guardianFormErrors["guardianContact"] = message
                    } else if message.contains("guardian_name") {
                        self.guardianFormErrors["guardianName"] = message
                    } else if message.contains("guardian_relationship") {
                        self.guardianFormErrors["guardianRelationship"] = message
                    } else {
                        self.guardianFormErrors["general"] = message
                    }
                    self.showVerificationScreen = false
                    self.showGuardianForm = true
                } else {
                    self.guardianFormErrors["general"] = error.localizedDescription
                    self.showVerificationScreen = false
                    self.showGuardianForm = true
                }
            }
        }
    }

    // MARK: - Age Verification

    func handleAgeVerificationYes() {
        showAgeVerification = false
        isMinorFlow = false
        selfDeclaredAdult = true
    }

    func handleAgeVerificationNo() {
        showAgeVerification = false
        if isMinor {
            showGuardianForm = true
        }
    }

    // MARK: - Verification Polling

    private func getVerificationErrorMessage(errorCode: String?, fallbackError: String?) -> String {
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
            return fallbackError ?? "Verification failed. Please try again."
        }
    }

    private func startStatusPolling(sessionToken: String) {
        stopPolling()
        verificationSessionToken = sessionToken
        isPollingStatus = true

        pollingTask = Task { [weak self] in
            guard let self else { return }

            let maxAttempts = 40
            let maxConsecutiveErrors = 3
            let pollIntervalNanos: UInt64 = 3_000_000_000 // 3 seconds
            var attempts = 0
            var consecutiveErrors = 0
            var paused = false

            // Observe app lifecycle for pause/resume
            let willResignObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in paused = true }

            let didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in paused = false }

            defer {
                NotificationCenter.default.removeObserver(willResignObserver)
                NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            }

            while !Task.isCancelled {
                // Wait for poll interval (but fire immediately on first resume from background)
                if attempts > 0 {
                    try? await Task.sleep(nanoseconds: pollIntervalNanos)
                    if Task.isCancelled { break }
                }

                // Skip poll if app is in background
                if paused {
                    try? await Task.sleep(nanoseconds: 500_000_000) // check every 0.5s
                    continue
                }

                attempts += 1

                if attempts > maxAttempts {
                    await MainActor.run {
                        self.verificationError = self.getVerificationErrorMessage(errorCode: "SESSION_EXPIRED", fallbackError: nil)
                        self.verificationErrorCode = "SESSION_EXPIRED"
                        self.canRetryVerification = true
                        self.isPollingStatus = false
                        self.isInitiatingVerification = false
                    }
                    break
                }

                do {
                    let response = try await ConsentAPI.verifyGuardianStatus(.init(
                        accessToken: self.accessToken,
                        baseUrl: self.baseUrl,
                        sessionToken: sessionToken
                    ))

                    if Task.isCancelled { break }
                    consecutiveErrors = 0

                    if response.status == "verified" {
                        let ref = response.verificationReference
                        guard let ref else {
                            await MainActor.run {
                                self.verificationError = "Verification completed but no reference received. Please try again."
                                self.canRetryVerification = true
                                self.isPollingStatus = false
                                self.isInitiatingVerification = false
                            }
                            break
                        }
                        await MainActor.run {
                            self.verificationReference = ref
                            self.isVerificationComplete = true
                            self.isPollingStatus = false
                            self.isInitiatingVerification = false
                        }
                        break
                    }

                    if response.status == "failed" || response.status == "expired" {
                        await MainActor.run {
                            self.verificationError = self.getVerificationErrorMessage(
                                errorCode: response.errorCode,
                                fallbackError: response.error
                            )
                            self.verificationErrorCode = response.errorCode
                            self.canRetryVerification = response.canRetry ?? false
                            self.isPollingStatus = false
                            self.isInitiatingVerification = false
                        }
                        break
                    }

                    // status is "pending" or "in_progress" — continue polling
                } catch {
                    if Task.isCancelled { break }
                    consecutiveErrors += 1

                    let apiError = error as? RedactoAPIError
                    if apiError?.statusCode == 404 || apiError?.statusCode == 410 {
                        await MainActor.run {
                            self.verificationError = "Verification session not found or expired. Please try again."
                            self.verificationErrorCode = "SESSION_EXPIRED"
                            self.canRetryVerification = true
                            self.isPollingStatus = false
                            self.isInitiatingVerification = false
                        }
                        break
                    }

                    if consecutiveErrors >= maxConsecutiveErrors {
                        await MainActor.run {
                            self.verificationError = error.localizedDescription
                            self.canRetryVerification = true
                            self.isPollingStatus = false
                            self.isInitiatingVerification = false
                        }
                        break
                    }
                }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPollingStatus = false
        isInitiatingVerification = false
    }

    func handleBackToGuardianForm(clearName: Bool = false) {
        stopPolling()
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        showVerificationScreen = false
        showGuardianForm = true
        verificationError = nil
        verificationErrorCode = nil
        canRetryVerification = false
        isVerificationComplete = false
        isAutoTransitioning = false
        if clearName {
            guardianFormData.guardianName = ""
        }
    }

    func handleVerificationContinue() {
        showVerificationScreen = false
        isVerificationComplete = false
    }

    // MARK: - Derived

    var activeConfig: ActiveConfig? { content?.detail.activeConfig }
    var logoUrl: URL? {
        guard let urlString = activeConfig?.logoUrl, !urlString.isEmpty else { return nil }
        if let url = URL(string: urlString) { return url }
        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) { return url }
        return nil
    }

    var supportedLanguages: [String] {
        guard let ac = activeConfig else { return [] }
        var languages = ["English"]

        let defaultLang = ac.defaultLanguage
        if !defaultLang.isEmpty && defaultLang != "English" && defaultLang != "en" && defaultLang != "EN" {
            languages.append(defaultLang)
        }

        for key in ac.supportedLanguagesAndTranslations.keys.sorted() {
            if !languages.contains(key) {
                languages.append(key)
            }
        }

        return languages
    }

    /// Whether all required data elements across all purposes are checked.
    /// Matching React SDK's `areAllRequiredElementsChecked` (lines 1621-1631).
    var areAllRequiredElementsChecked: Bool {
        guard let ac = activeConfig else { return false }
        return ac.purposes.allSatisfy { purpose in
            let requiredElements = purpose.dataElements.filter { $0.required }
            return requiredElements.allSatisfy { el in
                selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false
            }
        }
    }

    /// Accept button should be disabled when submitting or not all required elements are checked.
    var acceptDisabled: Bool {
        isSubmitting || !areAllRequiredElementsChecked
    }

    var translatedNoticeText: String {
        guard let ac = activeConfig else { return "" }
        return getTranslatedText("notice_text", defaultText: ac.noticeText).strippingHTML()
    }

    var translatedAdditionalText: String {
        guard let ac = activeConfig else { return "" }
        return getTranslatedText("additional_text", defaultText: ac.additionalText).strippingHTML()
    }
}
