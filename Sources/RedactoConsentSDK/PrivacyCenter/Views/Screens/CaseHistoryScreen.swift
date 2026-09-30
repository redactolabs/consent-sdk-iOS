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

/// The requests list (React CaseHistory.tsx).
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
                PCPageHeader(title: PCStrings.grievanceRequests, description: PCStrings.grievanceSubtitle)
                PCButton(PCStrings.newRequest, leadingIcon: "plus") { onNewRequest() }
                PCInput(text: $vm.searchText, placeholder: PCStrings.searchCasesByID, leadingIcon: "magnifyingglass")
                PCSegmentedTabs(
                    options: CaseRequestStatusFilter.allCases.map { ($0, label($0)) },
                    selection: vm.statusFilter,
                    onSelect: { vm.setStatusFilter($0) }
                )
                typeFilter
                content
                if !vm.isLoading && vm.errorMessage == nil {
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
            .padding(.bottom, 16)
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
            HStack(spacing: 6) {
                Text(PCStrings.filter).font(.system(size: 13, weight: .semibold))
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            PCLoader().frame(minHeight: 240)
        } else if let error = vm.errorMessage {
            VStack(spacing: 8) {
                Text(error).font(.system(size: 15)).foregroundColor(theme.error)
                Text(PCStrings.unknownError).font(.system(size: 13)).foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else if vm.pagedCases.isEmpty {
            PCEmpty(title: PCStrings.noData, icon: "tray")
        } else {
            VStack(spacing: 8) {
                ForEach(vm.pagedCases) { caseCard($0) }
            }
        }
    }

    private func caseCard(_ caseRequest: CaseRequest) -> some View {
        Button(action: { store.openCase(caseRequest) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(caseRequest.caseId)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.text)
                        Text(PrivacyCenterDateFormatters.formatDateShort(caseRequest.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    PCBadge(caseRequest.displayStatus, variant: caseStatusVariant(caseRequest.rawStatus ?? ""))
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PCStrings.requestType).font(.system(size: 11)).foregroundColor(theme.textTertiary)
                        Text(caseRequest.displayRequestType).font(.system(size: 13)).foregroundColor(theme.text)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(PCStrings.submittedOn).font(.system(size: 11)).foregroundColor(theme.textTertiary)
                        Text(PrivacyCenterDateFormatters.formatDateShort(caseRequest.createdAt)).font(.system(size: 13)).foregroundColor(theme.textSecondary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
        }
        .buttonStyle(.plain)
    }

    private func label(_ filter: CaseRequestStatusFilter) -> String {
        switch filter {
        case .all: return PCStrings.allRequests
        case .processing: return PCStrings.processing
        case .completed: return PCStrings.completed
        case .rejected: return PCStrings.rejected
        }
    }
}
