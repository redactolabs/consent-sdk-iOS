import Foundation
import SwiftUI

/// Notification hub (React NotificationHub/* and NotificationsPage.tsx): the
/// bell's unread badge and recent list, and the full page with its summary,
/// category tabs and pages of ten. Both poll every 30 seconds.
@MainActor
public final class NotificationsViewModel: ObservableObject {
    public enum FilterTab: String, CaseIterable {
        case all, consent, request, system

        var category: PrivacyNotificationCategory? {
            switch self {
            case .all: return nil
            case .consent: return .consent
            case .request: return .request
            case .system: return .system
            }
        }

        var label: String {
            switch self {
            case .all: return PCStrings.all
            case .consent: return PCStrings.consent
            case .request: return PCStrings.requests
            case .system: return PCStrings.system
            }
        }
    }

    /// What a CTA did (React `handleCTAClick`).
    public enum CTAResult: Equatable {
        case acknowledged, navigated, opened(URL), notFound
    }

    public static let pageSize = 10
    public static let dropdownLimit = 5
    static let pollIntervalNanoseconds: UInt64 = 30_000_000_000
    static let caseDetailsPrefix = "/case-details/"

    @Published public var notifications: [PrivacyNotification] = []
    @Published public var recent: [PrivacyNotification] = []
    @Published public var summary = PrivacyNotificationSummary()
    @Published public var unreadCount = 0
    @Published public var activeTab: FilterTab = .all
    @Published public var skip = 0
    @Published public var totalCount = 0
    @Published public var isLoading = false
    @Published public var isRefreshing = false

    private let store: PrivacyCenterStore
    private var pollTask: Task<Void, Never>?

    deinit {
        pollTask?.cancel()
    }

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var hasMore: Bool { skip + Self.pageSize < totalCount }

    // MARK: - Bell

    public func pollUnreadCount() async {
        let blocked = await store.tokenStore.isRefreshBlocked()
        guard !store.isSessionExpired, !blocked else { return }
        if let result = try? await store.api.getUnreadNotificationCount() {
            unreadCount = result.count
        }
    }

    public func loadRecent() async {
        do {
            let result = try await store.api.getNotifications(limit: Self.dropdownLimit, includeSummary: true, language: store.langParam)
            recent = Array(result.data.prefix(Self.dropdownLimit))
            if let summary = result.summary { unreadCount = summary.unread }
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
        }
    }

