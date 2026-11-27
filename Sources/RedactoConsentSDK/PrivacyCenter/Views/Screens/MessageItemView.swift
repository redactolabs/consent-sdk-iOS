import SwiftUI

enum PCFileSize {
    /// React `formatFileSize`.
    static func format(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(Int((Double(bytes) / 1024).rounded())) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

/// React CaseDetails/MessageItem: chat bubbles, document requests and status events.
struct MessageItemView: View {
    @Environment(\.privacyCenterTheme) private var theme
    let message: CaseMessage
    @ObservedObject var vm: CaseDetailsViewModel
    let onUploadForRequest: (String) -> Void
    let onOpenDocument: (MessageDocument) -> Void

    private var isPrincipal: Bool { message.senderRole == .dataPrincipal }
    private var timestamp: String { PrivacyCenterDateFormatters.formatMessageTime(message.createdAt) }
    private var header: String {
        Self.senderLabel(for: message).map { "\($0) · \(timestamp)" } ?? timestamp
    }

    /// React `MessageItem`'s label, except a role this release does not know
    /// names only the sender's email: "Privacy team" would attribute it to the
    /// fiduciary.
    static func senderLabel(for message: CaseMessage) -> String? {
        switch message.senderRole {
        case .dataPrincipal: return PCStrings.senderYou
        case .dataFiduciary: return message.triggeredByEmail.nonEmpty ?? PCStrings.senderPrivacyTeam
        case .other: return message.triggeredByEmail.nonEmpty
        }
    }

    var body: some View {
        switch message.messageType {
        case .documentRequested:
            VStack(alignment: .leading, spacing: 8) {
                if !message.body.isEmpty {
                    bubble(sent: false) { Text(message.body) }
                }
                if let meta = message.documentRequestMetadata {
                    documentRequestCard(meta)
                }
            }
        case .documentApproved:
            statusEvent(icon: "checkmark.circle.fill", hex: ("#16a34a", "#f0fdf4", "#bbf7d0"), text: PCStrings.documentAccepted, sub: nil)
        case .documentRejected:
            statusEvent(icon: "xmark.circle.fill", hex: ("#dc2626", "#fef2f2", "#fecaca"), text: PCStrings.documentRejected, sub: message.documentRequestMetadata?.rejectionReason.nonEmpty)
        case .documentReplacementRequested:
            statusEvent(icon: "exclamationmark.circle.fill", hex: ("#d97706", "#fffbeb", "#fde68a"), text: PCStrings.replacementRequested, sub: message.body.nonEmpty)
        default:
            bubble(sent: isPrincipal) {
                if !message.body.isEmpty { Text(message.body) }
            }
        }
    }

    private func bubble<Content: View>(sent: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: sent ? .trailing : .leading, spacing: 4) {
            Text(header)
                .font(theme.font(size: 11))
                .foregroundColor(theme.textTertiary)
            content()
                .font(theme.font(size: 14))
                .foregroundColor(sent ? theme.primaryText : theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(sent ? theme.primary : theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            ForEach(message.documents) { doc in
                attachmentCard(doc)
            }
        }
        .frame(maxWidth: .infinity, alignment: sent ? .trailing : .leading)
    }

    private func attachmentCard(_ doc: MessageDocument) -> some View {
        let name = doc.fileName.pcNonEmpty ?? PCStrings.document
        return Button(action: { onOpenDocument(doc) }) {
            HStack(spacing: 8) {
                if vm.openingDocument == doc.uuid {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "doc.text").font(theme.font(size: 18)).foregroundColor(theme.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(theme.font(size: 13, weight: .medium)).foregroundColor(theme.text).lineLimit(1)
                    if let size = doc.fileSize, size > 0 {
                        Text(PCFileSize.format(size)).font(theme.font(size: 11)).foregroundColor(theme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(theme.background)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PCStrings.downloadAttachment(name))
    }

    private func documentRequestCard(_ meta: DocumentRequestMetadata) -> some View {
        let canUpload = meta.documentRequestStatus == .pending || meta.documentRequestStatus == .replacementRequested
        let status = Self.statusInfo(meta.documentRequestStatus)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "paperclip").font(theme.font(size: 14)).foregroundColor(Color(hex: "#2563eb"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(PCStrings.documentRequestedLabel(meta.title))
                        .font(theme.font(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#1d4ed8"))
                    if !meta.acceptedDocument.isEmpty {
                        Text(PCStrings.acceptedLabel(meta.acceptedDocument))
                            .font(theme.font(size: 12))
                            .foregroundColor(Color(hex: "#2563eb"))
                    }
                }
                Spacer(minLength: 4)
                Text(status.label)
                    .font(theme.font(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: status.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(Color(hex: status.hex), lineWidth: 1))
            }
            if canUpload {
                PCButton(
                    PCStrings.uploadAndSubmit,
                    variant: .outline,
                    size: .compact,
                    fullWidth: false,
                    isLoading: vm.submittingForRequest == message.uuid,
                    isDisabled: vm.isUploading || vm.isCaseFinalized,
                    leadingIcon: "paperclip"
                ) { onUploadForRequest(message.uuid) }
            }
            if meta.documentRequestStatus == .rejected, !meta.rejectionReason.isEmpty {
                Text(PCStrings.rejectionReasonLabel(meta.rejectionReason))
                    .font(theme.font(size: 12))
                    .foregroundColor(Color(hex: "#dc2626"))
                    .padding(8)
                    .background(Color(hex: "#fef2f2"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color(hex: "#f8fbff"))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "#93c5fd"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// React `DOCUMENT_REQUEST_STATUS_LABEL`.
    static func statusInfo(_ status: DocumentRequestStatus) -> (label: String, hex: String) {
        switch status {
        case .pending: return (PCStrings.docStatusPending, "#d97706")
        case .underReview: return (PCStrings.docStatusUnderReview, "#2563eb")
        case .approved: return (PCStrings.docStatusApproved, "#16a34a")
        case .rejected: return (PCStrings.docStatusRejected, "#dc2626")
        case .replacementRequested: return (PCStrings.docStatusReplacementRequested, "#d97706")
        }
    }

    private func statusEvent(icon: String, hex: (String, String, String), text: String, sub: String?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(theme.font(size: 15))
                Text(text).font(theme.font(size: 13, weight: .medium))
            }
            .foregroundColor(Color(hex: hex.0))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: hex.1))
            .overlay(Capsule().stroke(Color(hex: hex.2), lineWidth: 1))
            .clipShape(Capsule())
            if let sub {
                Text(sub).font(theme.font(size: 12)).foregroundColor(Color(hex: hex.0))
            }
            Text(timestamp).font(theme.font(size: 11)).foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
