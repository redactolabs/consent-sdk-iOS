import Foundation
import SwiftUI

/// The data-request form (React components/Form.tsx): one form raises one
/// case, scoped to one product for ACCESS / ERASURE / CORRECTION.
@MainActor
public final class DSRFormViewModel: ObservableObject {
    public struct UploadedDoc: Identifiable, Equatable {
        public let id: String
        public let fileName: String
        public let fileSize: Int
    }

    public struct CorrectionValue: Equatable {
        public var current: String
        public var updated: String
        public init(current: String = "", updated: String = "") {
            self.current = current
            self.updated = updated
        }
    }

    /// What the success card shows (React `SubmittedCase`). Product fields are
    /// empty for nomination and grievance, which have no product anchor.
    public struct SubmittedCase: Equatable {
        public let caseId: String
        public let uuid: String
        public let productName: String
        public let productUuid: String
    }

    /// A correction field: a data element of the chosen product, deduplicated
    /// by uuid (React `buildGroupDataElements`).
    public struct CorrectionField: Identifiable, Equatable {
        public let element: PrivacyDataElement
        public let purposeName: String
        public var id: String { element.uuid }
    }

    /// Sentinel product of the synthetic group built from a backend's flat
    /// purpose list; a case raised from it carries no product anchor.
    public static let legacyProductGroupUuid = "__legacy_flat_purposes__"
    /// The ledger caps user-consents pages at 100.
    static let pickerGroupLimit = 100
    static let emailPattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    static let mobilePattern = #"^\+?\d{9,15}$"#

    @Published public var formData: PrivacyFormData?
    @Published public private(set) var groups: [FormProductGroup] = []
    @Published public var requestType: RequestType? {
        didSet {
            guard oldValue != requestType else { return }
            timePeriod = ""
            isRequestDetailsExpanded = true
            nominationData = NominationData()
            selectedGrievances = []
            if !skipProductStep { selectedProductKey = nil }
            reseedProductState()
        }
    }
    @Published public var selectedProductKey: String? {
        didSet { if oldValue != selectedProductKey { reseedProductState() } }
    }
    /// Selected data elements per purpose of the chosen product. A purpose
    /// counts as chosen when any of its elements is.
    @Published public var selectedElements: [String: Set<String>] = [:]
    @Published public var selectedCorrectionNames: [String] = []
    @Published public var correctionValues: [String: CorrectionValue] = [:]
    @Published public var selectedGrievances: Set<GrievanceType> = []
    @Published public var nominationData: NominationData = NominationData()
    @Published public var timePeriod: String = ""
    @Published public var additionalNote: String = ""
    @Published public var confirmChecked: Bool = false
    @Published public var uploadedDocs: [UploadedDoc] = []
    @Published public var isRequestDetailsExpanded: Bool = true
    @Published public var isLoading: Bool = false
    @Published public var isTranslating: Bool = false
    @Published public var isUploading: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var isErasureModalOpen: Bool = false
    @Published public var revokeConsentOnFulfilment: Bool = false
    @Published public var submittedCase: SubmittedCase?
    @Published public var errorMessage: String?

    public var caseSubmitted: Bool { submittedCase != nil }
    public var submittedCaseId: String? { submittedCase?.caseId }

    /// English form data, kept to send correction field names untranslated.
    private var englishFormData: PrivacyFormData?
    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var contact: String { formData?.contact.nonEmpty ?? store.contact ?? "" }

    public var grievanceOptions: [GrievanceOption] { formData?.grievanceOptions ?? [] }

    public var isProductScoped: Bool {
        guard let requestType else { return false }
        return [.access, .erasure, .correction].contains(requestType)
    }

    /// With exactly one product there is nothing to choose: React skips the
    /// step and selects it.
    public var skipProductStep: Bool { groups.count == 1 }

    public var selectedGroup: FormProductGroup? {
        if let key = selectedProductKey { return groups.first { $0.id == key } }
        return skipProductStep ? groups.first : nil
    }

    public var directGroups: [FormProductGroup] { groups.filter { $0.nominator == nil } }
    public var nominatedGroups: [FormProductGroup] { groups.filter { $0.nominator != nil } }