    public func refreshRecent() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await loadRecent()
    }

    public func startBellPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            // `self?` yields nil once the Privacy Center is gone, ending the loop.
            while !Task.isCancelled, await self?.pollUnreadCount() != nil {
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
            }
        }
    }

    // MARK: - Page

    public func load(includeSummary: Bool = true, silent: Bool = false) async {
        let blocked = await store.tokenStore.isRefreshBlocked()
        if store.isSessionExpired || blocked {
            isLoading = false
            isRefreshing = false
            return
        }
        if !silent { isLoading = true }
        defer {
            isLoading = false
            isRefreshing = false
        }
        do {
            let result = try await store.api.getNotifications(
                category: activeTab.category,
                skip: skip,
                limit: Self.pageSize,
                includeSummary: includeSummary,
                language: store.langParam
            )
            notifications = result.data
            if let summary = result.summary { self.summary = summary }
            totalCount = result.total
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
        }
    }

    public func setTab(_ tab: FilterTab) {
        guard tab != activeTab else { return }
        activeTab = tab
        skip = 0
        Task { await load(includeSummary: true) }
    }

    public func setSkip(_ value: Int) {
        skip = max(0, value)
        Task { await load(includeSummary: true) }
    }

    public func refreshPage() async {
        isRefreshing = true
        await load(includeSummary: true)
    }

    public func startPagePolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
                guard !Task.isCancelled, await self?.load(includeSummary: false, silent: true) != nil else { break }
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Actions

    private func markRead(_ uuid: String) async -> Bool {
        do {
            try await store.api.markNotificationRead(uuid: uuid)
            return true
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
            return false
        }
    }

    private func acknowledge(_ uuid: String) async -> Bool {
        do {
            try await store.api.acknowledgeNotification(uuid: uuid)
            return true
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
            return false
        }
    }

    private func update(_ uuid: String, read: Bool? = nil, acknowledged: Bool? = nil) {
        func apply(_ list: inout [PrivacyNotification]) {
            for index in list.indices where list[index].uuid == uuid {
                if let read { list[index].isRead = read }
                if let acknowledged { list[index].isAcknowledged = acknowledged }
            }
        }
        apply(&notifications)
        apply(&recent)
    }

    public func markAllRead() async {
        do {
            try await store.api.markAllNotificationsRead()
            for index in notifications.indices { notifications[index].isRead = true }
            for index in recent.indices { recent[index].isRead = true }
            summary.unread = 0
            unreadCount = 0
        } catch {
            if !isSilentPrivacyCenterError(error) { store.reportError(error) }
        }
    }

    /// Opening a row marks it read and, when it offers no acknowledge button,
    /// acknowledges it on the page (React `onNotificationClick`); the bell only
    /// marks it read.
    public func open(_ notification: PrivacyNotification, fromPage: Bool) async {
        let shouldRead = !notification.isRead
        let shouldAcknowledge = fromPage && !notification.isAcknowledged && !notification.hasAcknowledgeCTA
        guard shouldRead || shouldAcknowledge else { return }
        let read = shouldRead ? await markRead(notification.uuid) : false
        let acknowledged = shouldAcknowledge ? await acknowledge(notification.uuid) : false
        guard read || acknowledged else { return }
        update(notification.uuid, read: read ? true : nil, acknowledged: acknowledged ? true : nil)
        if read {
            summary.unread = max(0, summary.unread - 1)
            unreadCount = max(0, unreadCount - 1)
        }
        if acknowledged { summary.acknowledged += 1 }
    }

    /// A CTA only renders when pressing it can do something.
    public static func isActionable(_ cta: PrivacyNotificationCTA) -> Bool {
        guard !cta.label.isEmpty else { return false }
        switch cta.actionType {
        case .acknowledge: return true
        case .link: return cta.url.pcNonEmpty != nil
        case nil: return false
        }
    }

    public func performCTA(_ cta: PrivacyNotificationCTA, on notification: PrivacyNotification, fromPage: Bool) async -> CTAResult? {
        if cta.actionType == .acknowledge {
            guard await acknowledge(notification.uuid) else { return nil }
            update(notification.uuid, read: true, acknowledged: true)
            if !notification.isRead {
                summary.unread = max(0, summary.unread - 1)
                unreadCount = max(0, unreadCount - 1)
            }
            if !notification.isAcknowledged { summary.acknowledged += 1 }
            return .acknowledged
        }
        guard cta.actionType == .link, let url = cta.url.pcNonEmpty else { return nil }
        if !notification.isRead { _ = await markRead(notification.uuid) }
        let result: CTAResult?
        if url.hasPrefix(Self.caseDetailsPrefix) {
            let caseUuid = String(url.dropFirst(Self.caseDetailsPrefix.count))
            let cases = (try? await store.api.getCaseHistory(language: store.langParam).items) ?? []
            if let found = cases.first(where: { $0.uuid == caseUuid }) {
                store.openCase(found)
                result = .navigated
            } else {
                result = .notFound
            }
        } else if let parsed = URL(string: url), ["http", "https"].contains(parsed.scheme?.lowercased() ?? "") {
            result = .opened(parsed)
        } else {
            return nil
        }
        if !notification.isRead {
            update(notification.uuid, read: true)
            summary.unread = max(0, summary.unread - 1)
            unreadCount = max(0, unreadCount - 1)
        }
        return result
    }
}
