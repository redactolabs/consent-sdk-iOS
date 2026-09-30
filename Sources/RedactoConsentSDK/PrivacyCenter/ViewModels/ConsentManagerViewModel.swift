import Foundation
import SwiftUI

@MainActor
public final class ConsentManagerViewModel: ObservableObject {
    public enum ConsentTab: String, CaseIterable {
        case direct, nominated
    }

    /// React's "Consent visibility" toggle: product cards or a flat purpose list.
    public enum ViewMode: String, CaseIterable {
        case product, purpose
    }

    /// A product card as React draws it (`DisplayProductGroup`): purposes
    /// filtered by the search and status, with per-status counts.
    public struct DisplayGroup: Identifiable, Equatable {
        public let group: ProductConsentHistoryGroup
        public let purposes: [UserConsent]
        public let activeCount: Int
        public let withdrawnCount: Int
        public let expiredCount: Int
        public let declinedCount: Int
        public let latestGivenDate: String?
        public let key: String

        public var id: String { key }
        public var nominator: NominatorInfo? { group.purposes.first?.nominatorInfo }
    }

    @Published public var activeTab: ConsentTab = .direct
    @Published public var viewMode: ViewMode = .product
    @Published public var searchText: String = ""
    @Published public var debouncedSearch: String = ""
    @Published public var statusFilter: ConsentStatus?
    @Published public var productFilter: String?
    @Published public var currentPage: Int = 1
    @Published public var pageSize: Int = 10
    @Published public var isLoading: Bool = false
    @Published public var detail: UserConsentDetail?
    @Published public var errorMessage: String?
    @Published public var actionInProgress: Bool = false
    @Published public var actionMessage: String?
    @Published public var selectedNominator: NominatorInfo?
    @Published public var extraPurposes: [String: [UserConsent]] = [:]
    @Published public var moreAvailable: [String: Bool] = [:]
    @Published public var loadingMoreCards: Set<String> = []
    @Published public var expandedCards: Set<String> = []
    /// Kept from the last unfiltered read, so choosing a product never shrinks
    /// the list to that one product.
    @Published public private(set) var productOptions: [(uuid: String, name: String)] = []

    static let groupPurposesPageSize = 50
    static let searchDebounceNanoseconds: UInt64 = 500_000_000
    public static let pageSizeOptions = [5, 10, 15, 20, 25]

    private let store: PrivacyCenterStore
    private var debounceTask: Task<Void, Never>?
    private var purposesGeneration = 0

    public init(store: PrivacyCenterStore) {
        self.store = store
    }

    public var directGroups: [ProductConsentHistoryGroup] {
        ConsentManagerNormalization.directGroups(from: detail)
    }

    public var nominatedGroups: [NominatedPurposesGroup] {
        detail?.nominatedPurposes ?? []
    }

    public var nominatedProductGroups: [ProductConsentHistoryGroup] {
        ConsentManagerNormalization.nominatedGroups(from: detail)
    }

    public var activeGroups: [ProductConsentHistoryGroup] {
        activeTab == .direct ? directGroups : nominatedProductGroups
    }

    public var totalCount: Int {
        guard let detail else { return 0 }
        switch activeTab {
        case .direct: return detail.directPagination?.totalCount ?? detail.pagination?.totalCount ?? 0
        case .nominated: return detail.nominatedPagination?.totalCount ?? detail.pagination?.totalCount ?? 0
        }
    }

    public var totalPages: Int { max(1, (totalCount + pageSize - 1) / pageSize) }

    public var statusOptions: [ConsentStatus] {
        [.active, .withdrawn, .expired, .declined]
    }

    /// Tab badges (React `status_summary.direct_purposes` / `nominated_purposes`).
    public var directBadge: Int? { detail?.statusSummary?.directPurposes }
    public var nominatedBadge: Int? { detail?.statusSummary?.nominatedPurposes }

    /// The nominators whose consents this person manages, for the Managing tab.
    public var nominatorLabels: [String] {
        (detail?.nominators ?? []).compactMap { nominator in
            nominator.email.pcNonEmpty?.trimmingCharacters(in: .whitespaces)
                ?? nominator.orgUserId.nonEmpty
                ?? nominator.uuid.nonEmpty
        }
    }

    public var userStatus: UserStatus? { detail?.userStatus }

    // MARK: - Filtering (React buildDisplayGroups / filterConsentRows)

