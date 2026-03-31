import Foundation
import SwiftUI

/// ViewModel for the inline RedactoNoticeConsentInline view.
/// Port of RedactoNoticeConsentInline.tsx state management.
@MainActor
public class ConsentInlineViewModel: ObservableObject {
    // MARK: - Configuration
    let orgUuid: String
    let workspaceUuid: String
    let noticeUuid: String
    var accessToken: String?
    let baseUrl: String?
    let initialLanguage: String
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    let onError: ((Error) -> Void)?
    let onValidationChange: ((Bool) -> Void)?
    let settings: ConsentSettings?
    let applicationId: String?

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
    @Published var isLanguageDropdownOpen = false

    private var hasSubmitted = false
    private var fetchTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        orgUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        accessToken: String? = nil,
        baseUrl: String? = nil,
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

    var areAllRequiredElementsChecked: Bool {
        guard let ac = activeConfig else { return false }
        return ac.purposes.allSatisfy { purpose in
            let requiredElements = purpose.dataElements.filter { $0.required }
            return requiredElements.allSatisfy { el in
                selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false
            }
        }
    }

    var acceptDisabled: Bool {
        isSubmitting || !areAllRequiredElementsChecked || (accessToken ?? "").isEmpty
    }

    // MARK: - Fetch Notice

    func fetchNotice() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
    }

    private func performFetch() async {
        isLoading = true
        fetchError = nil

        do {
            let consentContentData = try await ConsentAPI.fetchInlineConsentContent(.init(
                orgUuid: orgUuid,
                workspaceUuid: workspaceUuid,
                noticeUuid: noticeUuid,
                baseUrl: baseUrl,
                language: initialLanguage,
                specificUuid: applicationId
            ))

            if Task.isCancelled { return }

            let config = consentContentData.detail.activeConfig
            activeConfig = config

            if !config.defaultLanguage.isEmpty {
                selectedLanguage = config.defaultLanguage
            }

            var initialCollapsed: [String: Bool] = [:]
            var initialDataElementState: [String: Bool] = [:]
            var initialPurposeState: [String: Bool] = [:]

            for purpose in config.purposes {
                initialCollapsed[purpose.uuid] = true
                initialPurposeState[purpose.uuid] = false
                for el in purpose.dataElements {
                    initialDataElementState["\(purpose.uuid)-\(el.uuid)"] = false
                }
            }

            collapsedPurposes = initialCollapsed
            selectedDataElements = initialDataElementState
            selectedPurposes = initialPurposeState

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
    }

    // MARK: - Translation

    func getTranslatedText(_ key: String, defaultText: String, itemId: String? = nil) -> String {
        guard let ac = activeConfig else { return defaultText }
        guard let translationMap = ac.supportedLanguagesAndTranslations[selectedLanguage] else {
            return defaultText
        }

        if let itemId {
            if key == "purposes.name" || key == "purposes.description" {
                if let purposeData = translationMap.purposes?[itemId] {
                    switch purposeData {
                    case .name(let str):
                        return key == "purposes.name" ? str : defaultText
                    case .full(let name, let description):
                        return key == "purposes.name" ? name : description
                    }
                }
                return defaultText
            }
            if key.hasPrefix("data_elements.") {
                return translationMap.dataElements?[itemId] ?? defaultText
            }
        }

        if let value = translationMap.value(forKey: key), !value.isEmpty {
            return value
        }
        return defaultText
    }

    // MARK: - Toggles

    func handlePurposeToggle(_ purposeUuid: String) {
        guard let ac = activeConfig,
              let purpose = ac.purposes.first(where: { $0.uuid == purposeUuid }) else { return }

        let newState = !(selectedPurposes[purposeUuid] ?? false)
        selectedPurposes[purposeUuid] = newState

        for el in purpose.dataElements {
            selectedDataElements["\(purposeUuid)-\(el.uuid)"] = newState
        }

        checkValidationAndAutoSubmit()
    }

    func handlePurposeCollapse(_ purposeUuid: String) {
        collapsedPurposes[purposeUuid] = !(collapsedPurposes[purposeUuid] ?? true)
    }

    func handleDataElementToggle(_ elementUuid: String, purposeUuid: String) {
        guard let ac = activeConfig,
              let purpose = ac.purposes.first(where: { $0.uuid == purposeUuid }) else { return }

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

        checkValidationAndAutoSubmit()
    }

    // MARK: - Validation & Auto-Submit

    func checkValidationAndAutoSubmit() {
        let isValid = areAllRequiredElementsChecked
        onValidationChange?(isValid)

        // Auto-submit when token is available and all required elements are checked
        guard let token = accessToken, !token.isEmpty,
              activeConfig != nil,
              isValid,
              !isSubmitting,
              !hasSubmitted else { return }

        hasSubmitted = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.submitConsent(with: token)
            } catch {
                self.hasSubmitted = false
                self.onError?(error)
            }
        }
    }

    func updateAccessToken(_ token: String?) {
        accessToken = token
        if token == nil || (token ?? "").isEmpty {
            hasSubmitted = false
        } else {
            checkValidationAndAutoSubmit()
        }
    }

    // MARK: - Submit

    private func submitConsent(with token: String) async throws {
        guard let ac = activeConfig else {
            errorMessage = "Unable to submit consent. Please try again."
            throw RedactoAPIError.invalidRequest("Content not available")
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let purposes = ac.purposes.map { purpose -> Purpose in
                let hasSelectedRequired = purpose.dataElements.contains { el in
                    el.required && (selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false)
                }
                let hasSelectedElement = purpose.dataElements.contains { el in
                    selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false
                }
                let purposeSelected = (selectedPurposes[purpose.uuid] ?? false) || hasSelectedRequired || hasSelectedElement

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
                            selected: selectedDataElements["\(purpose.uuid)-\(el.uuid)"] ?? false
                        )
                    }
                )
            }

            try await ConsentAPI.submitConsentEvent(.init(
                accessToken: token,
                baseUrl: baseUrl,
                noticeUuid: ac.noticeUuid,
                purposes: purposes,
                declined: false,
                metaData: applicationId.map { MetaData(specificUuid: $0) },
                orgUuid: orgUuid,
                workspaceUuid: workspaceUuid
            ))

            onAccept?()
            hasSubmitted = false
        } catch {
            let apiError = error as? RedactoAPIError
            errorMessage = apiError?.statusCode == 500
                ? "An error occurred while submitting your consent. Please try again later."
                : error.localizedDescription
            hasSubmitted = false
            isSubmitting = false
            throw error
        }

        isSubmitting = false
    }

    // MARK: - Derived

    var supportedLanguages: [String] {
        guard let translations = activeConfig?.supportedLanguagesAndTranslations else { return [] }
        return Array(translations.keys).sorted()
    }
}
