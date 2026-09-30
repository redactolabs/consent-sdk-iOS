import Foundation
import SwiftUI

/// What an assisted notice reads. A change to any of it is a new read, as the
/// fetch effect's dependencies are in React (tsx ~443).
struct AssistedNoticeIdentity: Equatable {
    let organisationUuid: String
    let workspaceUuid: String
    let noticeUuid: String
    let baseUrl: String?
}

/// Port of React's `RedactoNoticeAssisted.tsx` state. Selection is keyed per
/// purpose, over a flat list in product order.
@MainActor
final class AssistedNoticeViewModel: ObservableObject {
    private(set) var organisationUuid: String
    private(set) var workspaceUuid: String
    private(set) var noticeUuid: String
    private(set) var baseUrl: String?
    let ledgerBaseUrl: String?
    let settings: ConsentSettings?
    let onComplete: (() -> Void)?
    let onDecline: (() -> Void)?
    let onError: ((Error) -> Void)?

    @Published private(set) var activeConfig: ActiveConfig?
    @Published private(set) var isLoading = true
    @Published private(set) var fetchErrorMessage: String?
    @Published private(set) var step: AssistedStep = .notice
    @Published private(set) var acceptMode: AcceptMode = .selected
    @Published private(set) var selectedPurposes: [String: Bool] = [:]
    @Published private(set) var selectedDataElements: [String: Bool] = [:]
    @Published private(set) var collapsedPurposes: [String: Bool] = [:]
    @Published private(set) var selectedLanguage = "English"
    @Published private(set) var verifyMethod: AssistedVerifyMethod = .mobile
    @Published private(set) var mobile = ""
    @Published private(set) var email = ""
    @Published private(set) var otpSent = false
    @Published private(set) var otpUuid = ""
    @Published private(set) var otpDigits = OtpCodeEntry.empty(length: AssistedConfig.otpLength)
    @Published private(set) var resendCountdown = 0
    @Published private(set) var isSendingOtp = false
    @Published private(set) var isVerifying = false
    @Published private(set) var createError: String?
    @Published private(set) var otpError: String?

    // Narration (React tsx ~800-1144).
    @Published private(set) var ttsAudio: TTSAudioDetail?
    @Published private(set) var isTTSAvailable = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentAudioIndex = 0
    @Published private(set) var highlightedElementId: String?

    private var verifiedSession: VerifiedOtpSession?
    private var fetchTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private(set) var narrationTask: Task<Void, Never>?
    private let audioPlayer: AssistedAudioPlaying

    init(
        organisationUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        onComplete: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        audioPlayer: AssistedAudioPlaying? = nil
    ) {
        self.organisationUuid = organisationUuid
        self.workspaceUuid = workspaceUuid
        self.noticeUuid = noticeUuid
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = ledgerBaseUrl
        self.settings = settings
        self.onComplete = onComplete
        self.onDecline = onDecline
        self.onError = onError
        self.audioPlayer = audioPlayer ?? AssistedAVAudioPlayer()
    }

    deinit {
        fetchTask?.cancel()
        countdownTask?.cancel()
        narrationTask?.cancel()
    }

    var identity: AssistedNoticeIdentity {
        AssistedNoticeIdentity(
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            baseUrl: baseUrl
        )
    }

    /// The flow's own copy in the notice's language.
    var ts: AssistedI18n {
        AssistedI18n(language: selectedLanguage)
    }

    var displayedPurposes: [ActiveConfigPurpose] {
        activeConfig.map(AssistedNotice.displayedPurposes) ?? []
    }

    var areAllRequiredElementsChecked: Bool {
        guard activeConfig != nil else { return false }
        return AssistedNotice.allRequiredElementsChecked(displayedPurposes, selectedDataElements)
    }

    var isContactValid: Bool {
        switch verifyMethod {
        case .mobile: return AssistedFlow.isValidMobile(mobile)
        case .email: return AssistedFlow.isValidEmail(email)
        }
    }

    var otpCode: String {
        OtpCodeEntry.code(of: otpDigits)
    }

    var isOtpComplete: Bool {
        OtpCodeEntry.isComplete(otpDigits)
    }

    var isLocked: Bool {
        step == .verify
    }

    var primaryAction: AssistedPrimaryAction {
        guard step == .verify else { return .acceptSelected }
        return otpSent ? .confirmOtp : .sendOtp
    }

    var isPrimaryDisabled: Bool {
        switch primaryAction {
        case .acceptSelected: return !areAllRequiredElementsChecked
        case .sendOtp: return !isContactValid || isSendingOtp
        case .confirmOtp: return !isOtpComplete || isVerifying
        }
    }

