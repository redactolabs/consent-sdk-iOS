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
                PCWelcomeBanner()
                tabsRow
                if vm.activeTab == .nominated, !vm.nominatorLabels.isEmpty {
                    (Text("\(PCStrings.managingConsentsFor) ") + Text(vm.nominatorLabels.joined(separator: ", ")).fontWeight(.semibold).foregroundColor(theme.text))
                        .font(theme.font(size: 13))
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
        .pcDialog(item: $modifyTarget) { consent in
            ModifyConsentModal(
                consent: consent,
                nominatorContact: ConsentManagerViewModel.nominatorContact(for: consent.nominatorInfo),
                consentManagerVm: vm,
                onClose: { modifyTarget = nil }
            )
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

    // MARK: - Tabs

    private var tabsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                tab(.direct, PCStrings.myConsents, vm.directBadge)
                tab(.nominated, PCStrings.managing, nil)
                Spacer(minLength: 0)
            }
            .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
            HStack(spacing: 8) {
                Text(PCStrings.consentVisibility)
                    .font(theme.font(size: 12, weight: .medium))
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
                Text(label).font(theme.font(size: 12, weight: .semibold))
                if let badge {
                    Text("\(badge)")
                        .font(theme.font(size: 11))
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
                .font(theme.font(size: 11, weight: .semibold))
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
                placeholder: PCStrings.searchConsentsProductsPurposes,
                leadingIcon: "magnifyingglass"
            )
            PCSelect(
                selection: Binding(get: { vm.statusFilter }, set: { vm.setStatusFilter($0) }),
                options: vm.statusOptions.map { PCSelectOption(value: $0, label: statusLabel($0)) },
                placeholder: PCStrings.status,
                leadingIcon: "line.3.horizontal.decrease",
                allOptionLabel: PCStrings.all
            )
            PCSelect(
                selection: Binding(get: { vm.productFilter }, set: { vm.setProductFilter($0) }),
                options: vm.productOptions.map { PCSelectOption(value: $0.uuid, label: $0.name) },
                placeholder: PCStrings.product,
                leadingIcon: "circle",
                allOptionLabel: "\(PCStrings.all) \(PCStrings.product)"
            )
            HStack {
                Text(vm.summaryText)
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
                Spacer(minLength: 4)
                iconAction("arrow.clockwise", tint: theme.textSecondary, label: PCStrings.refresh) {
                    Task { await vm.refresh() }
                }
                iconAction("arrow.down.to.line", tint: theme.primary, label: PCStrings.export) {
                    showExportConfirm = true
                }
            }
        }
    }

    private func iconAction(_ systemName: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(theme.font(size: 18, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                    if let desc = group.productDescription, !desc.isEmpty {
                        Text(desc).font(theme.font(size: 13)).foregroundColor(theme.textSecondary)
                    }
                    if let nominator = display.nominator {
                        (Text("\(PCStrings.nominatedBy) ") + Text(nominator.displayLabel).fontWeight(.semibold))
                            .font(theme.font(size: 13))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer(minLength: 4)
                PCBadge("\(group.totalPurposes)", variant: .info)
            }
            let chips = statusChips(display)
            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        PCBadge(chip.0, variant: chip.1)
                    }
                }
            }
            Button(action: { withAnimation { vm.toggleCard(display.key) } }) {
                HStack {
                    Text("\(purposes.count) \(PCStrings.purpose)")
                        .font(theme.font(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(theme.font(size: 12, weight: .semibold))
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

    private func statusChips(_ display: ConsentManagerViewModel.DisplayGroup) -> [(String, PCBadgeVariant)] {
        var chips: [(String, PCBadgeVariant)] = []
        if display.activeCount > 0 { chips.append(("\(display.activeCount) \(PCStrings.statusActive)", .success)) }
        if display.withdrawnCount > 0 { chips.append(("\(display.withdrawnCount) \(PCStrings.statusWithdrawn)", .error)) }
        if display.expiredCount > 0 { chips.append(("\(display.expiredCount) \(PCStrings.statusExpired)", .warning)) }
        if display.declinedCount > 0 { chips.append(("\(display.declinedCount) \(PCStrings.statusDeclined)", .warning)) }
        return chips
    }

    private func purposeItem(_ consent: UserConsent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            purposeHead(consent)
            purposeDetails(consent)
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
            purposeDetails(consent)
        }
    }

    private func purposeHead(_ consent: UserConsent) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(consent.purpose)
                    .font(theme.font(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                if !consent.purposeDescription.isEmpty {
                    Text(consent.purposeDescription)
                        .font(theme.font(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer(minLength: 6)
            PCConsentStatusPill(consent: consent)
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(theme.font(size: 13, weight: .medium))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func purposeDetails(_ consent: UserConsent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metaRow(PCStrings.givenDate, PrivacyCenterDateFormatters.formatGivenDate(consent.givenDate))
            metaRow(PCStrings.validTill, ConsentManagerViewModel.validTillLabel(consent))
            if !consent.method.isEmpty {
                metaRow(PCStrings.method, consent.method)
            }
            PCButton(
                PCStrings.modifyConsent,
                variant: .outline,
                size: .compact,
                fullWidth: false,
                isDisabled: consent.status == .declined
            ) { modifyTarget = consent }
            .padding(.top, 4)
        }
    }
}