    private func matches(_ consent: UserConsent, normalizedSearch: String) -> Bool {
        let matchesSearch = normalizedSearch.isEmpty || [
            consent.purpose, consent.purposeDescription, consent.productName ?? "",
            consent.productDescription ?? "", consent.method, consent.statusText ?? consent.status.rawValue,
        ].contains { !$0.isEmpty && $0.lowercased().contains(normalizedSearch) }
        let matchesStatus = statusFilter.map { consent.status == $0 } ?? true
        return matchesSearch && matchesStatus
    }

    public var displayGroups: [DisplayGroup] {
        let search = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        return activeGroups.compactMap { group in
            if let productFilter, group.productUuid != productFilter { return nil }
            let filtered = group.purposes.filter { matches($0, normalizedSearch: search) }
            guard !filtered.isEmpty else { return nil }
            var latest: (date: Date, raw: String)?
            for consent in filtered {
                guard let date = PrivacyCenterDateFormatters.parse(consent.givenDate) else { continue }
                if latest == nil || date > latest!.date { latest = (date, consent.givenDate) }
            }
            return DisplayGroup(
                group: group,
                purposes: filtered,
                activeCount: filtered.filter { $0.status == .active }.count,
                withdrawnCount: filtered.filter { $0.status == .withdrawn }.count,
                expiredCount: filtered.filter { $0.status == .expired }.count,
                declinedCount: filtered.filter { $0.status == .declined }.count,
                latestGivenDate: latest?.raw,
                key: cardKey(for: group)
            )
        }
    }

    public var displayRows: [UserConsent] {
        let search = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        return activeGroups.flatMap(\.purposes).filter { row in
            matches(row, normalizedSearch: search) && (productFilter.map { row.productUuid == $0 } ?? true)
        }
    }

    public var summaryText: String {
        switch viewMode {
        case .product:
            let groups = displayGroups
            return PCStrings.productsAndConsentsSummary(groups.count, consents: groups.reduce(0) { $0 + $1.purposes.count })
        case .purpose:
            let rows = displayRows
            let products = Set(rows.compactMap { $0.productUuid.pcNonEmpty ?? $0.productName.pcNonEmpty })
            return PCStrings.productsAndConsentsSummary(products.count, consents: rows.count)
        }
    }

    // MARK: - Filters

