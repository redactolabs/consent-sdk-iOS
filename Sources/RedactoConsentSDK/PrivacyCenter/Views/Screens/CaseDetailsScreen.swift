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
            VStack(alignment: .leading, spacing: 10) {
                PCPageHeader(title: PCStrings.caseDetails, description: PCStrings.yourPrivacyCenter)
                Button(action: { store.isRequestFormOpen = false; store.navigate(to: .form) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").font(.system(size: 13, weight: .semibold))
                        Text(PCStrings.backToHome).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                header
                tabs
            }
            .padding(.horizontal, 16)
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

    /// "CASE-1 · Access · Submitted 15 Jan 2025 · Response due … · Status".
    private var header: some View {
        FlowLayoutCompat(spacing: 6) {
            Text(vm.caseId).font(.system(size: 13, weight: .bold)).foregroundColor(theme.text)
            dot
            Text(vm.requestType).font(.system(size: 13)).foregroundColor(theme.textSecondary)
            dot
            Text("\(PCStrings.submitted) \(vm.createdAt)").font(.system(size: 13)).foregroundColor(theme.textSecondary)
            if let due = vm.dueDate {
                dot
                Text("\(PCStrings.responseDue) \(due)")
                    .font(.system(size: 13, weight: vm.isDueDateOverdue ? .semibold : .regular))
                    .foregroundColor(vm.isDueDateOverdue ? theme.error : theme.textSecondary)
            }
            dot
            PCBadge(vm.statusLabel, variant: caseStatusVariant(vm.caseRequest.rawStatus ?? ""))
        }
    }

    private var dot: some View {
        Text("·").font(.system(size: 13)).foregroundColor(theme.textTertiary)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(.requestDetails, label: PCStrings.requestDetails)
            tabButton(.messages, label: PCStrings.messages)
            Spacer()
        }
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: CaseDetailsViewModel.Tab, label: String) -> some View {
        let isActive = vm.activeTab == tab
        return Button(action: { vm.activeTab = tab }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? theme.primary : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .overlay(Rectangle().fill(isActive ? theme.primary : Color.clear).frame(height: 2), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}

/// React CaseDetails/RequestDetailsTab.
struct RequestDetailsTab: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var vm: CaseDetailsViewModel

    var body: some View {
        let caseRequest = vm.caseRequest
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 14) {
                    field(PCStrings.requestType) { Text(vm.requestType).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text) }
                    field(PCStrings.status) { PCBadge(vm.statusLabel, variant: caseStatusVariant(caseRequest.rawStatus ?? "")) }
                    field(PCStrings.createdAt) { Text(vm.createdAt).font(.system(size: 14, weight: .medium)).foregroundColor(theme.text) }
                    if let completed = vm.completedAt {
                        field(PCStrings.completedAt) { Text(completed).font(.system(size: 14, weight: .medium)).foregroundColor(theme.text) }
                    }
                }
                .padding(14)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))

                if !vm.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(PCStrings.descriptionLabel).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text)
                        Text(vm.description).font(.system(size: 14)).foregroundColor(theme.textSecondary)
                    }
                }

                if let details = caseRequest.requestDetails {
                    specifics(details)
                }
            }
            .padding(16)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(theme.textSecondary)
            content()
        }
    }

    @ViewBuilder
    private func specifics(_ details: CaseRequestDetails) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(theme.border).frame(height: 1)
            Text(PCStrings.requestSpecifics)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
                .fixedSize()
            Rectangle().fill(theme.border).frame(height: 1)
        }
        if !details.purposes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.purposesInvolved).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text)
                ForEach(details.purposes) { wrapper in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wrapper.purpose.name).font(.system(size: 14, weight: .medium)).foregroundColor(theme.text)
                        if !wrapper.purpose.description.isEmpty {
                            Text(wrapper.purpose.description).font(.system(size: 13)).foregroundColor(theme.textSecondary)
                        }
                        let selected = wrapper.purpose.dataElements.filter(\.selected)
                        if !selected.isEmpty {
                            FlowLayoutCompat(spacing: 6) {
                                ForEach(selected) { PCBadge($0.name, variant: .secondary) }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        if !details.correctionData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.dataToCorrect).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text)
                VStack(spacing: 0) {
                    correctionRow(PCStrings.field, PCStrings.currentValue, PCStrings.newValue, header: true)
                    ForEach(Array(details.correctionData.enumerated()), id: \.offset) { _, item in
                        Divider()
                        correctionRow(item.name, item.currValue.isEmpty ? "-" : item.currValue, item.newValue.isEmpty ? "-" : item.newValue, header: false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        if let nomination = details.nominationData {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.nomination).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text)
                VStack(alignment: .leading, spacing: 10) {
                    field(PCStrings.nomineeEmail) { Text(nomination.nomineeEmail.isEmpty ? "-" : nomination.nomineeEmail).font(.system(size: 14, weight: .medium)).foregroundColor(theme.text) }
                    field(PCStrings.nomineeMobile) { Text(nomination.nomineeMobile.pcNonEmpty ?? "-").font(.system(size: 14, weight: .medium)).foregroundColor(theme.text) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        if !details.grievanceTypes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.grievanceTypes).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text)
                FlowLayoutCompat(spacing: 6) {
                    ForEach(details.grievanceTypes, id: \.self) { raw in
                        PCBadge(raw.replacingOccurrences(of: "_", with: " "), variant: .secondary)
                    }
                }
            }
        }
    }

    private func correctionRow(_ a: String, _ b: String, _ c: String, header: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array([a, b, c].enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.system(size: 12, weight: header ? .semibold : .regular))
                    .foregroundColor(header ? theme.textSecondary : theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(header ? theme.surface : Color.clear)
    }
}
