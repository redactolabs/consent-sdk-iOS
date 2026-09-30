import SwiftUI

/// React ModifyConsentModal.tsx: the one action the consent's status allows,
/// behind a description, the purpose's elements and a warning.
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
            PCNavbar(title: PCStrings.modifyConsent, onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if vm.action == nil {
                        Text(PCStrings.noActionsAvailable)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    } else {
                        Text(vm.descriptionText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                        purposePanel
                        warning
                        actions
                    }
                }
                .padding(16)
            }
            .background(theme.background)
        }
        .background(theme.background)
    }

    private var purposePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { vm.isAccordionOpen.toggle() } }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.consent.purpose)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.text)
                        if !vm.consent.purposeDescription.isEmpty {
                            Text(vm.consent.purposeDescription)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(vm.isAccordionOpen ? 0 : -90))
                }
            }
            .buttonStyle(.plain)
            if vm.isAccordionOpen {
                Divider()
                if vm.canRegrant && !vm.regrantEligibleElements.isEmpty {
                    Text(PCStrings.selectDataElementsForRegrant)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                    ForEach(vm.regrantEligibleElements) { element in
                        PCCheckbox(
                            isOn: Binding(
                                get: { vm.isChecked(element.uuid) },
                                set: { _ in vm.toggleDataElement(element.uuid) }
                            ),
                            label: element.required ? "\(element.name) (\(PCStrings.mandatory))" : element.name,
                            isDisabled: element.required
                        )
                    }
                } else {
                    let selected = vm.consent.dataElements.filter(\.selected)
                    if selected.isEmpty {
                        Text(PCStrings.noDataElementsAvailable)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textTertiary)
                    } else {
                        ForEach(selected) { element in
                            HStack(spacing: 8) {
                                Circle().fill(theme.primary).frame(width: 6, height: 6)
                                Text(element.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.text)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
            Text(vm.warningText)
                .font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(theme.badgeWarningText)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.badgeWarningBg)
        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.warning.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Spacer()
            PCButton(PCStrings.cancel, variant: .outline, fullWidth: false) { dismiss() }
            PCButton(
                vm.buttonLabel,
                variant: vm.canRevoke ? .destructive : .primary,
                fullWidth: false,
                isLoading: vm.isProcessing,
                isDisabled: vm.isConfirmDisabled
            ) {
                guard let action = vm.action else { return }
                Task {
                    vm.isProcessing = true
                    await consentManagerVm.performAction(
                        on: vm.consent,
                        action: action,
                        nominatorContact: vm.nominatorContact,
                        dataElementUuids: vm.dataElementUuidsForAction
                    )
                    vm.isProcessing = false
                    dismiss()
                }
            }
        }
    }
}
