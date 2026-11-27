import SwiftUI

/// Badge colour for a case status (React `getCaseStatusVariant`).
func caseStatusVariant(_ status: String) -> PCBadgeVariant {
    let normalized = status.lowercased().replacingOccurrences(of: "_", with: "")
    switch normalized {
    case "completed": return .success
    case "rejected", "declined": return .error
    case "processing", "inprogress", "expired": return .warning
    case "initiated": return .info
    default: return .secondary
    }
}

/// The requests list (Android CaseHistoryScreen).
public struct CaseHistoryScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @ObservedObject private var vm: CaseHistoryViewModel
    let onNewRequest: () -> Void

    public init(store: PrivacyCenterStore, vm: CaseHistoryViewModel, onNewRequest: @escaping () -> Void) {
        self.vm = vm
        self.onNewRequest = onNewRequest
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                titleRow
                PCInput(text: $vm.searchText, placeholder: PCStrings.searchCasesByID, leadingIcon: "magnifyingglass")
                statusTabs
                typeFilter
                content
                if !vm.isLoading && vm.errorMessage == nil && !vm.pagedCases.isEmpty {
                    PCPaginationBar(
                        currentPage: vm.pageIndex + 1,
                        totalPages: vm.totalPages,
                        pageSize: vm.pageSize,
                        pageSizeOptions: CaseHistoryViewModel.pageSizeOptions,
                        onPage: { vm.goToPage($0 - 1) },
                        onPageSize: { vm.pageSize = $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(theme.background)
        .refreshable { await vm.refresh() }
        .task { await vm.loadInitial() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterCasesChanged)) { _ in
            Task { await vm.refresh() }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(PCStrings.grievanceRequests)
                .font(theme.font(size: 20, weight: .bold))
                .foregroundColor(theme.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            PCButton("+ \(PCStrings.newRequest)", size: .compact) { onNewRequest() }
        }
    }

    private var statusTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CaseRequestStatusFilter.allCases, id: \.self) { filter in
                    let isActive = filter == vm.statusFilter
                    Button(action: { vm.setStatusFilter(filter) }) {
                        Text(label(filter))
                            .font(theme.font(size: 12, weight: .semibold))
                            .foregroundColor(isActive ? theme.primaryText : theme.text)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(minHeight: 36)
                            .background(isActive ? theme.primary : theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.controlRadius)
                                    .stroke(isActive ? theme.primary : theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var typeFilter: some View {
        Menu {
            Section(PCStrings.filterByType) {
                ForEach(RequestType.allCases, id: \.self) { type in
                    Button {
                        vm.toggleRequestType(type)
                    } label: {
                        if vm.selectedRequestTypes.contains(type) {
                            Label(type.label, systemImage: "checkmark")
                        } else {
                            Text(type.label)
                        }
                    }
                }
            }
        } label: {
            Text(PCStrings.filter)
                .font(theme.font(size: 13, weight: .medium))
                .foregroundColor(theme.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(theme.surfaceElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            PCLoader().frame(minHeight: 240)
        } else if let error = vm.errorMessage {
            VStack(spacing: 8) {
                Text(error).font(theme.font(size: 15)).foregroundColor(theme.error)
                Text(PCStrings.unknownError).font(theme.font(size: 13)).foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else if vm.pagedCases.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(vm.pagedCases) { caseCard($0) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            PCEmpty(
                title: vm.isFiltered ? PCStrings.noMatchingRequests : PCStrings.noCasesYet,
                subtitle: vm.isFiltered ? PCStrings.noResultsForSearch : PCStrings.submitFirstRequest,
                icon: "tray"
            )
            PCButton(PCStrings.newRequest, fullWidth: false) { onNewRequest() }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func caseCard(_ caseRequest: CaseRequest) -> some View {
        Button(action: { store.openCase(caseRequest) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(caseRequest.caseId)
                        .font(theme.font(size: 14, weight: .bold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    PCBadge(caseRequest.displayStatus, variant: caseStatusVariant(caseRequest.rawStatus ?? ""))
                }
                HStack(spacing: 6) {
                    Text(caseRequest.displayRequestType)
                        .font(theme.font(size: 12, weight: .semibold))
                        .foregroundColor(theme.text)
                    Text("·")
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text(PrivacyCenterDateFormatters.formatDateShort(caseRequest.createdAt))
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                if !caseRequest.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(caseRequest.description)
                        .font(theme.font(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(theme.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
        }
        .buttonStyle(.plain)
    }

    private func label(_ filter: CaseRequestStatusFilter) -> String {
        switch filter {
        case .all: return PCStrings.all
        case .processing: return PCStrings.processing
        case .completed: return PCStrings.completed
        case .rejected: return PCStrings.rejected
        }
    }
}
