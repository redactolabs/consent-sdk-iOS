import SwiftUI

struct MessagesTab: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var vm: CaseDetailsViewModel
    @State private var showFilePicker: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    secureNotice
                        .padding(.bottom, 4)
                    ForEach(vm.messagesGroupedByDay(), id: \.label) { group in
                        HStack {
                            Spacer()
                            Text(group.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.surface)
                                .cornerRadius(10)
                            Spacer()
                        }
                        .padding(.top, 8)
                        ForEach(group.messages) { message in
                            MessageBubble(message: message, vm: vm)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .task {
            vm.startPolling()
        }
        .onDisappear { vm.stopPolling() }
        .sheet(isPresented: $showFilePicker) {
            FilePickerView(
                allowedTypes: [.pdf, .image, .text, .data],
                onPick: { picked in
                    showFilePicker = false
                    Task {
                        await vm.uploadAttachment(fileData: picked.data, filename: picked.fileName, mimeType: picked.mimeType)
                    }
                },
                onCancel: { showFilePicker = false }
            )
        }
    }

    @ViewBuilder
    private var secureNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12))
                .foregroundColor(theme.primary)
            Text(PCStrings.secureChannelNotice)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
    }

    @ViewBuilder
    private var composer: some View {
        VStack(spacing: 8) {
            if let pending = vm.pendingUpload {
                HStack {
                    Image(systemName: "doc.fill").foregroundColor(theme.primary)
                    Text(pending.fileName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { vm.clearPendingUpload() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(theme.primarySoft)
                .cornerRadius(8)
            }
            HStack(spacing: 8) {
                Button(action: { showFilePicker = true }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(vm.isUploading)

                TextField(PCStrings.typeMessage, text: $vm.draftMessage, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14))
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surface)
                    .cornerRadius(20)

                Button(action: { Task { await vm.sendMessage() } }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(theme.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(vm.isSendingMessage || (vm.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.pendingUpload == nil))
                .opacity(vm.isSendingMessage ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.background)
        .overlay(
            Rectangle().fill(theme.border.opacity(0.5)).frame(height: 0.5),
            alignment: .top
        )
    }
}

struct MessageBubble: View {
    @Environment(\.privacyCenterTheme) private var theme
    let message: CaseMessage
    @ObservedObject var vm: CaseDetailsViewModel

    var body: some View {
        let isMine = message.senderRole == .dataPrincipal
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 40) }
            else {
                PCAvatar(initial: String((message.triggeredByEmail.first ?? "F").lowercased()), size: 28)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if message.messageType == .documentRequested, let metadata = message.documentRequestMetadata {
                    documentRequestCard(metadata: metadata, message: message)
                } else if !message.body.isEmpty {
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundColor(isMine ? .white : theme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMine ? theme.primary : theme.surface)
                        .cornerRadius(14)
                }
                ForEach(message.documents) { doc in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill").font(.system(size: 11))
                        Text(doc.fileName ?? PCStrings.attachment)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(isMine ? .white : theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isMine ? theme.primary.opacity(0.85) : theme.surfaceElevated)
                    .cornerRadius(8)
                }
                Text(PrivacyCenterDateFormatters.formatTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func documentRequestCard(metadata: DocumentRequestMetadata, message: CaseMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(theme.warning)
                Text(PCStrings.documentRequest)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
                PCBadge(metadata.documentRequestStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                        variant: variantForStatus(metadata.documentRequestStatus))
            }
            Text(metadata.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
            if !metadata.acceptedDocument.isEmpty {
                Text(metadata.acceptedDocument)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            if metadata.documentRequestStatus == .rejected, !metadata.rejectionReason.isEmpty {
                Text("\(PCStrings.rejectionReason): \(metadata.rejectionReason)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(10)
        .frame(maxWidth: 280, alignment: .leading)
    }

    private func variantForStatus(_ status: DocumentRequestStatus) -> PCBadgeVariant {
        switch status {
        case .pending, .underReview, .replacementRequested: return .pending
        case .approved: return .success
        case .rejected: return .error
        }
    }
}
