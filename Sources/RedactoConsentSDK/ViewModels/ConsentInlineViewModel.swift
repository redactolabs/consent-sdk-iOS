import Foundation
import SwiftUI

/// ViewModel for the inline RedactoNoticeConsentInline view.
/// Port of RedactoNoticeConsentInline.tsx state management.
@MainActor
public class ConsentInlineViewModel: ObservableObject {
    // MARK: - Configuration
    private(set) var orgUuid: String
    private(set) var workspaceUuid: String
    private(set) var noticeUuid: String
    var accessToken: String?
    let baseUrl: String?
    let ledgerBaseUrl: String?
    private(set) var initialLanguage: String
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    let onError: ((Error) -> Void)?
    let onValidationChange: ((Bool) -> Void)?
    let settings: ConsentSettings?
    private(set) var applicationId: String?

    // MARK: - Published State
    @Published var activeConfig: ActiveConfig?
    @Published var isLoading = true
    @Published var isSubmitting = false
    @Published var selectedLanguage: String
    @Published var collapsedPurposes: [String: Bool] = [:]
    @Published var selectedPurposes: [String: Bool] = [:]
    @Published var selectedDataElements: [String: Bool] = [:]
    @Published var hasAlreadyConsented = false
    @Published var fetchError: Error?
    @Published var errorMessage: String?

