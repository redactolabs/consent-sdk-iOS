import Foundation
import SwiftUI

@MainActor
public final class ActivityListViewModel: ObservableObject {
    @Published public var activities: [Activity] = []
    @Published public var pagination: Pagination = Pagination(totalCount: 0, offset: 0, limit: 15)
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String?
    @Published public var pageSize: Int = 15

    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var hasMore: Bool {
        activities.count < pagination.totalCount
    }

    public func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await store.api.getActivities(offset: 0, limit: pageSize, language: store.language)
            self.activities = result.items
            self.pagination = result.page ?? Pagination(totalCount: 0, offset: 0, limit: pageSize)
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
            let result = try await store.api.getActivities(
                offset: activities.count,
                limit: pageSize,
                language: store.language
            )
            self.activities += result.items
            self.pagination = result.page
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func refresh() async {
        await loadInitial()
    }
}