    /// React `buildGroupPurposes`: purposes with at least one addressable data
    /// element, elements without a uuid dropped.
    public static func groupPurposes(_ group: FormProductGroup) -> [PrivacyPurpose] {
        group.purposes.compactMap { purpose in
            let elements = purpose.dataElements.filter { !$0.uuid.isEmpty }
            guard !elements.isEmpty else { return nil }
            return PrivacyPurpose(
                uuid: purpose.uuid, name: purpose.name, description: purpose.description,
                industries: purpose.industries, selected: false, givenConsent: purpose.givenConsent,
                dataElements: elements, status: purpose.status, validity: purpose.validity,
                purposeUuid: purpose.purposeUuid, enabled: purpose.enabled
            )
        }
    }

    public static func groupDataElements(_ group: FormProductGroup) -> [CorrectionField] {
        var seen = Set<String>()
        var fields: [CorrectionField] = []
        for purpose in group.purposes {
            for element in purpose.dataElements where !element.uuid.isEmpty && !seen.contains(element.uuid) {
                seen.insert(element.uuid)
                fields.append(CorrectionField(element: element, purposeName: purpose.name))
            }
        }
        return fields
    }

    public var purposes: [PrivacyPurpose] {
        guard let group = selectedGroup, isProductScoped else { return [] }
        return Self.groupPurposes(group)
    }

    public var correctionFields: [CorrectionField] {
        guard let group = selectedGroup, requestType == .correction else { return [] }
        return Self.groupDataElements(group)
    }

    private func reseedProductState() {
        selectedElements = [:]
        selectedCorrectionNames = []
        correctionValues = [:]
    }

    // MARK: - Loading

    public func loadFormData() async {
        guard formData == nil else { return }
        guard let storedContact = store.contact.pcNonEmpty else {
            store.reportError(PrivacyCenterAPIError.validationError("Contact email not found"))
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let english = try await store.api.getFormData(contact: storedContact)
            englishFormData = english
            var display = english
            if let lang = store.langParam {
                display = (try? await store.api.getFormData(contact: storedContact, language: lang)) ?? english
            }
            apply(display, fallbackContact: storedContact)
            groups = await pickerGroups(for: display, language: store.langParam)
        } catch {
            if isCancellationError(error) { return }
            store.showToast(PCStrings.failedToFetchFormData, kind: .error)
            store.reportError(error)
        }
    }

