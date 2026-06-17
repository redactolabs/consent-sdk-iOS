import Foundation
import SwiftUI

@MainActor
public final class CaseDetailsViewModel: ObservableObject {
    public enum Tab: String { case requestDetails = "request-details", messages }

    @Published public var activeTab: Tab = .requestDetails
    @Published public var messages: [CaseMessage] = []
    @Published public var draftMessage: String = ""
    @Published public var pendingUpload: PendingUpload?
    @Published public var isSendingMessage: Bool = false
    @Published public var isLoadingMessages: Bool = false
    @Published public var isUploading: Bool = false
    @Published public var errorMessage: String?

    private let store: PrivacyCenterStore
    private let caseRequest: CaseRequest
    private var pollingTask: Task<Void, Never>?

    public init(store: PrivacyCenterStore, caseRequest: CaseRequest) {
        self.store = store
        self.caseRequest = caseRequest
    }

    public var caseUuid: String { caseRequest.uuid }
    public var caseId: String { caseRequest.caseId }
    public var requestType: String { caseRequest.requestTypeDisplay ?? caseRequest.requestType }
    public var statusLabel: String { caseRequest.statusDisplay ?? caseRequest.status }
    public var description: String { caseRequest.descriptionDisplay ?? caseRequest.description }
    public var createdAt: String { PrivacyCenterDateFormatters.formatDateTime(caseRequest.createdAt) }
    public var dueDate: String? { caseRequest.dueDate.map(PrivacyCenterDateFormatters.formatDate) }
    public var caseRequestRaw: CaseRequest { caseRequest }

    public func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchMessages(initial: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { break }
                await self.fetchMessages(initial: false)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func fetchMessages(initial: Bool) async {
        if initial { isLoadingMessages = true }
        defer { if initial { isLoadingMessages = false } }
        do {
            let result = try await store.api.getCaseMessages(caseUuid: caseUuid)
            self.messages = result
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func sendMessage() async {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingUpload != nil else { return }
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let docs = pendingUpload.map { [$0.uuid] } ?? []
            let result = try await store.api.sendCaseMessage(caseUuid: caseUuid, body: trimmed, documentUuids: docs)
            messages.append(result)
            draftMessage = ""
            pendingUpload = nil
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func uploadAttachment(fileData: Data, filename: String, mimeType: String) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let result = try await store.api.uploadCaseDocument(caseUuid: caseUuid, fileData: fileData, filename: filename, mimeType: mimeType)
            pendingUpload = PendingUpload(uuid: result.uuid, fileName: result.fileName, fileSize: result.fileSize)
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func clearPendingUpload() {
        pendingUpload = nil
    }

    public func submitForDocumentRequest(requestEventUuid: String, documentUuid: String, body: String) async {
        do {
            let result = try await store.api.submitDocumentForRequest(
                caseUuid: caseUuid,
                requestEventUuid: requestEventUuid,
                documentUuid: documentUuid,
                body: body
            )
            messages.append(result)
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
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
