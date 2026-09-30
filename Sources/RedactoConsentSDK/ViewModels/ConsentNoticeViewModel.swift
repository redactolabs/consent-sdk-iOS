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

        // Action buttons, read in the order they are laid out.
        appendIfPresent("accept_all_button_text", urls: urls, queue: &queue)
        appendIfPresent("confirm_button_text", urls: urls, queue: &queue)
        appendIfPresent("decline_button_text", urls: urls, queue: &queue)

        return queue
    }
}

/// The two notice-body sections a collapsible layout draws as disclosures.
enum NoticeSection: Hashable {
    case about
    case dpo
}

/// Everything one accept submits, captured when the button is pressed so a
/// token swap that resets the notice cannot change what is sent.
struct PreparedAccept {
    let params: ConsentAPI.SubmitConsentEventParams
}

/// ViewModel for the modal RedactoNoticeConsent view.
/// Port of RedactoNoticeConsent.tsx state management and business logic.
@MainActor
public class ConsentNoticeViewModel: ObservableObject {
    // MARK: - Configuration
    var noticeId: String
    var accessToken: String
    var refreshToken: String
    let baseUrl: String?
    var ledgerBaseUrl: String?
    /// Resolved sandbox config, or nil for the JWT/live path.
    var sandbox: SandboxConfig?
    /// A sandbox config that failed to resolve (a non-empty sandbox token was
    /// supplied with a missing org/workspace/identity). Surfaced through `onError`
    /// from the load path — never synchronously during view construction.
    var sandboxConfigError: Error?
    let settings: ConsentSettings?
    /// The host's `language`: what the notice is read in. The visible language
    /// then follows the notice's default language.
    var initialLanguage: String
    let blockUI: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onError: ((Error) -> Void)?
    var applicationId: String?
    var validateAgainst: String
    var includeFullyConsentedData: Bool
    let reviewModeButtonText: String?
    let defaultOpenProducts: [String]?
    var otpGate: OtpGate?
    var otpFlow = OtpGateFlow()

    // MARK: - Published State
    @Published var content: ConsentContent?
    @Published var isLoading = true
    @Published var hasAlreadyConsented = false
    @Published var isSubmitting = false
    @Published var isSubmittingAccept = false
    @Published var selectedLanguage: String
    @Published var collapsedPurposes: [String: Bool] = [:]
    @Published var selectedPurposes: [String: Bool] = [:]
    @Published var selectedDataElements: [String: Bool] = [:]
    @Published var initialDataElementSelections: [String: Bool] = [:]
    @Published var collapsedProducts: [String: Bool] = [:]
    @Published var recordedPurposeSelections: [String: Bool] = [:]
    @Published var consentedProducts: [String: Bool] = [:]
    @Published var consentedPurposes: [String: Bool] = [:]
    /// The reconsent split; nil unless the server asks for reconsent.
    @Published var categorizedPurposes: CategorizedPurposes?
    /// A submit or guardian-gate failure, shown as a dismissible banner.
    @Published var errorMessage: String?
    /// The notice could not be read: the dialog replaces the notice.
    @Published var fetchErrorMessage: String?
    /// The host's props are unusable: nothing is read.
    @Published var configurationErrorMessage: String?
    @Published var isVisible = false
    @Published var otpPanel = OtpPanelState()
    @Published var pendingConfirmAction: ConfirmAction?
    @Published var openSections: Set<NoticeSection> = []
    /// The appearance last served for this notice, for the loading state.
    @Published var cachedAppearance: NoticeAppearance?

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
    private var ttsTask: Task<Void, Never>?

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
    var verificationReference: String?
    var selfDeclaredAdult = false
    var verificationSessionToken: String?
    var pollingTask: Task<Void, Never>?
    var guardianTask: Task<Void, Never>?
    var autoTransitionTask: Task<Void, Never>?
    /// Seams for tests: how DigiLocker is opened and how often it is polled.
    var openURL: (URL) async -> Bool = { url in await UIApplication.shared.open(url) }
    var pollIntervalNanos: UInt64 = 3_000_000_000

