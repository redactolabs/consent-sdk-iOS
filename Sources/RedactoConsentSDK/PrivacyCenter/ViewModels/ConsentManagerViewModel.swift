import Foundation
import SwiftUI

@MainActor
public final class ConsentManagerViewModel: ObservableObject {
    public enum ConsentTab: String, CaseIterable {
        case direct, nominated
    }

    @Published public var activeTab: ConsentTab = .direct
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

    private let store: PrivacyCenterStore
    private var debounceTask: Task<Void, Never>?

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

    public var totalCount: Int {
        guard let detail else { return 0 }
        switch activeTab {
        case .direct:
            return detail.statusSummary?.directPurposes
                ?? detail.directPagination?.totalCount
                ?? detail.pagination?.totalCount
                ?? 0
        case .nominated:
            return detail.statusSummary?.nominatedPurposes
                ?? detail.nominatedPagination?.totalCount
                ?? detail.pagination?.totalCount
                ?? 0
        }
    }
    public var totalPages: Int { max(1, (totalCount + pageSize - 1) / pageSize) }

    public var statusOptions: [ConsentStatus] {
        [.active, .withdrawn, .expired, .declined]
    }

    public var productOptions: [(uuid: String, name: String)] {
        ConsentManagerNormalization.directGroups(from: detail).map { ($0.productUuid, $0.productName) }
    }

    public func setSearch(_ text: String) {
        searchText = text
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                guard let self else { return }
                if !Task.isCancelled {
                    self.debouncedSearch = text
                    self.currentPage = 1
                    Task { await self.refresh() }
                }
            }
        }
    }

    public func setStatusFilter(_ status: ConsentStatus?) {
        statusFilter = status
        currentPage = 1
        Task { await refresh() }
    }

    public func setProductFilter(_ productUuid: String?) {
        productFilter = productUuid
        currentPage = 1
        Task { await refresh() }
    }

    public func setActiveTab(_ tab: ConsentTab) {
        activeTab = tab
        if tab == .direct {
            selectedNominator = nil
        }
        currentPage = 1
        Task { await refresh() }
    }

    public func selectNominator(_ nominator: NominatorInfo?) {
        selectedNominator = nominator
        currentPage = 1
        Task { await refresh() }
    }

    public func goToPage(_ page: Int) {
        currentPage = max(1, min(page, totalPages))
        Task { await refresh() }
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let offset = (currentPage - 1) * pageSize
            let result = try await store.api.getUserConsents(
                offset: activeTab == .direct ? offset : nil,
                limit: activeTab == .direct ? pageSize : nil,
                nominatedOffset: activeTab == .nominated ? offset : nil,
                nominatedLimit: activeTab == .nominated ? pageSize : nil,
                search: debouncedSearch.isEmpty ? nil : debouncedSearch,
                status: statusFilter?.rawValue,
                productUuid: productFilter,
                language: store.language
            )
            self.detail = result
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }

    public func performAction(
        purposeId: String,
        action: ConsentAction,
        nominatorContact: String? = nil,
        dataElementUuids: [String]? = nil
    ) async {
        guard let contact = store.contact else { return }
        actionInProgress = true
        defer { actionInProgress = false }
        do {
            try await store.api.manageConsent(
                purposeId: purposeId,
                contact: contact,
                action: action,
                nominatorContact: nominatorContact,
                dataElementUuids: dataElementUuids
            )
            switch action {
            case .revoke: actionMessage = PCStrings.consentRevokedSuccess
            case .regrant: actionMessage = PCStrings.consentRegrantedSuccess
            case .renew: actionMessage = PCStrings.consentRenewedSuccess
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            await refresh()
        } catch {
            if !isCancellationError(error) {
                errorMessage = error.localizedDescription
                store.reportError(error)
            }
        }
    }
}
