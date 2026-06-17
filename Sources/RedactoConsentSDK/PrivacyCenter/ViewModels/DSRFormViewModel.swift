import Foundation
import SwiftUI

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

    @Published public var formData: PrivacyFormData?
    @Published public var requestType: RequestType?
    @Published public var selectedPurposeIds: Set<String> = []
    @Published public var selectedDataElementsByPurpose: [String: Set<String>] = [:]
    @Published public var selectedCorrectionFields: Set<String> = []
    @Published public var correctionValues: [String: CorrectionValue] = [:]
    @Published public var selectedGrievances: Set<GrievanceType> = []
    @Published public var nominationData: NominationData = NominationData()
    @Published public var additionalNote: String = ""
    @Published public var confirmChecked: Bool = false
    @Published public var uploadedDocs: [UploadedDoc] = []
    @Published public var isRequestDetailsExpanded: Bool = true
    @Published public var isLoading: Bool = false
    @Published public var isUploading: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var errorMessage: String?
    @Published public var caseSubmitted: Bool = false
    @Published public var submittedCaseId: String?

    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var purposes: [PrivacyPurpose] {
        formData?.purposes.map { $0.purpose } ?? []
    }

    /// Deduplicated data elements across all purposes — used by CORRECTION.
    public var uniqueDataElements: [PrivacyDataElement] {
        var seen = Set<String>()
        var result: [PrivacyDataElement] = []
        for purpose in purposes {
            for de in purpose.dataElements where !seen.contains(de.uuid) {
                seen.insert(de.uuid)
                result.append(de)
            }
        }
        return result
    }

    public var grievanceOptions: [GrievanceOption] {
        formData?.grievanceOptions ?? []
    }

    public func loadFormData() async {
        guard formData == nil else { return }
        guard let contact = store.contact else {
            errorMessage = "No contact available"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await store.api.getFormData(contact: contact, language: store.language)
            self.formData = data
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    /// Toggle a purpose. Selecting a purpose auto-selects all of its data elements.
    /// Deselecting clears them.
    public func togglePurpose(_ purpose: PrivacyPurpose) {
        let uuid = purpose.uuid
        if selectedPurposeIds.contains(uuid) {
            selectedPurposeIds.remove(uuid)
            selectedDataElementsByPurpose[uuid] = nil
        } else {
            selectedPurposeIds.insert(uuid)
            selectedDataElementsByPurpose[uuid] = Set(purpose.dataElements.map { $0.uuid })
        }
    }

    /// Toggle a data element under a purpose. If we deselect the last one we
    /// auto-uncheck the parent purpose; if we re-select one we auto-check it.
    public func toggleDataElement(purpose: PrivacyPurpose, elementUuid: String) {
        var set = selectedDataElementsByPurpose[purpose.uuid] ?? []
        if set.contains(elementUuid) {
            set.remove(elementUuid)
        } else {
            set.insert(elementUuid)
        }
        selectedDataElementsByPurpose[purpose.uuid] = set
        let totalElements = purpose.dataElements.count
        if set.isEmpty && totalElements > 0 {
            selectedPurposeIds.remove(purpose.uuid)
            selectedDataElementsByPurpose.removeValue(forKey: purpose.uuid)
        } else if !set.isEmpty {
            selectedPurposeIds.insert(purpose.uuid)
        }
    }

    public func toggleCorrectionField(_ uuid: String) {
        if selectedCorrectionFields.contains(uuid) {
            selectedCorrectionFields.remove(uuid)
        } else {
            selectedCorrectionFields.insert(uuid)
        }
    }

    public func toggleGrievance(_ grievance: GrievanceType) {
        if selectedGrievances.contains(grievance) {
            selectedGrievances.remove(grievance)
        } else {
            selectedGrievances.insert(grievance)
        }
    }

    public func updateCorrection(uuid: String, current: String? = nil, updated: String? = nil) {
        var v = correctionValues[uuid] ?? CorrectionValue()
        if let current { v.current = current }
        if let updated { v.updated = updated }
        correctionValues[uuid] = v
    }

    public func uploadDocument(fileData: Data, filename: String, mimeType: String) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let response = try await store.api.uploadDocument(fileData: fileData, filename: filename, mimeType: mimeType)
            uploadedDocs.append(UploadedDoc(id: response.uuid, fileName: response.fileName, fileSize: response.fileSize))
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func removeDocument(_ id: String) {
        uploadedDocs.removeAll { $0.id == id }
    }

    public var canSubmit: Bool {
        guard let requestType, confirmChecked, !isSubmitting else { return false }
        switch requestType {
        case .access, .erasure:
            return !selectedPurposeIds.isEmpty
        case .correction:
            return !selectedCorrectionFields.isEmpty
        case .grievance:
            return !selectedGrievances.isEmpty
        case .nomination:
            return !nominationData.nomineeEmail.isEmpty
        }
    }

    public func submit() async {
        guard let requestType, let formData else { return }
        guard let contact = store.contact else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let purposesPayload: [UpdatePurpose] = selectedPurposeIds.map { purposeUuid in
            UpdatePurpose(
                purposeUuid: purposeUuid,
                dataElementUuids: Array(selectedDataElementsByPurpose[purposeUuid] ?? [])
            )
        }
        let corrections: [UpdateCorrectionDataItem] = selectedCorrectionFields.map { fieldUuid in
            let name = uniqueDataElements.first(where: { $0.uuid == fieldUuid })?.name ?? fieldUuid
            let v = correctionValues[fieldUuid] ?? CorrectionValue()
            return UpdateCorrectionDataItem(name: name, currValue: v.current, newValue: v.updated)
        }
        let grievances = selectedGrievances.map { GrievanceTypeElement(grievance: $0) }
        let nomination = requestType == .nomination ? nominationData : nil
        let details = UserDataRequestDetails(
            purposes: purposesPayload,
            correctionData: corrections,
            grievanceTypes: grievances,
            nominationData: nomination
        )
        let timePeriod: Int? = requestType == .access ? 30 : 0
        let payload = UserDataRequest(
            uuid: formData.uuid,
            name: formData.name.trimmingCharacters(in: .whitespaces).isEmpty ? " " : formData.name,
            contact: formData.contact.isEmpty ? contact : formData.contact,
            requestType: requestType,
            supportingDocsUuids: uploadedDocs.map { $0.id },
            requestDetails: details,
            timePeriod: timePeriod,
            requestorNote: additionalNote
        )
        do {
            let result = try await store.api.createCase(payload, language: store.language)
            self.submittedCaseId = result.caseId
            self.caseSubmitted = true
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func reset() {
        requestType = nil
        selectedPurposeIds.removeAll()
        selectedDataElementsByPurpose.removeAll()
        selectedCorrectionFields.removeAll()
        correctionValues.removeAll()
        selectedGrievances.removeAll()
        nominationData = NominationData()
        additionalNote = ""
        confirmChecked = false
        uploadedDocs.removeAll()
        caseSubmitted = false
        submittedCaseId = nil
        errorMessage = nil
    }
}
