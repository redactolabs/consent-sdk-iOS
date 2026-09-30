import Foundation
import SwiftUI

/// A case's page (React PrivacyCenterCaseDetailsPage + CaseDetails/*).
@MainActor
public final class CaseDetailsViewModel: ObservableObject {
    public enum Tab: String { case requestDetails = "request-details", messages }

    /// React polls the thread every 30 seconds.
    static let pollIntervalNanoseconds: UInt64 = 30_000_000_000

    @Published public var activeTab: Tab = .requestDetails
    @Published public var messages: [CaseMessage] = []
    @Published public var draftMessage: String = ""
    @Published public var pendingUpload: PendingUpload?
    @Published public var isSendingMessage: Bool = false
    @Published public var isLoadingMessages: Bool = false
    @Published public var isFetchingMessages: Bool = false
    @Published public var isUploading: Bool = false
    @Published public var messagesFailed: Bool = false
    /// The document request an upload is being filed against.
    @Published public var submittingForRequest: String?
    @Published public var openingDocument: String?
    @Published public var errorMessage: String?
    @Published public private(set) var caseRequest: CaseRequest

    private let store: PrivacyCenterStore
    private var pollingTask: Task<Void, Never>?

    public init(store: PrivacyCenterStore, caseRequest: CaseRequest) {
        self.store = store
        self.caseRequest = caseRequest
    }

    public var caseUuid: String { caseRequest.uuid }
    public var caseId: String { caseRequest.caseId }
    public var requestType: String { caseRequest.displayRequestType }
    public var statusLabel: String { caseRequest.displayStatus }
    public var description: String { caseRequest.descriptionDisplay.pcNonEmpty ?? caseRequest.rawDescription ?? "" }
    public var createdAt: String { PrivacyCenterDateFormatters.formatDateShort(caseRequest.createdAt) }
    public var dueDate: String? { caseRequest.dueDate.pcNonEmpty.map(PrivacyCenterDateFormatters.formatDateShort) }
    public var completedAt: String? { caseRequest.completedAt.pcNonEmpty.map(PrivacyCenterDateFormatters.formatDateShort) }
    public var isDueDateOverdue: Bool { PrivacyCenterDateFormatters.isPast(caseRequest.dueDate) }
    public var isCaseFinalized: Bool { caseRequest.isFinalized }
    public var caseRequestRaw: CaseRequest { caseRequest }

    /// Re-read the case from the list so a language change re-translates it
    /// (React re-hydrates `selectedCase`); a case that is gone returns to the list.
    public func rehydrate() async {
        do {
            let list = try await store.api.getCaseHistory(language: store.langParam).items
            if let found = list.first(where: { $0.uuid == caseRequest.uuid }) {
                caseRequest = found
                store.selectedCase = found
            } else {
                store.navigate(to: .form)
            }
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
        }
    }

    public func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.fetchMessages(initial: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
                guard !Task.isCancelled, let self else { break }
                if await self.store.tokenStore.isRefreshBlocked() { continue }
                await self.fetchMessages(initial: false)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Oldest first whatever order the server sends (React `useCaseMessages`).
    static func sorted(_ messages: [CaseMessage]) -> [CaseMessage] {
        messages.sorted { a, b in
            if let da = PrivacyCenterDateFormatters.parse(a.createdAt), let db = PrivacyCenterDateFormatters.parse(b.createdAt) {
                return da < db
            }
            return a.createdAt < b.createdAt
        }
    }

    public func fetchMessages(initial: Bool) async {
        if initial { isLoadingMessages = true }
        isFetchingMessages = true
        defer {
            if initial { isLoadingMessages = false }
            isFetchingMessages = false
        }
        do {
            let result = try await store.api.getCaseMessages(caseUuid: caseUuid)
            messages = Self.sorted(result)
            messagesFailed = false
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            messagesFailed = true
            store.reportError(error)
        }
    }

    public var canSend: Bool {
        !isCaseFinalized && !isSendingMessage && !isUploading
            && (!draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingUpload != nil)
    }

    public func sendMessage() async {
        guard canSend else { return }
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let docs = pendingUpload.map { [$0.uuid] } ?? []
            _ = try await store.api.sendCaseMessage(caseUuid: caseUuid, body: trimmed, documentUuids: docs)
            draftMessage = ""
            pendingUpload = nil
            await fetchMessages(initial: false)
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
        }
    }

