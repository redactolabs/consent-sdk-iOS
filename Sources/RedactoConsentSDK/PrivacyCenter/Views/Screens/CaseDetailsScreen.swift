import SwiftUI

/// A case's page (React PrivacyCenterCaseDetailsPage).
public struct CaseDetailsScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: CaseDetailsViewModel

    public init(store: PrivacyCenterStore, caseRequest: CaseRequest) {
        _vm = StateObject(wrappedValue: CaseDetailsViewModel(store: store, caseRequest: caseRequest))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { store.isRequestFormOpen = false; store.navigate(to: .form) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").font(theme.font(size: 13, weight: .semibold))
                        Text(PCStrings.backToHome).font(theme.font(size: 13, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                header
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            tabs
            Group {
                switch vm.activeTab {
                case .requestDetails: RequestDetailsTab(vm: vm)
                case .messages: MessagesTab(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.rehydrate() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.caseId)
                        .font(theme.font(size: 16, weight: .bold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    Text(vm.requestType)
                        .font(theme.font(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PCBadge(vm.statusLabel, variant: caseStatusVariant(vm.caseRequest.rawStatus ?? ""))
            }
            if let due = vm.dueDate {
                Text("\(PCStrings.responseDue) \(due)")
                    .font(theme.font(size: 12, weight: vm.isDueDateOverdue ? .semibold : .regular))
                    .foregroundColor(vm.isDueDateOverdue ? theme.error : theme.textTertiary)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(.requestDetails, label: PCStrings.requestDetails)
            tabButton(.messages, label: PCStrings.messages)
        }
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: CaseDetailsViewModel.Tab, label: String) -> some View {
        let isActive = vm.activeTab == tab
        return Button(action: { vm.activeTab = tab }) {
            Text(label)
                .font(theme.font(size: 13, weight: .medium))
                .foregroundColor(isActive ? theme.primary : theme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .overlay(Rectangle().fill(isActive ? theme.primary : Color.clear).frame(height: 2), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}