    public func setSearch(_ text: String) {
        searchText = text
        currentPage = 1
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.searchDebounceNanoseconds)
            guard !Task.isCancelled, let self else { return }
            self.debouncedSearch = text
            await self.refresh()
        }
    }

    public func setStatusFilter(_ status: ConsentStatus?) {
        statusFilter = status
        currentPage = 1
        expandedCards = []
        Task { await refresh() }
    }

    public func setProductFilter(_ productUuid: String?) {
        productFilter = productUuid
        currentPage = 1
        expandedCards = []
        Task { await refresh() }
    }

    public func setActiveTab(_ tab: ConsentTab) {
        activeTab = tab
        if tab == .direct {
            selectedNominator = nil
        }
        currentPage = 1
        expandedCards = []
        Task { await refresh() }
    }

    public func setViewMode(_ mode: ViewMode) {
        guard mode != viewMode else { return }
        viewMode = mode
        currentPage = 1
        expandedCards = []
        Task { await refresh() }
    }

    public func selectNominator(_ nominator: NominatorInfo?) {
        selectedNominator = nominator
        currentPage = 1
        Task { await refresh() }
    }

    public func goToPage(_ page: Int) {
        currentPage = max(1, min(page, totalPages))
        expandedCards = []
        Task { await refresh() }
    }

    public func setPageSize(_ size: Int) {
        pageSize = size
        currentPage = 1
        expandedCards = []
        Task { await refresh() }
    }

    public func toggleCard(_ key: String) {
        if expandedCards.contains(key) { expandedCards.remove(key) } else { expandedCards.insert(key) }
    }

    private var refreshGeneration = 0

    public func refresh() async {
        if store.isSessionExpired { return }
        purposesGeneration += 1
        // A quicker filter, tab or page change starts a newer refresh; an older
        // response that lands after it must not replace its list.
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        errorMessage = nil
        defer { if generation == refreshGeneration { isLoading = false } }
        do {
            let offset = (currentPage - 1) * pageSize
            let search = debouncedSearch.trimmingCharacters(in: .whitespaces)
            let result = try await store.api.getUserConsents(
                offset: activeTab == .direct ? offset : nil,
                limit: activeTab == .direct ? pageSize : nil,
                nominatedOffset: activeTab == .nominated ? offset : nil,
                nominatedLimit: activeTab == .nominated ? pageSize : nil,
                search: search.isEmpty ? nil : search,
                status: statusFilter?.rawValue,
                productUuid: productFilter,
                language: store.langParam
            )
            guard generation == refreshGeneration else { return }
            purposesGeneration += 1
            self.extraPurposes = [:]
            self.moreAvailable = [:]
            self.detail = result
            if productFilter == nil {
                var seen = Set<String>()
                let groups = (result.direct ?? []).map { ($0.productUuid, $0.productName) }
                    + (result.nominated ?? []).map { ($0.productUuid, $0.productName) }
                let fallback = (directGroups + nominatedProductGroups).map { ($0.productUuid, $0.productName) }
                productOptions = (groups.isEmpty ? fallback : groups).compactMap { uuid, name in
                    seen.insert(uuid).inserted ? (uuid: uuid, name: name) : nil
                }
            }
        } catch {
            if isSilentPrivacyCenterError(error) || generation != refreshGeneration { return }
            detail = nil
            productOptions = []
            extraPurposes = [:]
            moreAvailable = [:]
            errorMessage = PCStrings.failedToFetchConsentData
            store.showToast(PCStrings.failedToFetchConsentData, kind: .error)
            store.reportError(error)
        }
    }

    public func cardKey(for group: ProductConsentHistoryGroup) -> String {
        if let nominatorUuid = group.purposes.first?.nominatorInfo?.uuid {
            return "nominated:\(nominatorUuid):\(group.productUuid)"
        }
        return "direct:\(group.productUuid)"
    }

    public func purposes(in group: ProductConsentHistoryGroup) -> [UserConsent] {
        group.purposes + (extraPurposes[cardKey(for: group)] ?? [])
    }

    public func purposes(in display: DisplayGroup) -> [UserConsent] {
        display.purposes + (extraPurposes[display.key] ?? [])
    }

    public func hasMorePurposes(in group: ProductConsentHistoryGroup) -> Bool {
        if let known = moreAvailable[cardKey(for: group)] { return known }
        let nominatorUuid = group.purposes.first?.nominatorInfo?.uuid
        let source = ((detail?.direct ?? []) + (detail?.nominated ?? [])).first {
            $0.productUuid == group.productUuid && $0.nominator?.uuid == nominatorUuid
        }
        return source?.hasMorePurposes ?? false
    }

    public func loadMorePurposes(in group: ProductConsentHistoryGroup) async {
        let key = cardKey(for: group)
        guard !loadingMoreCards.contains(key) else { return }
        loadingMoreCards.insert(key)
        defer { loadingMoreCards.remove(key) }
        let nominator = group.purposes.first?.nominatorInfo
        let offset = purposes(in: group).count
        let generation = purposesGeneration
        let search = debouncedSearch.trimmingCharacters(in: .whitespaces)
        do {
            let result = try await store.api.getGroupPurposes(
                productUuid: group.productUuid,
                offset: offset,
                limit: Self.groupPurposesPageSize,
                status: statusFilter?.rawValue,
                search: search.isEmpty ? nil : search,
                language: store.langParam,
                nominatorUuid: nominator?.uuid
            )
            guard generation == purposesGeneration else { return }
            let rows = result.purposes.map {
                ConsentManagerNormalization.userConsent(
                    from: $0,
                    productUuid: group.productUuid,
                    productName: group.productName,
                    productDescription: group.productDescription,
                    nominator: nominator
                )
            }
            extraPurposes[key, default: []] += rows
            let fetched = offset + rows.count
            moreAvailable[key] = !rows.isEmpty && fetched < (result.pagination?.totalCount ?? fetched)
        } catch {
            if isSilentPrivacyCenterError(error) { return }
            store.showToast(PCStrings.failedToFetchConsentData, kind: .error)
            store.reportError(error)
        }
    }

    nonisolated public static func nominatorContact(for nominator: NominatorInfo?) -> String? {
        guard let nominator else { return nil }
        if let email = nominator.email, !email.isEmpty { return email }
        return nominator.orgUserId.isEmpty ? nil : nominator.orgUserId
    }

    public func performAction(
        on consent: UserConsent,
        action: ConsentAction,
        nominatorContact: String? = nil,
        dataElementUuids: [String]? = nil
    ) async {
        await performAction(
            purposeId: consent.purposeUuid ?? "",
            action: action,
            nominatorContact: Self.nominatorContact(for: consent.nominatorInfo) ?? nominatorContact,
            dataElementUuids: dataElementUuids,
            productUuid: consent.productUuid,
            noticeUuid: consent.noticeUuid,
            dataElements: consent.dataElements,
            nominatorUuid: consent.nominatorInfo?.uuid
        )
    }

    static func successMessage(_ action: ConsentAction) -> String {
        switch action {
        case .revoke: return PCStrings.consentRevokedSuccess
        case .regrant: return PCStrings.consentRegrantedSuccess
        case .renew: return PCStrings.consentRenewedSuccess
        }
    }

    /// React's failure toast: the nominator-specific message when the server
    /// named one, else the action's own.
    static func failureMessage(_ action: ConsentAction, error: Error?) -> String {
        switch error.flatMap(ConsentApiErrorCode.from) {
        case .nominatorNotFound: return PCStrings.nominatorNotFound
        case .nomineeMustSpecifyNominator: return PCStrings.nomineeMustSpecifyNominator
        case nil: return PrivacyCenterAPI.manageFailureMessage(action)
        }
    }

    public func performAction(
        purposeId: String,
        action: ConsentAction,
        nominatorContact: String? = nil,
        dataElementUuids: [String]? = nil,
        productUuid: String? = nil,
        noticeUuid: String? = nil,
        dataElements: [ConsentDataElement] = [],
        nominatorUuid: String? = nil
    ) async {
        guard let contact = store.contact.pcNonEmpty else {
            store.showToast(PCStrings.missingInfoToManage, kind: .error)
            return
        }
        actionInProgress = true
        defer { actionInProgress = false }
        do {
            try await store.api.manageConsent(ManageConsentRequest(
                purposeUuid: purposeId,
                contact: contact,
                action: action,
                productUuid: productUuid,
                noticeUuid: noticeUuid,
                dataElements: dataElements,
                dataElementUuids: dataElementUuids,
                nominatorContact: nominatorContact,
                nominatorUuid: nominatorUuid,
                language: store.langParam
            ))
            actionMessage = Self.successMessage(action)
            store.showToast(Self.successMessage(action), kind: .success)
            await refresh()
        } catch {
            if isCancellationError(error) { return }
            store.showToast(Self.failureMessage(action, error: error), kind: .error)
            store.reportError(error)
        }
    }

    // MARK: - Export (React handleExport / exportTableToCSV)

    public static func statusLabel(_ consent: UserConsent) -> String {
        switch consent.status {
        case .active: return PCStrings.statusActive
        case .withdrawn:
            return (consent.statusText ?? "").uppercased() == "REVOKED" ? PCStrings.statusRevoked : PCStrings.statusWithdrawn
        case .expired: return PCStrings.statusExpired
        case .declined: return PCStrings.statusDeclined
        case .unknown: return consent.statusText ?? ""
        }
    }

    /// React `getValidTillLabel`.
    public static func validTillLabel(_ consent: UserConsent) -> String {
        switch consent.status {
        case .declined, .withdrawn: return "-"
        case .active where consent.validTill == nil: return PCStrings.untilWithdrawalNoExpiry
        default:
            guard let validTill = consent.validTill.pcNonEmpty else { return "-" }
            return PrivacyCenterDateFormatters.formatDate(validTill)
        }
    }

    /// The rows on screen, as their visible labels.
    public var exportRows: [[String]] {
        let rows: [UserConsent] = viewMode == .product
            ? displayGroups.flatMap(\.purposes)
            : displayRows
        return rows.map { consent in
            [
                consent.purpose,
                consent.purposeDescription,
                consent.productName.pcNonEmpty ?? "-",
                Self.statusLabel(consent),
                PrivacyCenterDateFormatters.formatDateTime(consent.givenDate),
                Self.validTillLabel(consent),
                consent.method,
            ]
        }
    }

    public static var exportHeaders: [String] {
        [PCStrings.purpose, PCStrings.descriptionLabel, PCStrings.product, PCStrings.status,
         PCStrings.givenDate, PCStrings.validTill, PCStrings.method]
    }

    /// UTF-8 CSV with a BOM, each cell quoted and a leading formula character
    /// defused, as React writes it.
    public static func csv(headers: [String], rows: [[String]]) -> String {
        let triggers: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]
        func escape(_ value: String) -> String {
            let safe = value.first.map { triggers.contains($0) } == true ? "'\(value)" : value
            return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        let lines = [headers.map(escape).joined(separator: ",")] + rows.map { $0.map(escape).joined(separator: ",") }
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    /// Writes `consent-records.csv` for the share sheet; nil when nothing is shown.
    public func exportCSV() -> URL? {
        let rows = exportRows
        guard !rows.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("consent-records.csv")
        do {
            try Data(Self.csv(headers: Self.exportHeaders, rows: rows).utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
