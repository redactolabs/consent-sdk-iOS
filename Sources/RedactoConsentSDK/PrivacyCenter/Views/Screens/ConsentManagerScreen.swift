import SwiftUI

/// Consent Manager as React draws it on a phone (ConsentManager.tsx with
/// ConsentManagerProductCards / ConsentManagerPurposeCards).
public struct ConsentManagerScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: ConsentManagerViewModel
    @State private var modifyTarget: UserConsent?
    @State private var showExportConfirm = false
    @State private var exportURL: URL?

    public init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: ConsentManagerViewModel(store: store))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PCPageHeader(title: PCStrings.manageConsent, description: PCStrings.manageConsentSubtitle, status: headerStatus)
                tabsRow
                if vm.activeTab == .nominated, !vm.nominatorLabels.isEmpty {
                    (Text("\(PCStrings.managingConsentsFor) ") + Text(vm.nominatorLabels.joined(separator: ", ")).fontWeight(.semibold).foregroundColor(theme.text))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                filters
                content
                if vm.viewMode == .product && !vm.isLoading && vm.detail != nil {
                    PCPaginationBar(
                        currentPage: vm.currentPage,
                        totalPages: vm.totalPages,
                        pageSize: vm.pageSize,
                        pageSizeOptions: ConsentManagerViewModel.pageSizeOptions,
                        onPage: { vm.goToPage($0) },
                        onPageSize: { vm.setPageSize($0) }
                    )
                }
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
            ModifyConsentModal(consent: consent, nominatorContact: ConsentManagerViewModel.nominatorContact(for: consent.nominatorInfo), consentManagerVm: vm)
                .environment(\.privacyCenterTheme, theme)
                .presentationDetents([.medium, .large])
        }
        .alert(PCStrings.exportConsentData, isPresented: $showExportConfirm) {
            Button(PCStrings.cancel, role: .cancel) {}
            Button(PCStrings.export) { exportURL = vm.exportCSV() }
        } message: {
            Text("\(PCStrings.exportConsentDataSubtitle)\n\n\(PCStrings.exportingIncludesFilters)")
        }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
    }

    private var headerStatus: (label: String, isSuccess: Bool)? {
        switch vm.userStatus {
        case .transferred: return (PCStrings.statusTransferred, false)
        case .active: return (PCStrings.statusActive, true)
        case nil: return nil
        }
    }

    // MARK: - Tabs

    private var tabsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                tab(.direct, PCStrings.myConsents, vm.directBadge)
                tab(.nominated, PCStrings.managing, vm.nominatedBadge)
                Spacer(minLength: 0)
            }
            .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
            HStack(spacing: 8) {
                Text(PCStrings.consentVisibility)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                HStack(spacing: 0) {
                    viewToggle(.product, PCStrings.product)
                    viewToggle(.purpose, PCStrings.purpose)
                }
                .padding(2)
                .background(theme.surface)
                .clipShape(Capsule())
            }
        }
    }

    private func tab(_ tab: ConsentManagerViewModel.ConsentTab, _ label: String, _ badge: Int?) -> some View {
        let isActive = vm.activeTab == tab
        return Button(action: { vm.setActiveTab(tab) }) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 12, weight: .semibold))
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(theme.surface)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isActive ? theme.primary : theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .overlay(Rectangle().fill(isActive ? theme.primary : Color.clear).frame(height: 2), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }

    private func viewToggle(_ mode: ConsentManagerViewModel.ViewMode, _ label: String) -> some View {
        let isActive = vm.viewMode == mode
        return Button(action: { vm.setViewMode(mode) }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActive ? theme.primaryText : theme.textSecondary)
                .frame(minWidth: 72)
                .padding(.vertical, 6)
                .background(isActive ? theme.primary : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filters

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            PCInput(
                text: Binding(get: { vm.searchText }, set: { vm.setSearch($0) }),
                placeholder: "\(PCStrings.search) \(PCStrings.consent), \(PCStrings.product), \(PCStrings.purpose)...",
                leadingIcon: "magnifyingglass"
            )
            PCSelect(
                selection: Binding(get: { vm.statusFilter }, set: { vm.setStatusFilter($0) }),
                options: vm.statusOptions.map { PCSelectOption(value: $0, label: statusLabel($0)) },
                placeholder: "\(PCStrings.all) \(PCStrings.status)"
            )
            PCSelect(
                selection: Binding(get: { vm.productFilter }, set: { vm.setProductFilter($0) }),
                options: vm.productOptions.map { PCSelectOption(value: $0.uuid, label: $0.name) },
                placeholder: "\(PCStrings.all) \(PCStrings.product)"
            )
            HStack {
                Text(vm.summaryText)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                PCButton(PCStrings.export, variant: .outline, size: .compact, fullWidth: false, leadingIcon: "square.and.arrow.up") {
                    showExportConfirm = true
                }
            }
        }
    }

    private func statusLabel(_ status: ConsentStatus) -> String {
        switch status {
        case .active: return PCStrings.statusActive
        case .withdrawn: return PCStrings.statusWithdrawn
        case .expired: return PCStrings.statusExpired
        case .declined: return PCStrings.statusDeclined
        case .unknown: return ""
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in PCSkeletonCard() }
            }
        } else if vm.viewMode == .product {
            let groups = vm.displayGroups
            if groups.isEmpty {
                PCEmpty(title: PCStrings.noData, icon: "shield")
            } else {
                VStack(spacing: 10) {
                    ForEach(groups) { productCard($0) }
                }
            }
        } else {
            let rows = vm.displayRows
            if rows.isEmpty {
                PCEmpty(title: PCStrings.noData, icon: "shield")
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { purposeCard($0) }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
    }

    private func productCard(_ display: ConsentManagerViewModel.DisplayGroup) -> some View {
        let group = display.group
        let name = group.productName.isEmpty ? "-" : group.productName
        let isExpanded = vm.expandedCards.contains(display.key)
        let purposes = vm.purposes(in: display)
        return card {
            HStack(alignment: .top, spacing: 10) {
                PCInitialsAvatar(text: PCInitialsAvatar.initials(name), seed: group.productUuid.isEmpty ? name : group.productUuid)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                    if let desc = group.productDescription, !desc.isEmpty {
                        Text(desc).font(.system(size: 13)).foregroundColor(theme.textSecondary)
                    }
                    if let nominator = display.nominator {
                        (Text("\(PCStrings.nominatedBy) ") + Text(nominator.displayLabel).fontWeight(.semibold))
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer(minLength: 4)
                (Text("\(group.totalPurposes)").foregroundColor(theme.primary).fontWeight(.bold) + Text(" \(PCStrings.consent)"))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(theme.border, lineWidth: 1))
            }
            let chips = statusChips(display)
            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        let (label, color) = chip
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            HStack(alignment: .top) {
                Text(PCStrings.activity)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                if let latest = display.latestGivenDate {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(PrivacyCenterDateFormatters.formatDateBulletTime(latest))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.text)
                        Text(PrivacyCenterDateFormatters.relativeTime(latest))
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                } else {
                    Text("-").font(.system(size: 13)).foregroundColor(theme.textSecondary)
                }
            }
            Button(action: { withAnimation { vm.toggleCard(display.key) } }) {
                HStack {
                    Text("\(purposes.count) \(PCStrings.purpose)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundColor(theme.text)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(purposes) { purposeItem($0) }
                    if vm.hasMorePurposes(in: group) {
                        let loading = vm.loadingMoreCards.contains(display.key)
                        PCButton(loading ? PCStrings.loading : PCStrings.loadMorePurposes, variant: .outline, size: .compact, fullWidth: false, isDisabled: loading) {
                            Task { await vm.loadMorePurposes(in: group) }
                        }
                    }
                }
            }
        }
    }

    private func statusChips(_ display: ConsentManagerViewModel.DisplayGroup) -> [(String, Color)] {
        var chips: [(String, Color)] = []
        if display.activeCount > 0 { chips.append(("\(display.activeCount) \(PCStrings.statusActive)", theme.success)) }
        if display.withdrawnCount > 0 { chips.append(("\(display.withdrawnCount) \(PCStrings.statusWithdrawn)", theme.error)) }
        if display.expiredCount > 0 { chips.append(("\(display.expiredCount) \(PCStrings.statusExpired)", theme.warning)) }
        if display.declinedCount > 0 { chips.append(("\(display.declinedCount) \(PCStrings.statusDeclined)", theme.warning)) }
        return chips
    }

    private func purposeItem(_ consent: UserConsent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            purposeHead(consent)
            metaGrid(consent)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func purposeCard(_ consent: UserConsent) -> some View {
        card {
            purposeHead(consent)
            metaRow(PCStrings.product, consent.productName.pcNonEmpty ?? "-")
            if let nominator = consent.nominatorInfo {
                metaRow(PCStrings.nominatedBy, nominator.displayLabel)
            }
            metaGrid(consent)
        }
    }

    private func purposeHead(_ consent: UserConsent) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(consent.purpose)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                if !consent.purposeDescription.isEmpty {
                    Text(consent.purposeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer(minLength: 6)
            PCConsentStatusPill(consent: consent)
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(theme.text)
        }
    }

    private func metaGrid(_ consent: UserConsent) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 10) {
            meta(PCStrings.givenDate) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(PrivacyCenterDateFormatters.formatDateTime(consent.givenDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.text)
                    if !consent.givenDate.isEmpty {
                        Text(PrivacyCenterDateFormatters.relativeTime(consent.givenDate))
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            meta(PCStrings.validTill) {
                Text(ConsentManagerViewModel.validTillLabel(consent))
                    .font(.system(size: 13))
                    .foregroundColor(theme.text)
            }
            meta(PCStrings.method) {
                HStack(spacing: 4) {
                    if consent.method == "MOBILE" { Image(systemName: "iphone").font(.system(size: 10)) }
                    if consent.method == "WEB" { Image(systemName: "laptopcomputer").font(.system(size: 10)) }
                    Text(consent.method).font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
            }
            meta(PCStrings.action) {
                let disabled = consent.status == .declined
                Button(PCStrings.modifyButton) { modifyTarget = consent }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(disabled ? Color(hex: "#9ca3af") : theme.primary)
                    .disabled(disabled)
            }
        }
    }

    private func meta<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 12)).foregroundColor(theme.textSecondary)
            content()
        }
    }
}