    var otpRecipientLabel: String {
        switch verifyMethod {
        case .mobile: return "\(AssistedConfig.dialCode) \(mobile)"
        case .email: return email
        }
    }

    // MARK: - Load

    @discardableResult
    func loadIfNeeded() -> Task<Void, Never>? {
        guard activeConfig == nil, fetchTask == nil else { return nil }
        return load()
    }

    @discardableResult
    func load() -> Task<Void, Never> {
        fetchTask?.cancel()
        isLoading = true
        fetchErrorMessage = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
        fetchTask = task
        return task
    }

    /// A host that points a mounted flow at another notice, workspace,
    /// organisation or host gets that notice read afresh.
    @discardableResult
    func updateIdentity(_ identity: AssistedNoticeIdentity) -> Task<Void, Never>? {
        guard identity != self.identity else { return nil }
        organisationUuid = identity.organisationUuid
        workspaceUuid = identity.workspaceUuid
        noticeUuid = identity.noticeUuid
        baseUrl = identity.baseUrl
        return load()
    }

    private func performFetch() async {
        do {
            let content = try await AssistedAPI.fetchAssistedNotice(
                organisationUuid: organisationUuid,
                workspaceUuid: workspaceUuid,
                noticeUuid: noticeUuid,
                baseUrl: baseUrl
            )
            if Task.isCancelled { return }
            applyConfig(content.detail.activeConfig)
        } catch {
            if Task.isCancelled || isCancellationError(error) { return }
            fetchErrorMessage = Self.loadFailureMessage(error)
            onError?(error)
        }
        isLoading = false
    }

    static func loadFailureMessage(_ error: Error) -> String {
        if case .api(_, _, let message)? = error as? RedactoAPIError {
            return message
        }
        return APIErrorFallback.noticeRead
    }

    func applyConfig(_ config: ActiveConfig) {
        activeConfig = config
        selectedLanguage = AssistedNotice.initialLanguage(config)
        let selection = AssistedNotice.initialSelection(config)
        selectedPurposes = selection.selectedPurposes
        selectedDataElements = selection.selectedDataElements
        collapsedPurposes = AssistedNotice.initialCollapsed(config)
        isLoading = false
        fetchNarration()
    }

    // MARK: - Language

    var supportedLanguages: [String] {
        guard let config = activeConfig else { return [selectedLanguage] }
        return NoticeTranslation.supportedLanguages(config)
    }

    func selectLanguage(_ language: String) {
        guard language != selectedLanguage else { return }
        selectedLanguage = language
        fetchNarration()
    }

    func getTranslatedText(_ key: String, defaultText: String, itemId: String? = nil) -> String {
        AssistedNotice.text(activeConfig, language: selectedLanguage, key: key, fallback: defaultText, itemId: itemId)
    }

    func getTranslatedDpoText(_ key: String, defaultText: String) -> String {
        NoticeTranslation.dpoText(activeConfig, language: selectedLanguage, key: key, defaultText: defaultText)
    }

    // MARK: - Selection

    func handlePurposeToggle(_ purposeUuid: String) {
        guard !isLocked,
              let purpose = activeConfig?.purposes.first(where: { $0.uuid == purposeUuid }) else { return }
        let next = !(selectedPurposes[purposeUuid] ?? false)
        selectedPurposes[purposeUuid] = next
        selectedDataElements = InlineSelection.withPurposeElements(purpose, nil, next, selectedDataElements)
    }

    func handlePurposeCollapse(_ purposeUuid: String) {
        collapsedPurposes[purposeUuid] = !(collapsedPurposes[purposeUuid] ?? false)
    }

    func handleDataElementToggle(_ elementUuid: String, purposeUuid: String) {
        guard !isLocked,
              let purpose = activeConfig?.purposes.first(where: { $0.uuid == purposeUuid }) else { return }
        let toggled = InlineSelection.toggleDataElement(purpose, elementUuid, nil, selectedDataElements)
        selectedDataElements = toggled.selectedDataElements
        selectedPurposes[purposeUuid] = toggled.purposeSelected
    }

    func acceptSelected() {
        guard step == .notice, areAllRequiredElementsChecked else { return }
        enterVerify(.selected)
    }

    func acceptAll() {
        guard step == .notice, let config = activeConfig else { return }
        let rows = config.purposes.map { NoticePurposeRow(purpose: $0, productUuid: nil) }
        let selection = ProductConsent.selectionForMode(rows: rows, mode: .all, current: currentSelection)
        selectedPurposes = selection.selectedPurposes
        selectedDataElements = selection.selectedDataElements
        enterVerify(.all)
    }

    private func enterVerify(_ mode: AcceptMode) {
        acceptMode = mode
        stopAudio()
        step = .verify
        otpSent = false
    }

