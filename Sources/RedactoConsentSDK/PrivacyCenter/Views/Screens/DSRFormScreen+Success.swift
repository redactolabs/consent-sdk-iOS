import SwiftUI

/// The erasure question and the success card (Android ErasureRevokeDialog and
/// DsrSuccessScreen).
extension DSRFormScreen {
    // MARK: - Erasure modal

    var erasureModal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(theme.font(size: 24))
                        .foregroundColor(theme.warning)
                    Text(PCStrings.revokeConsentModalTitle)
                        .font(theme.font(size: 17, weight: .semibold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                    Text(PCStrings.revokeConsentModalQuestion)
                        .font(theme.font(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text(PCStrings.revokeConsentModalPurposesLabel)
                        .font(theme.font(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    let names = vm.selectedErasurePurposeNames
                    if names.isEmpty {
                        Text(PCStrings.revokeConsentModalYourPurposes)
                            .font(theme.font(size: 13))
                            .foregroundColor(theme.textSecondary)
                    } else {
                        ForEach(names.prefix(DSRFormViewModel.maxErasurePurposeNames), id: \.self) { name in
                            Text(name)
                                .font(theme.font(size: 14, weight: .medium))
                                .foregroundColor(theme.text)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        if names.count > DSRFormViewModel.maxErasurePurposeNames {
                            Text(PCStrings.revokeConsentModalAndMore(names.count - DSRFormViewModel.maxErasurePurposeNames))
                                .font(theme.font(size: 13))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                (Text(PCStrings.revokeConsentModalIfYesLabel).fontWeight(.semibold) + Text(" \(PCStrings.revokeConsentModalIfYesBody)"))
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.badgeWarningText)
                    .padding(12)
                    .background(theme.badgeWarningBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 10) {
                    PCButton(PCStrings.revokeConsentNo, variant: .outline, isDisabled: vm.isSubmitting) {
                        Task { await vm.chooseErasureRevoke(false) }
                    }
                    PCButton(PCStrings.revokeConsentYes, fullWidth: true, isLoading: vm.isSubmitting) {
                        Task { await vm.chooseErasureRevoke(true) }
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    // MARK: - Success (Android DsrSuccessScreen)

    var successView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(theme.badgeSuccessBg)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "checkmark.circle.fill").font(theme.font(size: 22)).foregroundColor(theme.success))
                Text(PCStrings.requestSubmittedSuccessfully)
                    .font(theme.font(size: 18, weight: .semibold))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(PCStrings.thankYouForSubmittingYourRequest)
                .font(theme.font(size: 13))
                .foregroundColor(theme.textSecondary)
            if let submitted = vm.submittedCase {
                VStack(alignment: .leading, spacing: 4) {
                    if !submitted.productName.isEmpty {
                        Text(submitted.productName)
                            .font(theme.font(size: 13, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    Text("\(PCStrings.caseID): \(submitted.caseId)")
                        .font(theme.font(size: 14, weight: .bold))
                        .foregroundColor(theme.text)
                        .textSelection(.enabled)
                    Text(PCStrings.saveThisID)
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "envelope").font(theme.font(size: 14)).foregroundColor(theme.textSecondary)
                Text("\(PCStrings.confirmationSentTo): \(vm.contact)")
                    .font(theme.font(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(PCStrings.processRequest)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textSecondary)
            if vm.revokeConsentOnFulfilment {
                Text(PCStrings.erasureConsentRevokeNotice(vm.erasurePurposeSummary))
                    .font(theme.font(size: 12, weight: .medium))
                    .foregroundColor(theme.badgeInfoText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.badgeInfoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Spacer()
                PCButton(PCStrings.backToHome, fullWidth: false) {
                    vm.reset()
                    onBack?()
                }
                Spacer()
            }
        }
        .padding(20)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }
}