    /// Re-read the purposes, elements and grievance labels in the new language
    /// (React `fetchAndApplyTranslations`); English stays if there is none.
    public func applyLanguageChange() async {
        guard formData != nil, let storedContact = contact.nonEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let translated = try await store.api.getFormData(contact: storedContact, language: store.langParam)
            guard !translated.purposes.isEmpty else {
                store.showToast(PCStrings.translationNotAvailable, kind: .info)
                return
            }
            let grievances = selectedGrievances
            apply(translated, fallbackContact: storedContact)
            groups = await pickerGroups(for: translated, language: store.langParam)
            selectedGrievances = grievances.filter { g in translated.grievanceOptions.contains { $0.value == g } }
            reseedProductState()
        } catch {
            if !isCancellationError(error) {
                store.showToast(PCStrings.translationNotAvailable, kind: .info)
            }
        }
    }

    private func apply(_ data: PrivacyFormData, fallbackContact: String) {
        formData = PrivacyFormData(
            uuid: data.uuid,
            name: data.name,
            contact: data.contact.nonEmpty ?? fallbackContact,
            grievanceOptions: data.grievanceOptions,
            purposes: data.purposes,
            directGroups: data.directGroups,
            nominatedGroups: data.nominatedGroups
        )
    }

    /// Products for the picker, read from user-consents (every status) since
    /// form/data stopped carrying them; the form's own groups otherwise, and
    /// its flat purpose list as one synthetic group last.
    private func pickerGroups(for form: PrivacyFormData, language: String?) async -> [FormProductGroup] {
        if let consents = try? await store.api.getUserConsents(
            limit: Self.pickerGroupLimit,
            nominatedLimit: Self.pickerGroupLimit,
            language: language
        ) {
            let direct = consents.direct ?? []
            let nominated = consents.nominated ?? []
            if !direct.isEmpty || !nominated.isEmpty {
                return (direct + nominated).map(Self.formGroup(from:))
            }
        }
        let formGroups = (form.directGroups ?? []) + (form.nominatedGroups ?? [])
        if !formGroups.isEmpty { return formGroups }
        let flat = FormProductGroup(
            productUuid: Self.legacyProductGroupUuid,
            productName: PCStrings.yourData,
            purposes: form.purposes.map(\.purpose)
        )
        return Self.groupPurposes(flat).isEmpty ? [] : [flat]
    }

    /// React `consentGroupToFormProductGroup`.
    static func formGroup(from group: ConsentGroup) -> FormProductGroup {
        FormProductGroup(
            productUuid: group.productUuid,
            productName: group.productName,
            productDescription: group.productDescription,
            nominator: group.nominator,
            purposes: group.purposes.map { item in
                PrivacyPurpose(
                    uuid: item.purposeUuid,
                    name: item.name,
                    description: item.description ?? "",
                    dataElements: item.dataElements.map {
                        PrivacyDataElement(uuid: $0.uuid, name: $0.name, enabled: $0.enabled, required: $0.required, givenConsent: $0.selected, selected: $0.selected)
                    },
                    status: item.statusText,
                    purposeUuid: item.purposeUuid,
                    enabled: true
                )
            }
        )
    }

    // MARK: - Selection

    public func selectProduct(_ group: FormProductGroup) {
        if skipProductStep { return }
        selectedProductKey = selectedProductKey == group.id ? nil : group.id
    }

    public func isPurposeSelected(_ purpose: PrivacyPurpose) -> Bool {
        !(selectedElements[purpose.uuid] ?? []).isEmpty
    }

    public func isPurposeFullySelected(_ purpose: PrivacyPurpose) -> Bool {
        let chosen = selectedElements[purpose.uuid] ?? []
        return purpose.dataElements.allSatisfy { chosen.contains($0.uuid) }
    }

    public func setPurpose(_ purpose: PrivacyPurpose, selected: Bool) {
        selectedElements[purpose.uuid] = selected ? Set(purpose.dataElements.map(\.uuid)) : []
    }

    /// Kept for callers of the earlier API: toggles every element of the purpose.
    public func togglePurpose(_ purpose: PrivacyPurpose) {
        setPurpose(purpose, selected: !isPurposeFullySelected(purpose))
    }

    public func toggleDataElement(purpose: PrivacyPurpose, elementUuid: String) {
        var chosen = selectedElements[purpose.uuid] ?? []
        if chosen.contains(elementUuid) { chosen.remove(elementUuid) } else { chosen.insert(elementUuid) }
        selectedElements[purpose.uuid] = chosen
    }

    public var isAllSelected: Bool {
        purposes.allSatisfy(isPurposeFullySelected)
    }

    public func setAllPurposes(selected: Bool) {
        for purpose in purposes { setPurpose(purpose, selected: selected) }
    }

    public func toggleCorrectionField(_ name: String) {
        if let index = selectedCorrectionNames.firstIndex(of: name) {
            selectedCorrectionNames.remove(at: index)
        } else {
            selectedCorrectionNames.append(name)
        }
    }

    public var isAllCorrectionSelected: Bool {
        !correctionFields.isEmpty && selectedCorrectionNames.count == correctionFields.count
    }

    public func setAllCorrectionFields(selected: Bool) {
        selectedCorrectionNames = selected ? correctionFields.map(\.element.name) : []
    }

    public func updateCorrection(name: String, current: String? = nil, updated: String? = nil) {
        var value = correctionValues[name] ?? CorrectionValue()
        if let current { value.current = current }
        if let updated { value.updated = updated }
        correctionValues[name] = value
    }

    public func toggleGrievance(_ grievance: GrievanceType) {
        if selectedGrievances.contains(grievance) {
            selectedGrievances.remove(grievance)
        } else {
            selectedGrievances.insert(grievance)
        }
    }

    public var isAllGrievancesSelected: Bool {
        !grievanceOptions.isEmpty && grievanceOptions.allSatisfy { selectedGrievances.contains($0.value) }
    }

    public func setAllGrievances(selected: Bool) {
        selectedGrievances = selected ? Set(grievanceOptions.map(\.value)) : []
    }

    // MARK: - Validation

    /// React `cleanNomineeMobile`: spacing and punctuation dropped, so
    /// "+91 98765 43210" goes out as "+919876543210".
    public static func cleanMobile(_ mobile: String?) -> String {
        (mobile ?? "").replacingOccurrences(of: #"[\s\-().]"#, with: "", options: .regularExpression)
    }

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    /// An email, a mobile, or both; each one given must be well formed.
    public static func isNominationValid(_ data: NominationData) -> Bool {
        let email = data.nomineeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let mobile = cleanMobile(data.nomineeMobile)
        if email.isEmpty && mobile.isEmpty { return false }
        return (email.isEmpty || matches(email, emailPattern)) && (mobile.isEmpty || matches(mobile, mobilePattern))
    }

    public var isRequestDetailsValid: Bool {
        guard let requestType else { return false }
        if isProductScoped {
            guard !groups.isEmpty, selectedGroup != nil else { return false }
            if requestType == .correction {
                return !selectedCorrectionNames.isEmpty && selectedCorrectionNames.allSatisfy { name in
                    let value = correctionValues[name]
                    return !(value?.current.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
                        && !(value?.updated.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
                }
            }
            return purposes.contains(where: isPurposeSelected)
        }
        switch requestType {
        case .grievance: return !selectedGrievances.isEmpty
        case .nomination: return Self.isNominationValid(nominationData)
        default: return false
        }
    }

    public var canSubmit: Bool {
        !contact.trimmingCharacters(in: .whitespaces).isEmpty
            && requestType != nil
            && isRequestDetailsValid
            && confirmChecked
            && !isSubmitting
    }

    /// Purpose names in an erasure request, for the revoke modal and notice.
    public var selectedErasurePurposeNames: [String] {
        purposes.filter(isPurposeSelected).map(\.name).filter { !$0.isEmpty }
    }

    public static let maxErasurePurposeNames = 3

    public var erasurePurposeSummary: String {
        let names = selectedErasurePurposeNames
        if names.isEmpty || names.count > Self.maxErasurePurposeNames { return PCStrings.revokeConsentModalYourPurposes }
        return names.joined(separator: ", ")
    }

    // MARK: - Submit

    /// Erasure first asks whether to revoke consent on fulfilment; every other
    /// type submits straight away.
    public func submitTapped() async {
        guard canSubmit else { return }
        if requestType == .erasure {
            isErasureModalOpen = true
            return
        }
        revokeConsentOnFulfilment = false
        await submit()
    }

    public func chooseErasureRevoke(_ revoke: Bool) async {
        revokeConsentOnFulfilment = revoke
        isErasureModalOpen = false
        await submit(revokeConsent: revoke)
    }

    /// React `getEnglishDataElementName`: a translated field name mapped back to
    /// English through its uuid, so the case records the original field.
    func englishDataElementName(_ name: String) -> String {
        guard let english = englishFormData else { return name }
        var uuidByName: [String: String] = [:]
        for wrapper in formData?.purposes ?? [] {
            for element in wrapper.purpose.dataElements { uuidByName[element.name] = element.uuid }
        }
        guard let uuid = uuidByName[name] else { return name }
        for wrapper in english.purposes {
            if let match = wrapper.purpose.dataElements.first(where: { $0.uuid == uuid }) { return match.name }
        }
        return name
    }

    func buildPayload(revokeConsent: Bool) -> UserDataRequest? {
        guard let requestType, let formData else { return nil }
        let anchor = isProductScoped && selectedGroup?.productUuid != Self.legacyProductGroupUuid ? selectedGroup : nil

        var purposesPayload: [UpdatePurpose] = []
        if requestType == .access || requestType == .erasure {
            purposesPayload = purposes.filter(isPurposeSelected).map { purpose in
                let chosen = selectedElements[purpose.uuid] ?? []
                return UpdatePurpose(
                    purposeUuid: purpose.uuid,
                    dataElementUuids: purpose.dataElements.map(\.uuid).filter { chosen.contains($0) }
                )
            }
        }
        var corrections: [UpdateCorrectionDataItem] = []
        if requestType == .correction {
            corrections = selectedCorrectionNames.map { name in
                UpdateCorrectionDataItem(
                    name: englishDataElementName(name),
                    currValue: correctionValues[name]?.current ?? "",
                    newValue: correctionValues[name]?.updated ?? ""
                )
            }
        }
        var grievances: [GrievanceTypeElement] = []
        if requestType == .grievance {
            grievances = grievanceOptions.map(\.value).filter { selectedGrievances.contains($0) }.map(GrievanceTypeElement.init)
        }
        var nomination: NominationData?
        if requestType == .nomination {
            let mobile = Self.cleanMobile(nominationData.nomineeMobile)
            nomination = NominationData(
                nomineeEmail: nominationData.nomineeEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                nomineeMobile: mobile.isEmpty ? nil : mobile
            )
        }
        return UserDataRequest(
            uuid: formData.uuid,
            name: " ",
            contact: contact,
            requestType: requestType,
            supportingDocsUuids: uploadedDocs.map(\.id),
            requestDetails: UserDataRequestDetails(
                purposes: purposesPayload,
                correctionData: corrections,
                grievanceTypes: grievances,
                nominationData: nomination
            ),
            timePeriod: requestType == .access ? (Int(timePeriod) ?? 30) : 0,
            requestorNote: additionalNote,
            revokeConsentOnFulfilment: requestType == .erasure ? revokeConsent : nil,
            productUuid: anchor?.productUuid,
            dataPrincipalUuid: anchor?.nominator?.uuid
        )
    }

    public func submit(revokeConsent: Bool = false) async {
        guard isRequestDetailsValid, let payload = buildPayload(revokeConsent: revokeConsent) else { return }
        let anchor = payload.productUuid == nil ? nil : selectedGroup
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let result = try await store.api.createCase(payload, language: store.langParam)
            let caseId = result.caseId.nonEmpty ?? result.uuid ?? ""
            guard !caseId.isEmpty else {
                store.showToast(PCStrings.requestSubmissionFailed, kind: .error)
                return
            }
            submittedCase = SubmittedCase(
                caseId: caseId,
                uuid: result.uuid ?? caseId,
                productName: anchor?.productName ?? "",
                productUuid: anchor?.productUuid ?? ""
            )
            store.showToast(PCStrings.requestSubmittedSuccess, kind: .success)
            NotificationCenter.default.post(name: .privacyCenterCasesChanged, object: nil)
        } catch {
            if isCancellationError(error) { return }
            store.showToast(PCStrings.requestSubmissionFailed, kind: .error)
            store.reportError(error)
        }
    }

    // MARK: - Documents

    public func uploadDocument(fileData: Data, filename: String, mimeType: String) async {
        if let problem = PCUploadValidation.problem(size: fileData.count, mimeType: mimeType) {
            store.showToast(problem, kind: .error)
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let response = try await store.api.uploadDocument(
                fileData: fileData,
                filename: filename,
                mimeType: mimeType,
                principalUuid: formData?.uuid ?? ""
            )
            uploadedDocs.append(UploadedDoc(
                id: response.uuid,
                fileName: filename,
                fileSize: response.fileSize > 0 ? response.fileSize : fileData.count
            ))
            store.showToast(PCStrings.fileUploadedSuccess, kind: .success)
        } catch {
            if isCancellationError(error) { return }
            store.showToast(PCStrings.failedToUploadFile(filename), kind: .error)
            store.reportError(error)
        }
    }

    public func removeDocument(_ id: String) {
        uploadedDocs.removeAll { $0.id == id }
    }

    public func reset() {
        requestType = nil
        selectedProductKey = nil
        reseedProductState()
        selectedGrievances = []
        nominationData = NominationData()
        timePeriod = ""
        additionalNote = ""
        confirmChecked = false
        uploadedDocs.removeAll()
        submittedCase = nil
        revokeConsentOnFulfilment = false
        errorMessage = nil
    }
}

public extension Notification.Name {
    /// A case was raised; the case list refetches (React invalidates `caseHistory`).
    static let privacyCenterCasesChanged = Notification.Name("PrivacyCenterCasesChanged")
}

/// React's upload rules (lib/constants.ts, CaseDetails/utils.ts): a 10 MB cap
/// and a MIME allowlist, checked before anything is sent.
public enum PCUploadValidation {
    public static let maxFileSize = 10 * 1024 * 1024

    public static let allowedMimeTypes: [String] = [
        "application/pdf",
        "image/jpeg",
        "image/png",
        "image/webp",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "text/plain",
        "text/csv",
    ]

    /// The message to show, or nil when the file may be uploaded.
    public static func problem(size: Int, mimeType: String) -> String? {
        if size == 0 { return PCStrings.fileEmpty }
        if size > maxFileSize { return PCStrings.fileTooLarge }
        let type = mimeType.trimmingCharacters(in: .whitespaces).lowercased()
        if type.isEmpty || type == "application/octet-stream" { return PCStrings.fileTypeUnknown }
        if !allowedMimeTypes.contains(type) { return PCStrings.fileTypeNotSupported }
        return nil
    }

    /// React `getUploadErrorMessage`.
    public static func message(for error: Error) -> String {
        let text: String
        if let api = error as? PrivacyCenterAPIError {
            if let status = api.httpStatus {
                switch status {
                case 409: return PCStrings.uploadDuplicate
                case 422: return PCStrings.uploadFormatRejected
                case 400: return PCStrings.uploadEmptyOrInvalid
                case 500: return PCStrings.uploadServerError
                default: break
                }
            }
            text = api.debugDescription
        } else {
            text = String(describing: error)
        }
        if text.contains("document_already_exists") { return PCStrings.uploadDuplicate }
        if text.contains("empty_file") { return PCStrings.uploadEmptyOrInvalid }
        return PCStrings.uploadFailedGeneric
    }
}
