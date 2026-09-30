import Foundation
import SwiftUI

/// The activity timeline (React ActivitiesList.tsx): pages of ten, loaded as
/// the end of the list comes into view.
@MainActor
public final class ActivityListViewModel: ObservableObject {
    /// Activities of one calendar day, newest first as the server orders them.
    public struct DayGroup: Identifiable, Equatable {
        public let key: String
        public let label: String
        public let newest: String
        public let items: [Activity]
        public var id: String { key }
    }

    @Published public var activities: [Activity] = []
    @Published public var pagination: Pagination = Pagination(totalCount: 0, offset: 0, limit: 10)
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String?
    @Published public var pageSize: Int = 10

    private let store: PrivacyCenterStore
    private var generation = 0

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var hasMore: Bool {
        activities.count < pagination.totalCount
    }

    public var dayGroups: [DayGroup] {
        var order: [String] = []
        var byKey: [String: [Activity]] = [:]
        for activity in activities {
            let key = PrivacyCenterDateFormatters.dayKey(activity.timestamp)
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(activity)
        }
        return order.map { key in
            let items = byKey[key] ?? []
            return DayGroup(
                key: key,
                label: PrivacyCenterDateFormatters.formatDate(items.first?.timestamp),
                newest: items.first?.timestamp ?? "",
                items: items
            )
        }
    }

    public func loadInitial() async {
        if store.isSessionExpired { return }
        generation += 1
        let current = generation
        isLoading = true
        errorMessage = nil
        activities = []
        pagination = Pagination(totalCount: 0, offset: 0, limit: pageSize)
        defer { if current == generation { isLoading = false } }
        do {
            let result = try await store.api.getActivities(offset: 0, limit: pageSize, language: store.langParam)
            guard current == generation else { return }
            self.activities = result.items
            self.pagination = result.page
        } catch {
            guard current == generation, !isSilentPrivacyCenterError(error) else { return }
            errorMessage = PCStrings.failedToFetchActivityData
            store.showToast(PCStrings.failedToFetchActivityData, kind: .error)
            store.reportError(error)
        }
    }

    public func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        let current = generation
        isLoadingMore = true
        defer { if current == generation { isLoadingMore = false } }
        do {
            let result = try await store.api.getActivities(
                offset: activities.count,
                limit: pageSize,
                language: store.langParam
            )
            guard current == generation else { return }
            self.activities += result.items
            self.pagination = result.pagination ?? pagination
        } catch {
            guard current == generation, !isSilentPrivacyCenterError(error) else { return }
            store.showToast(PCStrings.failedToFetchActivityData, kind: .error)
            store.reportError(error)
        }
    }

    public func refresh() async {
        await loadInitial()
    }
}