    private var hasSubmitted = false
    var isCheckingConsent = false
    var autoSubmitDeferredByConsentCheck = false
    private var lastSubmissionKey: String?
    /// Bumped whenever the principal or the consent changes; a submit that
    /// finishes under an older generation belongs to someone else.
    private var submissionGeneration = 0
    private var lastReportedValidity: Bool?
    private var hasStartedFetch = false
    private var fetchTask: Task<Void, Never>?
    private(set) var submitTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        orgUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        accessToken: String? = nil,
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        language: String = "en",
        onAccept: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onValidationChange: ((Bool) -> Void)? = nil,
        settings: ConsentSettings? = nil,
        applicationId: String? = nil
    ) {
        self.orgUuid = orgUuid
        self.workspaceUuid = workspaceUuid
        self.noticeUuid = noticeUuid
        self.accessToken = accessToken
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = ledgerBaseUrl
        self.isCheckingConsent = ConsentInlineViewModel.runsLedgerConsentCheck(ledgerBaseUrl: ledgerBaseUrl, applicationId: applicationId)
        self.initialLanguage = language
        self.selectedLanguage = language
        self.onAccept = onAccept
        self.onDecline = onDecline
        self.onError = onError
        self.onValidationChange = onValidationChange
        self.settings = settings
        self.applicationId = applicationId
    }

    deinit {
        fetchTask?.cancel()
    }

    // MARK: - Validation

    var purposeRows: [NoticePurposeRow] {
        activeConfig.map(InlineSelection.inlinePurposeRows) ?? []
    }

    var productGroups: [ProductPurposeGroup] {
        activeConfig.map(InlineSelection.productGroups) ?? []
    }

    var areAllRequiredElementsChecked: Bool {
        guard activeConfig != nil else { return false }
        return InlineSelection.allRequiredElementsChecked(purposeRows, selectedDataElements)
    }

    var acceptDisabled: Bool {
        isSubmitting || !areAllRequiredElementsChecked || (accessToken ?? "").isEmpty
    }

    // MARK: - Fetch Notice

    /// `.onAppear` fires again whenever the view re-enters the hierarchy (a List
    /// row scrolling back, a navigation pop); re-reading there would wipe the
    /// reader's ticks. React reads once per identity, and so does this.
    func fetchNoticeIfNeeded() {
        guard !hasStartedFetch else { return }
        fetchNotice()
    }

    @discardableResult
    func fetchNotice() -> Task<Void, Never> {
        hasStartedFetch = true
        fetchTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
        fetchTask = task
        return task
    }

    private func performFetch() async {
        isLoading = true
        fetchError = nil
        hasAlreadyConsented = false
        isCheckingConsent = Self.runsLedgerConsentCheck(ledgerBaseUrl: ledgerBaseUrl, applicationId: applicationId)
        autoSubmitDeferredByConsentCheck = false

        do {
            let consentContentData = try await ConsentAPI.fetchInlineConsentContent(.init(
                orgUuid: orgUuid,
                workspaceUuid: workspaceUuid,
                noticeUuid: noticeUuid,
                accessToken: accessToken,
                baseUrl: baseUrl,
                language: initialLanguage,
                specificUuid: applicationId,
                ledgerBaseUrl: ledgerBaseUrl
            ))

            if Task.isCancelled { return }

            applyConfig(consentContentData.detail.activeConfig)
            checkValidationAndAutoSubmit()
        } catch let error as RedactoAPIError {
            if Task.isCancelled { return }
            fetchError = error
            if error.statusCode == 409 {
                hasAlreadyConsented = true
                onAccept?()
            } else {
                onError?(error)
            }
        } catch {
            if Task.isCancelled { return }
            fetchError = error
            onError?(error)
        }

        if !Task.isCancelled {
            isLoading = false
        }
        if !Task.isCancelled, fetchError == nil {
            await checkLedgerConsent()
        }
    }

    func applyConfig(_ config: ActiveConfig) {
        activeConfig = config

        if !config.defaultLanguage.isEmpty {
            selectedLanguage = config.defaultLanguage
        }

        let rows = InlineSelection.inlinePurposeRows(config)
        let selection = InlineSelection.initialSelection(
            rows, preselection: PurposePreselectionLogic.resolve(config.purposePreselection)
        )
        collapsedPurposes = InlineSelection.initialCollapsedPurposes(rows)
        selectedDataElements = selection.selectedDataElements
        selectedPurposes = selection.selectedPurposes
    }

    // MARK: - Translation

    /// React inline's `getTranslatedText` (tsx ~191-260): English reads the
    /// base copy, save the privacy policy anchor the notice names.
    func getTranslatedText(_ key: String, defaultText: String, itemId: String? = nil) -> String {
        guard let ac = activeConfig else { return defaultText }
        if NoticeTranslation.isEnglish(selectedLanguage) {
            if key == "privacy_policy_anchor_text", !ac.privacyPolicyAnchorText.isEmpty {
                return ac.privacyPolicyAnchorText
            }
            return defaultText
        }
        return NoticeTranslation.text(ac, language: selectedLanguage, key: key, defaultText: defaultText, itemId: itemId)
    }

    // MARK: - Appearance

    /// The console appearance under the host's `settings`
    /// (`useNoticeAppearance(content?.appearance, settings)`, tsx ~105).
    func appearance(colorScheme: ColorScheme) -> ResolvedNoticeAppearance {
        NoticeAppearance.resolve(console: activeConfig?.appearance, settings: settings, colorScheme: colorScheme)
    }

    /// The host's `settings.font`, then the console's `font_preference`.
    var noticeFontFamily: String? {
        NoticeFontResolver.resolve(
            hostFont: settings?.font,
            noticeFont: activeConfig?.fontPreference,
            installed: NoticeFontResolver.installedFamily
        )
    }

    // MARK: - Toggles

    func handlePurposeToggle(_ purposeUuid: String, productUuid: String? = nil) {
        guard let ac = activeConfig,
              let purpose = ac.purposes.first(where: { $0.uuid == purposeUuid }) else { return }

        let key = ProductMatrix.productPurposeKey(productUuid, purposeUuid)
        let newState = !(selectedPurposes[key] ?? false)
        selectedPurposes[key] = newState
        selectedDataElements = InlineSelection.withPurposeElements(purpose, productUuid, newState, selectedDataElements)

        checkValidationAndAutoSubmit()
    }

    func handlePurposeCollapse(_ purposeUuid: String, productUuid: String? = nil) {
        let key = ProductMatrix.productPurposeKey(productUuid, purposeUuid)
        collapsedPurposes[key] = !(collapsedPurposes[key] ?? true)
    }

    func handleDataElementToggle(_ elementUuid: String, purposeUuid: String, productUuid: String? = nil) {
        guard let ac = activeConfig,
              let purpose = ac.purposes.first(where: { $0.uuid == purposeUuid }) else { return }

        let toggled = InlineSelection.toggleDataElement(purpose, elementUuid, productUuid, selectedDataElements)
        selectedDataElements = toggled.selectedDataElements
        selectedPurposes[ProductMatrix.productPurposeKey(productUuid, purposeUuid)] = toggled.purposeSelected

        checkValidationAndAutoSubmit()
    }

    // MARK: - Validation & Auto-Submit

    func checkValidationAndAutoSubmit() {
        let isValid = areAllRequiredElementsChecked
        if isValid != lastReportedValidity {
            lastReportedValidity = isValid
            onValidationChange?(isValid)
        }
        autoSubmitIfReady()
    }

    private func autoSubmitIfReady() {
        // Auto-submit when token is available and all required elements are checked
        guard let token = accessToken, !token.isEmpty,
              let ac = activeConfig,
              areAllRequiredElementsChecked,
              !isSubmitting,
              !hasSubmitted,
              !hasAlreadyConsented else { return }
        if isCheckingConsent {
            autoSubmitDeferredByConsentCheck = true
            return
        }

        let selection = SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
        let key = InlineSelection.inlineSubmissionKey(token: token, configUuid: ac.uuid, selection: selection)
        guard key != lastSubmissionKey else { return }

        hasSubmitted = true
        lastSubmissionKey = key
        let generation = submissionGeneration
        submitTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.submitConsent(ac, token: token, selection: selection, generation: generation)
            } catch {
                self.hasSubmitted = false
                self.onError?(error)
            }
            self.submitTask = nil
            self.autoSubmitIfReady()
        }
    }

    /// A new token is a new principal: re-read, so its 409 and ledger check
    /// govern, as React's fetch effect does on every `accessToken` change.
    @discardableResult
    func updateAccessToken(_ token: String?) -> Task<Void, Never>? {
        guard token != accessToken else { return nil }
        accessToken = token
        submissionGeneration += 1
        hasSubmitted = false
        if (token ?? "").isEmpty {
            checkValidationAndAutoSubmit()
            return nil
        }
        return fetchNotice()
    }

    /// A host that swaps the notice, application or language on a mounted view
    /// is asking about a different consent: drop the previous one's acceptance
    /// and submission state and read again.
    @discardableResult
    func updateIdentity(_ identity: InlineNoticeIdentity) -> Task<Void, Never>? {
        guard identity != self.identity else { return nil }
        orgUuid = identity.orgUuid
        workspaceUuid = identity.workspaceUuid
        noticeUuid = identity.noticeUuid
        initialLanguage = identity.language
        selectedLanguage = identity.language
        applicationId = identity.applicationId
        submissionGeneration += 1
        // A failed re-read must leave nothing of the previous consent to submit.
        activeConfig = nil
        selectedPurposes = [:]
        selectedDataElements = [:]
        hasSubmitted = false
        lastSubmissionKey = nil
        return fetchNotice()
    }

    var identity: InlineNoticeIdentity {
        InlineNoticeIdentity(
            orgUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            language: initialLanguage,
            applicationId: applicationId
        )
    }

    // MARK: - Submit

    /// A completion from an earlier generation only releases `isSubmitting`:
    /// no callback, no error, and the caller's `autoSubmitIfReady()` then lets
    /// the current principal's own submission through.
    private func submitConsent(
        _ ac: ActiveConfig,
        token: String,
        selection: SelectionState,
        generation: Int
    ) async throws {
        guard generation == submissionGeneration else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let purposes = InlineSelection.buildInlineSubmitPurposes(InlineSelection.inlinePurposeRows(ac), selection)

            try await ConsentAPI.submitConsentEvent(.init(
                accessToken: token,
                baseUrl: baseUrl,
                ledgerBaseUrl: ledgerBaseUrl,
                noticeUuid: ac.noticeUuid,
                purposes: purposes,
                declined: false,
                metaData: applicationId.map { MetaData(specificUuid: $0) },
                orgUuid: orgUuid,
                workspaceUuid: workspaceUuid
            ))
        } catch {
            isSubmitting = false
            guard generation == submissionGeneration else { return }
            errorMessage = error.localizedDescription
            hasSubmitted = false
            throw error
        }

        guard generation == submissionGeneration else {
            isSubmitting = false
            return
        }
        onAccept?()
        hasSubmitted = false
        isSubmitting = false
    }
}
