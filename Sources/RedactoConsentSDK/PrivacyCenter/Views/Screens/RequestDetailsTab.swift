import SwiftUI

/// React CaseDetails/RequestDetailsTab.
struct RequestDetailsTab: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var vm: CaseDetailsViewModel

    var body: some View {
        let caseRequest = vm.caseRequest
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 14) {
                    field(PCStrings.requestType) { Text(vm.requestType).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text) }
                    field(PCStrings.status) { PCBadge(vm.statusLabel, variant: caseStatusVariant(caseRequest.rawStatus ?? "")) }
                    field(PCStrings.createdAt) { dateValue(caseRequest.createdAt) }
                    if let completed = caseRequest.completedAt.pcNonEmpty {
                        field(PCStrings.completedAt) { dateValue(completed) }
                    }
                }
                .padding(14)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))

                if !vm.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(PCStrings.descriptionLabel).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text)
                        Text(vm.description).font(theme.font(size: 14)).foregroundColor(theme.textSecondary)
                    }
                }

                if let details = caseRequest.requestDetails {
                    specifics(details)
                }
            }
            .padding(16)
        }
    }

    private func dateValue(_ iso: String?) -> some View {
        Text(PrivacyCenterDateFormatters.formatDateTimeShort(iso))
            .font(theme.font(size: 14, weight: .semibold))
            .foregroundColor(theme.text)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(theme.font(size: 12, weight: .medium)).foregroundColor(theme.textSecondary)
            content()
        }
    }

    @ViewBuilder
    private func specifics(_ details: CaseRequestDetails) -> some View {
        Text(PCStrings.requestSpecifics)
            .font(theme.font(size: 16, weight: .semibold))
            .foregroundColor(theme.text)
            .padding(.top, 4)
        if !details.purposes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.purposesInvolved).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text)
                ForEach(details.purposes) { wrapper in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wrapper.purpose.name).font(theme.font(size: 14, weight: .medium)).foregroundColor(theme.text)
                        if !wrapper.purpose.description.isEmpty {
                            Text(wrapper.purpose.description).font(theme.font(size: 13)).foregroundColor(theme.textSecondary)
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
                Text(PCStrings.dataToCorrect).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text)
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
                Text(PCStrings.nomination).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text)
                VStack(alignment: .leading, spacing: 10) {
                    field(PCStrings.nomineeEmail) { Text(nomination.nomineeEmail.isEmpty ? "-" : nomination.nomineeEmail).font(theme.font(size: 14, weight: .medium)).foregroundColor(theme.text) }
                    field(PCStrings.nomineeMobile) { Text(nomination.nomineeMobile.pcNonEmpty ?? "-").font(theme.font(size: 14, weight: .medium)).foregroundColor(theme.text) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        if !details.grievanceTypes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PCStrings.grievanceTypes).font(theme.font(size: 14, weight: .semibold)).foregroundColor(theme.text)
                FlowLayoutCompat(spacing: 6) {
                    ForEach(details.grievanceTypes, id: \.self) { raw in
                        PCBadge(Self.grievanceLabel(raw), variant: .secondary)
                    }
                }
            }
        }
    }

    static func grievanceLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "consent_violation": return PCStrings.grievanceConsentViolation
        case "unlawful_processing": return PCStrings.grievanceUnlawfulProcessing
        case "data_breach": return PCStrings.grievanceDataBreach
        default:
            let words = raw.replacingOccurrences(of: "_", with: " ").lowercased()
            return words.prefix(1).uppercased() + words.dropFirst()
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
