import Foundation
import SwiftUI

/// The requests list (React CaseHistory.tsx): the whole history is read once
/// and filtered, searched and paged on the device.
@MainActor
public final class CaseHistoryViewModel: ObservableObject {
    @Published public var cases: [CaseRequest] = []
    @Published public var pagination: Pagination = Pagination(totalCount: 0, offset: 0, limit: 10)
    @Published public var statusFilter: CaseRequestStatusFilter = .all {
        didSet { if oldValue != statusFilter { pageIndex = 0 } }
    }
    @Published public var selectedRequestTypes: Set<RequestType> = Set(RequestType.allCases) {
        didSet { if oldValue != selectedRequestTypes { pageIndex = 0 } }
    }
    @Published public var searchText: String = "" {
        didSet { if oldValue != searchText { pageIndex = 0 } }
    }
    @Published public var pageIndex: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String?
    @Published public var pageSize: Int = 10 {
        didSet { if oldValue != pageSize { pageIndex = 0 } }
    }

    public static let pageSizeOptions = [5, 10, 15, 20, 25]

    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    static func matchesTab(_ status: String, _ filter: CaseRequestStatusFilter) -> Bool {
        let s = status.lowercased()
        switch filter {
        case .all: return true
        case .processing: return ["processing", "in_progress", "initiated", "assigned"].contains(s)
        case .completed: return s == "completed"
        case .rejected: return ["rejected", "declined"].contains(s)
        }
    }

    public var filteredCases: [CaseRequest] {
        let query = searchText.lowercased()
        let allTypes = selectedRequestTypes.count == RequestType.allCases.count
        return cases.filter { item in
            guard Self.matchesTab(item.rawStatus ?? "", statusFilter) else { return false }
            if !allTypes && !selectedRequestTypes.isEmpty {
                guard let raw = item.rawRequestType?.lowercased(),
                      selectedRequestTypes.contains(where: { $0.rawValue == raw }) else { return false }
            }
            if !query.isEmpty {
                let matchesId = item.caseId.lowercased().contains(query)
                let matchesDescription = (item.rawDescription ?? "").lowercased().contains(query)
                    || (item.requestDetails?.purposes.first?.purpose.description ?? "").lowercased().contains(query)
                if !matchesId && !matchesDescription { return false }
            }
            return true
        }
    }

    public var totalPages: Int { max(1, (filteredCases.count + pageSize - 1) / pageSize) }

    public var pagedCases: [CaseRequest] {
        let all = filteredCases
        let start = min(pageIndex * pageSize, all.count)
        return Array(all[start..<min(start + pageSize, all.count)])
    }

    public func goToPage(_ index: Int) {
        pageIndex = max(0, min(index, totalPages - 1))
    }

    public func toggleRequestType(_ type: RequestType) {
        if selectedRequestTypes.contains(type) {
            selectedRequestTypes.remove(type)
        } else {
            selectedRequestTypes.insert(type)
        }
    }

    public var hasMore: Bool { false }

    public var isEmpty: Bool { !isLoading && cases.isEmpty }

    public func loadInitial() async {
        if store.isSessionExpired { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await store.api.getCaseHistory(language: store.langParam)
            self.cases = result.items
            self.pagination = result.page
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            errorMessage = PCStrings.errorLoadingCaseHistory
            store.reportError(error)
        }
    }

    public func loadMore() async {}

    public func refresh() async { await loadInitial() }

    public func setStatusFilter(_ filter: CaseRequestStatusFilter) {
        statusFilter = filter
    }
}