    // Language dropdown
    @Published var isLanguageDropdownOpen = false

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
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        sandbox: SandboxConfig? = nil,
        sandboxConfigError: Error? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        blockUI: Bool = true,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void,
        onError: ((Error) -> Void)? = nil,
        applicationId: String? = nil,
        validateAgainst: String = "all",
        includeFullyConsentedData: Bool = false,
        reviewModeButtonText: String? = nil,
        defaultOpenProducts: [String]? = nil,
        otpGate: OtpGate? = nil
    ) {
        self.noticeId = noticeId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = ledgerBaseUrl
        self.sandbox = sandbox
        self.sandboxConfigError = sandboxConfigError
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
        self.defaultOpenProducts = defaultOpenProducts
        self.otpGate = otpGate
        self.cachedAppearance = NoticeAppearanceCache.read(noticeId: noticeId)
    }

    deinit {
        fetchTask?.cancel()
        ttsTask?.cancel()
        pollingTask?.cancel()
        guardianTask?.cancel()
        autoTransitionTask?.cancel()
        audioPlayer?.pause()
        audioPlayer = nil
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Fetch Content

    @discardableResult
    func fetchContent(clearingCache: Bool = false) -> Task<Void, Never> {
        fetchTask?.cancel()
        let task = Task { [weak self] in
            if clearingCache {
                await ConsentAPI.clearCache()
            }
            guard let self else { return }
            await self.performFetch()
        }
        fetchTask = task
        return task
    }

    /// Why the host's props cannot be used, checked before anything is read.
    var propValidationError: String? {
        if noticeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NoticeErrorCopy.missingNoticeId
        }
        if let sandboxConfigError {
            return sandboxConfigError.localizedDescription
        }
        if sandbox == nil && accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NoticeErrorCopy.missingAccessToken
        }
        return nil
    }

    private func performFetch() async {
        isLoading = true
        fetchErrorMessage = nil
        showAgeVerification = false
        showGuardianForm = false

        if let invalid = propValidationError {
            configurationErrorMessage = invalid
            // Fail loud (deferred out of `init`) for a sandbox config the host
            // got wrong; the JWT/live path is unaffected.
            if let sandboxConfigError {
                onError?(sandboxConfigError)
            }
            isLoading = false
            return
        }
        configurationErrorMessage = nil

        do {
            let data = try await ConsentAPI.fetchConsentContent(.init(
                noticeId: noticeId,
                accessToken: accessToken,
                baseUrl: baseUrl,
                ledgerBaseUrl: ledgerBaseUrl,
                language: initialLanguage,
                specificUuid: applicationId,
                validateAgainst: validateAgainst,
                includeFullyConsentedData: includeFullyConsentedData,
                sandbox: sandbox
            ))

            if Task.isCancelled { return }

            let activeConfig = data.detail.activeConfig
            if let opening = NoticeTranslation.openingLanguage(defaultLanguage: activeConfig.defaultLanguage) {
                selectedLanguage = opening
            }

            seedSelectionState(from: data)
            content = data
            NoticeAppearanceCache.write(noticeId: activeConfig.noticeUuid, appearance: activeConfig.appearance)

            isMinor = data.detail.isMinor ?? false
            if isMinor {
                isMinorFlow = true
                showAgeVerification = true
            }

            isVisible = true
            isLoading = false
            refreshTTS()
        } catch {
            if Task.isCancelled { return }
            if (error as? RedactoAPIError)?.statusCode == 409 {
                hasAlreadyConsented = true
                isLoading = false
                onAccept()
                return
            }
            let message = error.localizedDescription
            fetchErrorMessage = message.isEmpty ? NoticeErrorCopy.fallback : message
            onError?(error)
            isLoading = false
        }
    }

    // MARK: - TTS

    /// Talkback restarts from nothing whenever the notice or its language
    /// changes: the old audio stops and the new language's is read.
    private var ttsLanguageCode: String?

    func refreshTTS() {
        ttsTask?.cancel()
        isTTSAvailable = false
        ttsAudioUrls = [:]
        stopAudio()
        guard let content else { return }
        let languageCode = NoticeTranslation.audioLanguage(selectedLanguage, config: content.detail.activeConfig)
        ttsLanguageCode = languageCode
        ttsTask = Task { [weak self] in
            await self?.fetchTTS(content: content, languageCode: languageCode)
        }
    }

    private func fetchTTS(content: ConsentContent, languageCode: String) async {
        do {
            let data = try await ConsentAPI.fetchTTSAudioUrls(.init(
                accessToken: accessToken,
                baseUrl: baseUrl,
                ledgerBaseUrl: ledgerBaseUrl,
                noticeUuid: content.detail.activeConfig.noticeUuid,
                language: languageCode,
                sandbox: sandbox
            ))
            if Task.isCancelled { return }

            var urls: [String: String] = [:]
            urls["notice_text"] = data.detail.noticeTextAudioUrl
            urls["additional_text"] = data.detail.additionalTextAudioUrl
            urls["notice_banner_heading"] = data.detail.noticeBannerHeadingAudioUrl
            urls["purpose_section_heading"] = data.detail.purposeSectionHeadingAudioUrl
            urls["privacy_policy_prefix_text"] = data.detail.privacyPolicyPrefixTextAudioUrl
            urls["privacy_policy_anchor_text"] = data.detail.privacyPolicyAnchorTextAudioUrl
            urls["privacy_center_anchor_text"] = data.detail.privacyCenterAnchorTextAudioUrl
            urls["accept_all_button_text"] = data.detail.acceptAllButtonTextAudioUrl
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
            isTTSAvailable = true
        } catch {
            if Task.isCancelled { return }
            #if DEBUG
            print("[RedactoConsentSDK] TTS fetch failed for language '\(languageCode)': \(error.localizedDescription)")
            #endif
            isTTSAvailable = false
        }
    }

    /// The purposes talkback reads, in the order they render.
    var ttsPurposes: [ActiveConfigPurpose] {
        if let categorizedPurposes {
            return categorizedPurposes.alreadyConsented + categorizedPurposes.needsConsent
        }
        return renderedPurposes
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
            purposes: ttsPurposes,
            hasAdditionalText: !ac.additionalText.isEmpty,
            hasPrivacyCenterUrl: !ac.privacyCenterUrl.isEmpty,
            hasDpoInfo: ac.dpoInfo != nil
        )
        guard !ttsQueue.isEmpty else { return }
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

        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.playNextInQueue() }
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

    var isTalkbackActive: Bool { isPlaying || isPaused }

    // MARK: - Notice sections

    /// Talkback reads the notice text and the DPO block, so both stay open for
    /// the whole session, paused included.
    func isSectionOpen(_ section: NoticeSection) -> Bool {
        openSections.contains(section) || isTalkbackActive
    }

    func toggleSection(_ section: NoticeSection) {
        guard !isTalkbackActive else { return }
        if openSections.contains(section) {
            openSections.remove(section)
        } else {
            openSections.insert(section)
        }
    }

    // MARK: - Translation Helper

    func getTranslatedText(_ key: String, defaultText: String, itemId: String? = nil) -> String {
        NoticeTranslation.text(activeConfig, language: selectedLanguage, key: key, defaultText: defaultText, itemId: itemId)
    }

    func getTranslatedDpoText(_ key: String, defaultText: String) -> String {
        NoticeTranslation.dpoText(activeConfig, language: selectedLanguage, key: key, defaultText: defaultText)
    }

    /// Called when selectedLanguage changes to re-fetch TTS audio.
    /// The read settles the notice on its default language, which lands here
    /// after the read already fetched that language's audio: only a different
    /// audio language needs a second request.
    func onLanguageChanged() {
        guard let content else { return }
        let languageCode = NoticeTranslation.audioLanguage(selectedLanguage, config: content.detail.activeConfig)
        guard languageCode != ttsLanguageCode else { return }
        refreshTTS()
    }

    /// A fully consented notice has nothing to submit: its one button hands
    /// control back to the host, as React's review-mode "Continue" does.
    func continueFromReview() {
        onAccept()
    }

    // MARK: - Purpose/Element Toggles

    private func autoExpandPurposeIfNeeded(for segmentKey: String) {
        guard let purposeUuid = purposeUUID(for: segmentKey) else {
            return
        }
        for key in rowKeys(forPurpose: purposeUuid) where collapsedPurposes[key] == true {
            collapsedPurposes[key] = false
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

    // MARK: - Submit

    /// Shared by all three accept buttons. The mode only decides which
    /// purposes/data elements are submitted — everything downstream, including
    /// the host's `onAccept` callback, is identical.
    func handleAccept(mode: AcceptMode = .selected) {
        guard let prepared = prepareAccept(mode: mode) else { return }
        submit(prepared)
    }

    /// Runs the gates an accept passes through and captures what it submits.
    /// Nil when a gate holds it (the OTP step, a missing guardian check).
    func prepareAccept(mode: AcceptMode) -> PreparedAccept? {
        guard let content else { return nil }
        if holdForOtp(mode) { return nil }

        if isMinorFlow && verificationReference == nil {
            errorMessage = NoticeCopy.minorVerificationRequired
            return nil
        }

        let rows = purposeRows
        let selection = ProductConsent.selectionForMode(
            rows: rows,
            mode: mode,
            current: SelectionState(
                selectedPurposes: selectedPurposes,
                selectedDataElements: selectedDataElements
            )
        )
        // Reflect the shortcut's selection in the checkboxes so the notice shows
        // what was sent if the request fails and it stays open.
        if mode != .selected {
            selectedPurposes = selection.selectedPurposes
            selectedDataElements = selection.selectedDataElements
        }

        let purposes = ProductConsent.submissionPurposes(
            rows: rows,
            selection: selection,
            mode: mode,
            recordedPurposeSelections: modificationBaseline,
            initialDataElementSelections: initialDataElementSelections
        )
        let specificUuid = applicationId.flatMap { $0.isEmpty ? nil : $0 }
        return PreparedAccept(params: ConsentAPI.SubmitConsentEventParams(
            accessToken: accessToken,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            noticeUuid: content.detail.activeConfig.noticeUuid,
            purposes: purposes,
            declined: false,
            language: NoticeLanguageCodes.toBcp47Code(selectedLanguage),
            metaData: specificUuid.map { MetaData(specificUuid: $0) },
            guardianVerificationReference: verificationReference,
            selfDeclaredAdult: selfDeclaredAdult ? true : nil,
            sandbox: sandbox
        ))
    }

    func submit(_ prepared: PreparedAccept) {
        isSubmitting = true
        isSubmittingAccept = true
        errorMessage = nil

        Task { [weak self] in
            do {
                try await ConsentAPI.submitConsentEvent(prepared.params)
                guard let self else { return }
                self.stopAudio()
                await ConsentAPI.clearCache()
                self.isVisible = false
                self.onAccept()
            } catch {
                guard let self else { return }
                let message = error.localizedDescription
                self.errorMessage = message.isEmpty ? NoticeCopy.submitFailed : message
                self.onError?(error)
            }
            self?.isSubmitting = false
            self?.isSubmittingAccept = false
        }
    }

    func handleDecline() {
        stopPolling()
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        stopAudio()
        otpPanel = OtpPanelState()
        isVisible = false
        onDecline()
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
        return NoticeTranslation.supportedLanguages(ac)
    }

    /// Accept button should be disabled when submitting or not all required elements are checked.
    var acceptDisabled: Bool {
        isSubmitting || !confirmVerdict.ok
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
