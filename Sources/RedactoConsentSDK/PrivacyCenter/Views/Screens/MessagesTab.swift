import SwiftUI

/// React CaseDetails/MessagesTab: secure notice, the thread, and a composer
/// locked once the case is finalized.
struct MessagesTab: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.openURL) private var openURL
    @ObservedObject var vm: CaseDetailsViewModel
    @State private var showAttachPicker = false
    @State private var uploadRequestUuid: String?

    var body: some View {
        VStack(spacing: 0) {
            notice
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.isLoadingMessages {
                            PCLoader()
                        } else if vm.messagesFailed {
                            Text(PCStrings.errorLoadingMessages)
                                .font(theme.font(size: 13))
                                .foregroundColor(theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else if vm.messages.isEmpty {
                            PCEmpty(title: PCStrings.noMessagesYet, subtitle: PCStrings.noMessagesYetSubtitle, icon: "bubble.left")
                        }
                        ForEach(vm.messages) { message in
                            MessageItemView(
                                message: message,
                                vm: vm,
                                onUploadForRequest: { uploadRequestUuid = $0 },
                                onOpenDocument: { doc in
                                    Task { if let url = await vm.documentURL(for: doc) { openURL(url) } }
                                }
                            )
                            .id(message.id)
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
            MessageComposer(vm: vm, onAttach: { showAttachPicker = true })
        }
        .task { vm.startPolling() }
        .onDisappear { vm.stopPolling() }
        .sheet(isPresented: $showAttachPicker) {
            FilePickerView(
                allowedTypes: PCUploadValidation.allowedContentTypes,
                onPick: { picked in
                    showAttachPicker = false
                    Task { await vm.uploadAttachment(fileData: picked.data, filename: picked.fileName, mimeType: picked.mimeType) }
                },
                onCancel: { showAttachPicker = false }
            )
        }
        .sheet(isPresented: Binding(get: { uploadRequestUuid != nil }, set: { if !$0 { uploadRequestUuid = nil } })) {
            FilePickerView(
                allowedTypes: PCUploadValidation.allowedContentTypes,
                onPick: { picked in
                    let request = uploadRequestUuid
                    uploadRequestUuid = nil
                    guard let request else { return }
                    Task {
                        await vm.uploadForDocumentRequest(
                            requestEventUuid: request,
                            fileData: picked.data,
                            filename: picked.fileName,
                            mimeType: picked.mimeType
                        )
                    }
                },
                onCancel: { uploadRequestUuid = nil }
            )
        }
    }

    private var notice: some View {
        HStack(spacing: 8) {
            Text("🔒")
            Text(vm.isCaseFinalized ? PCStrings.caseFinalizedMessagesTooltip : PCStrings.secureMessagesNotice)
                .font(theme.font(size: 12))
            Spacer()
            Button(action: { Task { await vm.fetchMessages(initial: false) } }) {
                Image(systemName: "arrow.clockwise").font(theme.font(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(vm.isFetchingMessages)
            .accessibilityLabel(PCStrings.refreshMessages)
        }
        .foregroundColor(Color(hex: "#1d4ed8"))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#eff6ff"))
        .overlay(Rectangle().fill(Color(hex: "#bfdbfe")).frame(height: 1), alignment: .bottom)
    }
}
