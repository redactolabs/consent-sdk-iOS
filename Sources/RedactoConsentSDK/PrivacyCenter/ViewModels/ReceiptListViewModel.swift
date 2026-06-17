import Foundation
import SwiftUI

/// Event-type filter (drives the `event_type` query param).
public enum ReceiptEventFilter: String, CaseIterable, Hashable, Sendable {
    case granted = "GRANTED"
    case withdrawn = "WITHDRAWN"
    case declined = "DECLINED"
    case expired = "EXPIRED"
}

/// Purpose-status filter (drives the `status` query param).
public enum ReceiptStatusFilter: String, CaseIterable, Hashable, Sendable {
    case consented = "CONSENTED"
    case declined = "DECLINED"
    case withdrawn = "WITHDRAWN"
}

/// Date filter — presets map to `created_after`; `.custom` uses the From/To pickers.
public enum ReceiptDateFilter: String, CaseIterable, Hashable, Sendable {
    case today = "1"
    case last7Days = "7"
    case last30Days = "30"
    case last3Months = "90"
    case custom = "custom"
}

@MainActor
public final class ReceiptListViewModel: ObservableObject {
    @Published public var receipts: [Receipt] = []
    @Published public var pagination: Pagination = Pagination(totalCount: 0, offset: 0, limit: 10)
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false
    @Published public var errorMessage: String?
    @Published public var pageSize: Int = 10

    // Per-row download state.
    @Published public var downloadingUuid: String?
    @Published public var downloadError: String?

    // MARK: - Filters
    @Published public var eventType: ReceiptEventFilter? {
        didSet { if oldValue != eventType { Task { await reload() } } }
    }
    @Published public var datePreset: ReceiptDateFilter? {
        didSet {
            if oldValue != datePreset {
                if datePreset != .custom { customFrom = nil; customTo = nil }
                Task { await reload() }
            }
        }
    }
    @Published public var customFrom: Date?
    @Published public var customTo: Date?

    private let store: PrivacyCenterStore

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var hasMore: Bool {
        receipts.count < pagination.totalCount
    }

    public var hasActiveFilters: Bool {
        eventType != nil || datePreset != nil
    }

    /// The custom range is invalid when From is after To.
    public var isCustomRangeInvalid: Bool {
        guard datePreset == .custom, let from = customFrom, let to = customTo else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: from) > cal.startOfDay(for: to)
    }

    // MARK: - Date params (mirror the React dateRangeParams)
    private func dateRangeParams() -> (after: String?, before: String?) {
        guard let preset = datePreset else { return (nil, nil) }
        let cal = Calendar.current
        let now = Date()
        switch preset {
        case .custom:
            let after = customFrom.map { PrivacyCenterDateFormatters.iso8601.string(from: cal.startOfDay(for: $0)) }
            let before = customTo.map { PrivacyCenterDateFormatters.iso8601.string(from: endOfDay(for: $0, calendar: cal)) }
            return (after, before)
        case .today:
            return (PrivacyCenterDateFormatters.iso8601.string(from: cal.startOfDay(for: now)), nil)
        case .last7Days, .last30Days, .last3Months:
            let days = Int(preset.rawValue) ?? 0
            guard let shifted = cal.date(byAdding: .day, value: -days, to: now) else { return (nil, nil) }
            return (PrivacyCenterDateFormatters.iso8601.string(from: cal.startOfDay(for: shifted)), nil)
        }
    }

    private func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    // MARK: - Loading
    public func loadInitial() async {
        if isCustomRangeInvalid { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let range = dateRangeParams()
        do {
            let result = try await store.api.getReceipts(
                skip: 0,
                limit: pageSize,
                eventType: eventType?.rawValue,
                createdAfter: range.after,
                createdBefore: range.before,
                language: store.language
            )
            self.receipts = result.items
            self.pagination = result.page
        } catch {
            if !isCancellationError(error) {
                errorMessage = PCStrings.failedToFetchReceipts
                store.reportError(error)
            }
        }
    }

    public func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let range = dateRangeParams()
        do {
            let result = try await store.api.getReceipts(
                skip: receipts.count,
                limit: pageSize,
                eventType: eventType?.rawValue,
                createdAfter: range.after,
                createdBefore: range.before,
                language: store.language
            )
            self.receipts += result.items
            self.pagination = result.page
        } catch {
            if !isCancellationError(error) {
                errorMessage = PCStrings.failedToFetchReceipts
                store.reportError(error)
            }
        }
    }

    public func refresh() async {
        await loadInitial()
    }

    /// Changing any filter resets to page 1 (i.e. a fresh load from skip = 0).
    public func reload() async {
        await loadInitial()
    }

    public func applyCustomRange() async {
        guard datePreset == .custom else { return }
        await reload()
    }

    public func clearFilters() {
        eventType = nil
        datePreset = nil
        customFrom = nil
        customTo = nil
    }

    // MARK: - Download
    /// Fetch the receipt PDF bytes and write them to a temporary file for sharing.
    /// Returns the on-disk URL on success, or nil on failure.
    public func downloadReceipt(_ receipt: Receipt) async -> URL? {
        guard downloadingUuid == nil else { return nil }
        downloadingUuid = receipt.uuid
        downloadError = nil
        defer { downloadingUuid = nil }
        do {
            let data = try await store.api.getReceiptPdf(receiptUuid: receipt.uuid)
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("receipt-\(receipt.uuid).pdf")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            if !isCancellationError(error) {
                downloadError = PCStrings.failedToDownloadReceipt
                store.reportError(error)
            }
            return nil
        }
    }
}
