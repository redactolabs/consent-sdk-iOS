import SwiftUI

public struct ConsentManagerScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: ConsentManagerViewModel
    @State private var modifyTarget: UserConsent?
    @State private var modifyNominator: String?

    public init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: ConsentManagerViewModel(store: store))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabs
                filters
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(theme.background)
        .refreshable { await vm.refresh() }
        .task { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.refresh() }
        }
        .sheet(item: $modifyTarget) { consent in
            ModifyConsentModal(consent: consent, nominatorContact: modifyNominator, consentManagerVm: vm)
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let msg = vm.actionMessage {
                actionBanner(msg)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PCStrings.manageConsent)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.text)
            Text(PCStrings.manageConsentSubtitle)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var tabs: some View {
        HStack(spacing: 0) {
            tabPill(.direct, label: PCStrings.direct)
            tabPill(.nominated, label: PCStrings.nominated)
        }
        .padding(4)
        .background(theme.surface)
        .cornerRadius(10)
    }

    @ViewBuilder
    private func tabPill(_ tab: ConsentManagerViewModel.ConsentTab, label: String) -> some View {
        let isActive = vm.activeTab == tab
        Button(action: { vm.setActiveTab(tab) }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? theme.primaryText : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isActive ? theme.primary : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            PCInput(
                text: Binding(get: { vm.searchText }, set: { vm.setSearch($0) }),
                placeholder: PCStrings.search,
                leadingIcon: "magnifyingglass"
            )
            PCAdaptiveColumns(minColumnWidth: 150, spacing: 10) {
                PCSelect(
                    selection: Binding(get: { vm.statusFilter }, set: { vm.setStatusFilter($0) }),
                    options: vm.statusOptions.map { PCSelectOption(value: $0, label: localizedStatus($0)) },
                    placeholder: PCStrings.status
                )
                PCSelect(
                    selection: Binding(get: { vm.productFilter }, set: { vm.setProductFilter($0) }),
                    options: vm.productOptions.map { PCSelectOption(value: $0.uuid, label: $0.name) },
                    placeholder: PCStrings.product
                )
            }
            if vm.activeTab == .nominated, let nominators = vm.detail?.nominators, !nominators.isEmpty {
                PCSelect(
                    selection: Binding(
                        get: { vm.selectedNominator?.uuid },
                        set: { id in vm.selectNominator(nominators.first { $0.uuid == id }) }
                    ),
                    options: nominators.map { PCSelectOption(value: $0.uuid, label: $0.name ?? $0.email ?? $0.orgUserId) },
                    placeholder: PCStrings.nominated
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in PCSkeletonCard() }
            }
        } else if let err = vm.errorMessage {
            PCEmpty(title: PCStrings.error, subtitle: err, icon: "exclamationmark.triangle")
        } else if vm.activeTab == .direct {
            directList
        } else {
            nominatedList
        }
    }

    @ViewBuilder
    private var directList: some View {
        let groups = vm.directGroups
        if groups.isEmpty {
            PCEmpty(title: PCStrings.noConsents, icon: "shield")
        } else {
            ForEach(groups) { group in
                productGroupCard(group: group, nominator: nil)
            }
            paginationBar
        }
    }

    @ViewBuilder
    private var nominatedList: some View {
        if vm.nominatedProductGroups.isEmpty && vm.nominatedGroups.isEmpty {
            PCEmpty(title: PCStrings.noConsents, icon: "person.2")
        } else if !vm.nominatedProductGroups.isEmpty {
            ForEach(vm.nominatedProductGroups) { group in
                productGroupCard(
                    group: group,
                    nominator: group.purposes.first?.nominatorInfo?.email
                )
            }
            paginationBar
        } else {
            ForEach(vm.nominatedGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PCAvatar(initial: String((group.nominatorInfo.name ?? group.nominatorInfo.email ?? "?").prefix(1)), size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.nominatorInfo.name ?? group.nominatorInfo.email ?? group.nominatorInfo.orgUserId)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.text)
                            if let email = group.nominatorInfo.email {
                                Text(email)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    ForEach(group.productGroups) { sub in
                        productGroupCard(group: sub, nominator: group.nominatorInfo.email)
                    }
                }
            }
            paginationBar
        }
    }

    @ViewBuilder
    private func productGroupCard(group: ProductConsentHistoryGroup, nominator: String?) -> some View {
        PCCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(group.productName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("\(group.activePurposes)/\(group.totalPurposes)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
                if let desc = group.productDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(3)
                }
                ForEach(group.purposes) { consent in
                    consentRow(consent: consent, nominator: nominator)
                }
            }
        }
    }

    @ViewBuilder
    private func consentRow(consent: UserConsent, nominator: String?) -> some View {
        Button(action: {
            modifyTarget = consent
            modifyNominator = nominator
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(consent.purpose)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                    Spacer()
                    PCStatusBadge(status: consent.status)
                }
                Text(consent.purposeDescription)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Text("\(PCStrings.givenOn) \(PrivacyCenterDateFormatters.formatDate(consent.givenDate))")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                    if let validTill = consent.validTill, !validTill.isEmpty {
                        Text("\(PCStrings.validTill) \(PrivacyCenterDateFormatters.formatDate(validTill))")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(theme.surfaceElevated)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var paginationBar: some View {
        if vm.totalPages > 1 {
            HStack {
                Button(action: { vm.goToPage(vm.currentPage - 1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 32, height: 32)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .disabled(vm.currentPage == 1)
                .opacity(vm.currentPage == 1 ? 0.4 : 1)
                Spacer()
                Text("\(vm.currentPage) / \(vm.totalPages)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: { vm.goToPage(vm.currentPage + 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 32, height: 32)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .disabled(vm.currentPage >= vm.totalPages)
                .opacity(vm.currentPage >= vm.totalPages ? 0.4 : 1)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func actionBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.badgeSuccessText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.badgeSuccessBg)
            .cornerRadius(8)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    vm.actionMessage = nil
                }
            }
    }

    private func localizedStatus(_ status: ConsentStatus) -> String {
        switch status {
        case .active: return PCStrings.statusActive
        case .withdrawn: return PCStrings.statusWithdrawn
        case .expired: return PCStrings.statusExpired
        case .declined: return PCStrings.statusDeclined
        }
    }
}