    func editSelections() {
        guard !isVerifying else { return }
        acceptMode = .selected
        step = .notice
        mobile = ""
        email = ""
        resetOtpSession()
    }

    // MARK: - Contact and code

    func selectMethod(_ method: AssistedVerifyMethod) {
        guard !otpSent, !isSendingOtp else { return }
        verifyMethod = method
        createError = nil
    }

    func setMobile(_ raw: String) {
        guard !otpSent, !isSendingOtp else { return }
        mobile = AssistedFlow.sanitizeMobile(raw)
    }

    func setEmail(_ raw: String) {
        guard !otpSent, !isSendingOtp else { return }
        email = raw
    }

    func setOtpCode(_ raw: String) {
        setOtpDigits(AssistedFlow.digits(of: AssistedFlow.sanitizeOtp(raw)))
    }

    func setOtpDigits(_ digits: [String]) {
        guard otpSent, !isVerifying, digits.count == AssistedConfig.otpLength else { return }
        otpDigits = digits
    }

    @discardableResult
    func sendOtp() -> Task<Void, Never>? {
        guard step == .verify, !otpSent, isContactValid, !isSendingOtp else { return nil }
        return requestOtp()
    }

    @discardableResult
    func resendOtp() -> Task<Void, Never>? {
        guard step == .verify, otpSent, resendCountdown == 0, !isSendingOtp, !isVerifying else { return nil }
        return requestOtp()
    }

    private func requestOtp() -> Task<Void, Never> {
        createError = nil
        isSendingOtp = true
        let recipient = AssistedFlow.otpRecipient(verifyMethod, mobile: mobile, email: email)
        let channel = AssistedFlow.otpChannel(verifyMethod)
        return Task { [weak self] in
            guard let self else { return }
            do {
                let detail = try await AssistedAPI.createOtp(
                    organisationUuid: self.organisationUuid,
                    workspaceUuid: self.workspaceUuid,
                    to: recipient,
                    channel: channel,
                    baseUrl: self.baseUrl
                )
                self.otpUuid = detail.uuid
                self.otpDigits = OtpCodeEntry.empty(length: AssistedConfig.otpLength)
                self.otpError = nil
                self.otpSent = true
                self.startResendCountdown()
            } catch {
                self.createError = self.ts(.otpSendFailed)
            }
            self.isSendingOtp = false
        }
    }

    func changeContact() {
        guard !isVerifying else { return }
        resetOtpSession()
    }

    func tickResendCountdown() {
        if resendCountdown > 0 {
            resendCountdown -= 1
        }
    }

