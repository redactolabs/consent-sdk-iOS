import Foundation
import SwiftUI

@MainActor
public final class CaseHistoryViewModel: ObservableObject {
    @Published public var cases: [CaseRequest] = []
    @Published public var pagination: Pagination = Pagination(totalCount: 0, offset: 0, limit: 10)
    @Published public var statusFilter: CaseRequestStatusFilter = .all
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String?
    @Published public var pageSize: Int = 10

    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var filteredCases: [CaseRequest] {
        let filtered: [CaseRequest]
        switch statusFilter {
        case .all:
            filtered = cases
        case .processing, .completed, .rejected:
            filtered = cases.filter { ($0.statusDisplay ?? $0.status).caseInsensitiveCompare(statusFilter.rawValue) == .orderedSame }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return filtered }
        return filtered.filter {
            $0.caseId.lowercased().contains(q)
                || $0.requestType.lowercased().contains(q)
                || $0.description.lowercased().contains(q)
        }
    }

    public var hasMore: Bool { cases.count < pagination.totalCount }

    public var isEmpty: Bool { !isLoading && cases.isEmpty }

    public func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await store.api.getCaseHistory(offset: 0, limit: pageSize, language: store.language)
            self.cases = result.items
            self.pagination = result.page
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await store.api.getCaseHistory(offset: cases.count, limit: pageSize, language: store.language)
            self.cases += result.items
            self.pagination = result.page
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func refresh() async { await loadInitial() }

    public func setStatusFilter(_ filter: CaseRequestStatusFilter) {
        statusFilter = filter
    }
}
