import SwiftUI

/// Android MessageComposer: pending-upload pill, a one-line field that grows
/// to five lines, round attach and send buttons, and the secure footer.
struct MessageComposer: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var vm: CaseDetailsViewModel
    let onAttach: () -> Void

    private var isAttachLoading: Bool { vm.isUploading && vm.submittingForRequest == nil }
    private var isAttachDisabled: Bool { vm.isUploading || vm.isSendingMessage || vm.isCaseFinalized }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pending = vm.pendingUpload {
                pendingPill(pending)
            }
            HStack(alignment: .bottom, spacing: 8) {
                field
                roundButton(
                    icon: "paperclip",
                    label: PCStrings.attachFile,
                    background: theme.surface,
                    tint: theme.text,
                    isLoading: isAttachLoading,
                    isDisabled: isAttachDisabled,
                    action: onAttach
                )
                roundButton(
                    icon: "paperplane.fill",
                    label: PCStrings.send,
                    background: vm.canSend ? theme.primary : theme.border,
                    tint: vm.canSend ? theme.primaryText : theme.textTertiary,
                    isLoading: vm.isSendingMessage,
                    isDisabled: !vm.canSend,
                    action: { Task { await vm.sendMessage() } }
                )
                .scaleEffect(vm.canSend ? 1 : 0.92)
                .animation(.easeOut(duration: 0.16), value: vm.canSend)
            }
            Text(PCStrings.messagesSecureFooter)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.background)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: -2)
    }

    private var field: some View {
        TextField(
            vm.isCaseFinalized ? PCStrings.caseFinalizedMessagesTooltip : PCStrings.writeMessagePlaceholder,
            text: $vm.draftMessage,
            axis: .vertical
        )
        .lineLimit(1...5)
        .font(theme.font(size: 15))
        .foregroundColor(theme.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
        .disabled(vm.isCaseFinalized || vm.isSendingMessage)
        .opacity(vm.isCaseFinalized ? 0.6 : 1)
    }

    private func pendingPill(_ pending: PendingUpload) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc").font(theme.font(size: 13)).foregroundColor(theme.info)
            Text(pending.fileName)
                .font(theme.font(size: 12))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(PCFileSize.format(pending.fileSize)).font(theme.font(size: 12)).foregroundColor(theme.textTertiary)
            Button(action: { vm.clearPendingUpload() }) {
                Image(systemName: "xmark")
                    .font(theme.font(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PCStrings.removeAttachment)
        }
        .padding(.leading, 8)
        .background(theme.info.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.info, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
        .padding(.bottom, 4)
    }

    private func roundButton(
        icon: String,
        label: String,
        background: Color,
        tint: Color,
        isLoading: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(background)
                if isLoading {
                    ProgressView().tint(tint).scaleEffect(0.8)
                } else {
                    Image(systemName: icon).font(theme.font(size: 18, weight: .medium)).foregroundColor(tint)
                }
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(label)
    }
}
