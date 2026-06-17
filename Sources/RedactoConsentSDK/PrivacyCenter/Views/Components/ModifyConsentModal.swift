import SwiftUI

public struct ModifyConsentModal: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: ModifyConsentViewModel
    let consentManagerVm: ConsentManagerViewModel

    public init(consent: UserConsent, nominatorContact: String?, consentManagerVm: ConsentManagerViewModel) {
        self._vm = StateObject(wrappedValue: ModifyConsentViewModel(consent: consent, nominatorContact: nominatorContact))
        self.consentManagerVm = consentManagerVm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PCNavbar(
                title: PCStrings.modifyConsent,
                subtitle: vm.consent.purpose,
                onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        switch vm.step {
                        case .overview: overview
                        case .confirmRevoke: confirmRevoke
                        case .regrantSelect: regrantSelect
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.background)

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        }
        .background(theme.background)
    }

    @ViewBuilder
    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.consent.purposeDescription)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            HStack {
                PCStatusBadge(status: vm.consent.status)
                Spacer()
            }
            if !vm.consent.dataElements.isEmpty {
                Text(PCStrings.dataElementsLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)
                    .padding(.top, 4)
                ForEach(vm.consent.dataElements) { de in
                    HStack(spacing: 8) {
                        Image(systemName: de.selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(de.selected ? theme.success : theme.textTertiary)
                        Text(de.name)
                            .font(.system(size: 14))
                            .foregroundColor(theme.text)
                        Spacer()
                    }
                }
            }
        }
        VStack(spacing: 10) {
            if vm.canRevoke {
                PCButton(PCStrings.revoke, variant: .destructive) {
                    vm.startRevoke()
                }
            }
            if vm.canRegrant {
                PCButton(PCStrings.regrant, variant: .primary) {
                    vm.startRegrant()
                }
            }
            if vm.canRenew {
                PCButton(PCStrings.renew, variant: .outline, isLoading: vm.isProcessing) {
                    Task {
                        await consentManagerVm.performAction(
                            purposeId: vm.consent.purposeUuid ?? "",
                            action: .renew,
                            nominatorContact: vm.nominatorContact
                        )
                        dismiss()
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var confirmRevoke: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PCStrings.revokeConfirmTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.text)
            Text(PCStrings.revokeConfirmBody)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            HStack {
                PCButton(PCStrings.cancel, variant: .outline) { vm.step = .overview }
                PCButton(PCStrings.revoke, variant: .destructive, isLoading: vm.isProcessing) {
                    Task {
                        vm.isProcessing = true
                        await consentManagerVm.performAction(
                            purposeId: vm.consent.purposeUuid ?? "",
                            action: .revoke,
                            nominatorContact: vm.nominatorContact
                        )
                        vm.isProcessing = false
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var regrantSelect: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PCStrings.dataElementsLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            ForEach(vm.consent.dataElements) { de in
                PCCheckbox(
                    isOn: Binding(
                        get: { vm.selectedDataElementUuids.contains(de.uuid) },
                        set: { _ in vm.toggleDataElement(de.uuid) }
                    ),
                    label: de.name,
                    isDisabled: de.required
                )
            }
            HStack {
                PCButton(PCStrings.cancel, variant: .outline) { vm.step = .overview }
                PCButton(PCStrings.regrant, variant: .primary, isLoading: vm.isProcessing) {
                    Task {
                        vm.isProcessing = true
                        await consentManagerVm.performAction(
                            purposeId: vm.consent.purposeUuid ?? "",
                            action: .regrant,
                            nominatorContact: vm.nominatorContact,
                            dataElementUuids: Array(vm.selectedDataElementUuids)
                        )
                        vm.isProcessing = false
                        dismiss()
                    }
                }
            }
        }
    }
}
