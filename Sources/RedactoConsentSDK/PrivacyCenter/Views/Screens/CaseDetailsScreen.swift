import SwiftUI

public struct CaseDetailsScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: CaseDetailsViewModel

    public init(store: PrivacyCenterStore, caseRequest: CaseRequest) {
        _vm = StateObject(wrappedValue: CaseDetailsViewModel(store: store, caseRequest: caseRequest))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
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
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.caseId)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(theme.text)
                    Text(vm.requestType)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
                Spacer()
                PCCaseStatusBadge(status: vm.statusLabel)
            }
            HStack(spacing: 12) {
                Text("\(PCStrings.caseCreatedAt) \(vm.createdAt)")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
                if let due = vm.dueDate {
                    Text("\(PCStrings.caseDueDate) \(due)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(16)
        .background(theme.surface)
    }

    @ViewBuilder
    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(.requestDetails, label: PCStrings.requestDetails)
            tabButton(.messages, label: PCStrings.messages)
        }
        .padding(4)
        .background(theme.surface)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: CaseDetailsViewModel.Tab, label: String) -> some View {
        let isActive = vm.activeTab == tab
        Button(action: { vm.activeTab = tab }) {
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
}

struct RequestDetailsTab: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var vm: CaseDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                detailRow(label: PCStrings.requestType, value: vm.requestType)
                detailRow(label: PCStrings.status, value: vm.statusLabel)
                detailRow(label: PCStrings.caseCreatedAt, value: vm.createdAt)
                if let due = vm.dueDate {
                    detailRow(label: PCStrings.caseDueDate, value: due)
                }
                if !vm.description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PCStrings.description)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                        Text(vm.description)
                            .font(.system(size: 14))
                            .foregroundColor(theme.text)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .cornerRadius(10)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(theme.text)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .cornerRadius(10)
    }
}