    private func upload(fileData: Data, filename: String, mimeType: String) async throws -> UploadDocumentResponse {
        try await store.api.uploadCaseDocument(caseUuid: caseUuid, fileData: fileData, filename: filename, mimeType: mimeType)
    }

    public func uploadAttachment(fileData: Data, filename: String, mimeType: String) async {
        if let problem = PCUploadValidation.problem(size: fileData.count, mimeType: mimeType) {
            store.showToast(problem, kind: .error)
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let result = try await upload(fileData: fileData, filename: filename, mimeType: mimeType)
            let name = result.fileName.nonEmpty ?? filename
            pendingUpload = PendingUpload(
                uuid: result.uuid,
                fileName: name,
                fileSize: result.fileSize > 0 ? result.fileSize : fileData.count
            )
            store.showToast(PCStrings.fileUploadedNamed(name), kind: .success)
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            store.showToast(PCUploadValidation.message(for: error), kind: .error)
            store.reportError(error)
        }
    }

    public func clearPendingUpload() {
        pendingUpload = nil
    }

    /// Upload a file and file it against a document request (React
    /// `handleSubmitForRequest`).
    public func uploadForDocumentRequest(requestEventUuid: String, fileData: Data, filename: String, mimeType: String) async {
        if let problem = PCUploadValidation.problem(size: fileData.count, mimeType: mimeType) {
            store.showToast(problem, kind: .error)
            return
        }
        submittingForRequest = requestEventUuid
        isUploading = true
        defer {
            submittingForRequest = nil
            isUploading = false
        }
        let uploaded: UploadDocumentResponse
        do {
            uploaded = try await upload(fileData: fileData, filename: filename, mimeType: mimeType)
            store.showToast(PCStrings.fileUploadedNamed(uploaded.fileName.nonEmpty ?? filename), kind: .success)
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            store.showToast(PCUploadValidation.message(for: error), kind: .error)
            store.reportError(error)
            return
        }
        await submitForDocumentRequest(requestEventUuid: requestEventUuid, documentUuid: uploaded.uuid, body: "")
    }

    public func submitForDocumentRequest(requestEventUuid: String, documentUuid: String, body: String) async {
        do {
            _ = try await store.api.submitDocumentForRequest(
                caseUuid: caseUuid,
                requestEventUuid: requestEventUuid,
                documentUuid: documentUuid,
                body: body
            )
            await fetchMessages(initial: false)
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            store.showToast(PCStrings.failedToSubmitDocument, kind: .error)
            store.reportError(error)
        }
    }

    /// The attachment's download URL; one the thread did not carry is looked
    /// up (React `getCaseDocument`).
    public func documentURL(for document: MessageDocument) async -> URL? {
        if let url = document.downloadURL { return url }
        guard !document.uuid.isEmpty else { return nil }
        openingDocument = document.uuid
        defer { openingDocument = nil }
        do {
            return try await store.api.getCaseDocument(caseUuid: caseUuid, documentUuid: document.uuid).downloadURL
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
            return nil
        }
    }

    public func messagesGroupedByDay() -> [(label: String, messages: [CaseMessage])] {
        var groups: [(String, [CaseMessage])] = []
        for message in messages {
            let label = PrivacyCenterDateFormatters.dayBucketLabel(message.createdAt)
            if let last = groups.last, last.0 == label {
                groups[groups.count - 1].1.append(message)
            } else {
                groups.append((label, [message]))
            }
        }
        return groups
    }
}