    private func startResendCountdown() {
        countdownTask?.cancel()
        resendCountdown = AssistedConfig.resendSeconds
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.tickResendCountdown()
                if self.resendCountdown == 0 { return }
            }
        }
    }

    private func resetOtpSession() {
        verifiedSession = nil
        countdownTask?.cancel()
        countdownTask = nil
        otpSent = false
        otpUuid = ""
        otpDigits = OtpCodeEntry.empty(length: AssistedConfig.otpLength)
        resendCountdown = 0
        createError = nil
        otpError = nil
    }

    // MARK: - Verify and submit

    @discardableResult
    func confirmOtp() -> Task<Void, Never>? {
        guard step == .verify, otpSent, !otpUuid.isEmpty, isOtpComplete, !isVerifying,
              let config = activeConfig else { return nil }
        otpError = nil
        isVerifying = true
        let sessionUuid = otpUuid
        let code = otpCode
        let purposes = AssistedFlow.submitPurposes(config.purposes, mode: acceptMode, current: currentSelection)
        let language = NoticeLanguageCodes.toBcp47Code(selectedLanguage)
        return Task {
            await self.verifyAndSubmit(
                config: config,
                sessionUuid: sessionUuid,
                code: code,
                purposes: purposes,
                language: language
            )
            self.isVerifying = false
        }
    }

    private func verifyAndSubmit(
        config: ActiveConfig,
        sessionUuid: String,
        code: String,
        purposes: [Purpose],
        language: String
    ) async {
        let token: String
        if let verified = verifiedSession, verified.uuid == sessionUuid {
            token = verified.token
        } else {
            do {
                let detail = try await AssistedAPI.verifyOtp(
                    organisationUuid: organisationUuid,
                    workspaceUuid: workspaceUuid,
                    uuid: sessionUuid,
                    otp: code,
                    baseUrl: baseUrl
                )
                guard let accessToken = detail.accessToken, !accessToken.isEmpty else {
                    otpError = ts(.otpVerifyFailed)
                    return
                }
                token = accessToken
                verifiedSession = VerifiedOtpSession(uuid: sessionUuid, token: accessToken)
            } catch {
                otpError = AssistedFlow.verifyErrorMessage(error, ts)
                return
            }
        }

        let status = await ConsentAPI.fetchNoticeConsentStatus(NoticeConsentStatusParams(
            accessToken: token,
            ledgerBaseUrl: ledgerBaseUrl,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: config.noticeUuid
        ))
        if status?.isFullyConsented == true {
            handleSuccess()
            return
        }

        do {
            try await AssistedAPI.submitAssistedConsent(
                accessToken: token,
                organisationUuid: organisationUuid,
                workspaceUuid: workspaceUuid,
                baseUrl: baseUrl,
                ledgerBaseUrl: ledgerBaseUrl,
                noticeUuid: config.noticeUuid,
                purposes: purposes,
                language: language
            )
            handleSuccess()
        } catch {
            if AssistedFlow.isConsentAlreadyProvided(error) {
                handleSuccess()
                return
            }
            otpError = ts(.otpVerifyFailed)
        }
    }

    private func handleSuccess() {
        if let onComplete {
            onComplete()
            return
        }
        resetFlow()
    }

    func decline() {
        if let onDecline {
            onDecline()
            return
        }
        resetFlow()
    }

    /// Replays the flow from the start: the ticks come back from the notice's
    /// pre-selection mode, as a fresh load seeds them (tsx ~1332-1349).
    private func resetFlow() {
        step = .notice
        if let config = activeConfig {
            let selection = AssistedNotice.initialSelection(config)
            selectedPurposes = selection.selectedPurposes
            selectedDataElements = selection.selectedDataElements
        }
        verifyMethod = .mobile
        mobile = ""
        email = ""
        resetOtpSession()
    }

    private var currentSelection: SelectionState {
        SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
    }

    // MARK: - Narration

    var narrationSequence: [AssistedNarrationClip] {
        guard let ttsAudio, let config = activeConfig else { return [] }
        return AssistedNarration.sequence(ttsAudio, config: config, purposes: displayedPurposes)
    }

    /// The narration speaker shows on the notice step only.
    var showsSpeaker: Bool {
        isTTSAvailable && step == .notice
    }

    var isNarrating: Bool {
        isPlaying && !isPaused
    }

    /// The element the playing clip reads; nothing is highlighted while paused.
    func isHighlighted(_ elementId: String) -> Bool {
        isPlaying && highlightedElementId == elementId
    }

    /// Re-read the clips for the notice in the selected language. A failure
    /// only hides the speaker: narration must never break the notice.
    @discardableResult
    func fetchNarration() -> Task<Void, Never>? {
        narrationTask?.cancel()
        narrationTask = nil
        isTTSAvailable = false
        ttsAudio = nil
        stopAudio()
        guard let config = activeConfig, !config.noticeUuid.isEmpty else { return nil }
        let language = selectedLanguage
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await AssistedAPI.fetchAssistedTTSAudioUrls(
                    organisationUuid: self.organisationUuid,
                    workspaceUuid: self.workspaceUuid,
                    noticeUuid: config.noticeUuid,
                    language: language,
                    baseUrl: self.baseUrl
                )
                if Task.isCancelled { return }
                self.ttsAudio = response.detail
                self.isTTSAvailable = true
            } catch {
                if Task.isCancelled || isCancellationError(error) { return }
                self.ttsAudio = nil
                self.isTTSAvailable = false
            }
        }
        narrationTask = task
        return task
    }

    func toggleAudio() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }

    private func playAudio() {
        guard !narrationSequence.isEmpty else { return }
        if isPaused {
            audioPlayer.resume()
            isPlaying = true
            isPaused = false
        } else {
            playClip(at: 0)
        }
    }

    private func pauseAudio() {
        guard isPlaying else { return }
        audioPlayer.pause()
        isPlaying = false
        isPaused = true
    }

    func stopAudio() {
        audioPlayer.stop()
        isPlaying = false
        isPaused = false
        currentAudioIndex = 0
        highlightedElementId = nil
    }

    private func playClip(at index: Int) {
        let sequence = narrationSequence
        guard index < sequence.count else {
            stopAudio()
            return
        }
        let clip = sequence[index]
        currentAudioIndex = index
        isPlaying = true
        isPaused = false
        highlightedElementId = clip.elementId
        if let purpose = AssistedNarration.purpose(for: clip.elementId, in: displayedPurposes),
           collapsedPurposes[purpose.uuid] == true {
            collapsedPurposes[purpose.uuid] = false
        }

        let next: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            self.playClip(at: index + 1)
        }
        guard let url = URL(string: clip.url) else {
            next()
            return
        }
        audioPlayer.play(url: url, onEnd: next, onError: next)
    }
}
