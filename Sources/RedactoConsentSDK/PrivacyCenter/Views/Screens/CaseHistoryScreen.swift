import SwiftUI

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
                header
                tabs
                searchField
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(theme.background)
        .refreshable { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(PCStrings.caseHistory)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.text)
                Text(PCStrings.dataRequestsSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PCButton(
                PCStrings.newRequest,
                variant: .primary,
                size: .compact,
                fullWidth: false,
                leadingIcon: "plus"
            ) { onNewRequest() }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var tabs: some View {
        PCScrollingTabBar(spacing: 8) {
            ForEach(CaseRequestStatusFilter.allCases, id: \.self) { filter in
                let isActive = vm.statusFilter == filter
                Button(action: { vm.setStatusFilter(filter) }) {
                    Text(localizedFilter(filter))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isActive ? theme.primaryText : theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isActive ? theme.primary : theme.surface)
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var searchField: some View {
        PCInput(
            text: $vm.searchText,
            placeholder: PCStrings.search,
            leadingIcon: "magnifyingglass"
        )
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in PCSkeletonCard() } }
        } else if vm.filteredCases.isEmpty {
            PCEmpty(title: PCStrings.noCases, icon: "tray")
        } else {
            VStack(spacing: 8) {
                ForEach(vm.filteredCases) { caseRequest in
                    caseCard(caseRequest)
                }
                if vm.hasMore {
                    Button(action: { Task { await vm.loadMore() } }) {
                        Text(vm.isLoadingMore ? PCStrings.loading : PCStrings.loadMore)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.surface)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingMore)
                }
            }
        }
    }

    @ViewBuilder
    private func caseCard(_ caseRequest: CaseRequest) -> some View {
        Button(action: { store.openCase(caseRequest) }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(caseRequest.caseId)
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundColor(theme.text)
                        Spacer(minLength: 8)
                        PCCaseStatusBadge(status: caseRequest.status)
                    }
                    Text(PCFormatting.humanize(caseRequest.requestType))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primary)
                    if !caseRequest.description.isEmpty {
                        Text(caseRequest.description)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 12) {
                        Label(PrivacyCenterDateFormatters.formatDate(caseRequest.createdAt), systemImage: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                            .labelStyle(.titleAndIcon)
                        if let due = caseRequest.dueDate {
                            Label(PrivacyCenterDateFormatters.formatDate(due), systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.border.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func localizedFilter(_ filter: CaseRequestStatusFilter) -> String {
        switch filter {
        case .all: return PCStrings.all
        case .processing: return PCStrings.processing
        case .completed: return PCStrings.completed
        case .rejected: return PCStrings.rejected
        }
    }
}
