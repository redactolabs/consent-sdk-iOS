import SwiftUI
import UniformTypeIdentifiers

extension PCUploadValidation {
    /// The picker opens on the accepted types only.
    static var allowedContentTypes: [UTType] {
        allowedMimeTypes.compactMap { UTType(mimeType: $0) }
    }
}

extension RequestType {
    /// React `useRequestTypeLabels`.
    var label: String {
        switch self {
        case .access: return PCStrings.access
        case .correction: return PCStrings.correction
        case .erasure: return PCStrings.erasure
        case .grievance: return PCStrings.grievance
        case .nomination: return PCStrings.nomination
        }
    }
}

extension GrievanceType {
    /// React translates the option by its value, not the server's label.
    var label: String {
        switch self {
        case .consentViolation: return PCStrings.consentViolation
        case .unlawfulProcessing: return PCStrings.unlawfulProcessing
        case .dataBreach: return PCStrings.dataBreach
        }
    }
}

/// The data-request form (Android DsrFormScreen) and its success card
/// (DsrSuccessScreen).
public struct DSRFormScreen: View {
    @Environment(\.privacyCenterTheme) var theme
    @EnvironmentObject var store: PrivacyCenterStore
    @StateObject var vm: DSRFormViewModel
    @State private var showFilePicker: Bool = false
    @State var expandedPurposes: Set<String> = []
    let onBack: (() -> Void)?

    public init(store: PrivacyCenterStore, onBack: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: DSRFormViewModel(store: store))
        self.onBack = onBack
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if vm.caseSubmitted {
                    PCPageHeader(title: PCStrings.grievanceRequests, description: nil)
                    successView
                } else if vm.isLoading {
                    PCLoader(label: PCStrings.loading).padding(.top, 40)
                } else {
                    form
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(theme.background)
        .task { await vm.loadFormData() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.applyLanguageChange() }
        }
        .onChange(of: vm.requestType) { _ in expandedPurposes = [] }
        .onChange(of: store.settings) { _ in vm.dropUnofferedRequestType() }
        .onChange(of: vm.serverRequestTypes) { _ in vm.dropUnofferedRequestType() }
        .sheet(isPresented: $showFilePicker) {
            FilePickerView(
                allowedTypes: PCUploadValidation.allowedContentTypes,
                onPick: { picked in
                    showFilePicker = false
                    Task {
                        await vm.uploadDocument(fileData: picked.data, filename: picked.fileName, mimeType: picked.mimeType)
                    }
                },
                onCancel: { showFilePicker = false }
            )
        }
        .sheet(isPresented: $vm.isErasureModalOpen) {
            erasureModal
                .environment(\.privacyCenterTheme, theme)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(vm.isSubmitting)
        }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(PCStrings.raiseDataRequest)
                .font(theme.font(size: 20, weight: .bold))
                .foregroundColor(theme.text)
                .padding(.top, 20)
            labeledField(requiredText(PCStrings.contact)) {
                PCInput(text: .constant(vm.contact), placeholder: PCStrings.contactPlaceholder, isDisabled: true)
            }
            labeledField(requiredText(PCStrings.requestType)) {
                PCSelect(
                    selection: $vm.requestType,
                    options: vm.requestTypeOptions.map { PCSelectOption(value: $0.type, label: $0.label) },
                    placeholder: PCStrings.selectRequestType
                )
            }
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel(requiredText(PCStrings.requestDetails))
                requestDetailsBody
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if vm.requestType == .access {
                labeledField(PCStrings.timePeriod) {
                    PCSelect(
                        selection: Binding(get: { vm.timePeriod.isEmpty ? nil : vm.timePeriod }, set: { vm.timePeriod = $0 ?? "" }),
                        options: [
                            PCSelectOption(value: "1", label: PCStrings.today),
                            PCSelectOption(value: "7", label: PCStrings.last7Days),
                            PCSelectOption(value: "30", label: PCStrings.last30Days),
                            PCSelectOption(value: "90", label: PCStrings.last3Months),
                        ],
                        placeholder: PCStrings.selectPlaceholder
                    )
                }
            }
            labeledField(PCStrings.additionalNote) {
                PCTextarea(text: $vm.additionalNote, placeholder: PCStrings.reasonOptional)
            }
            supportingDocs
            PCCheckbox(isOn: $vm.confirmChecked, label: requiredText(PCStrings.confirmCheckBox))
            HStack(spacing: 8) {
                Spacer()
                if let onBack {
                    PCButton(PCStrings.cancel, variant: .outline, isDisabled: vm.isSubmitting) { onBack() }
                }
                PCButton(PCStrings.submit, fullWidth: false, isLoading: vm.isSubmitting, isDisabled: !vm.canSubmit) {
                    Task { await vm.submitTapped() }
                }
            }
        }
    }

    // MARK: - Documents (Android DsrAttachmentsSection)

    private var supportingDocs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PCStrings.supportingDocumentation)
                .font(theme.font(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.uploadedDocs) { doc in
                    attachmentRow(doc)
                }
                uploadButton
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func attachmentRow(_ doc: DSRFormViewModel.UploadedDoc) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip")
                .font(theme.font(size: 16))
                .foregroundColor(theme.textSecondary)
            Text(doc.fileName)
                .font(theme.font(size: 13, weight: .medium))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: { vm.removeDocument(doc.id) }) {
                Image(systemName: "xmark")
                    .font(theme.font(size: 14, weight: .semibold))
                    .foregroundColor(theme.error)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PCStrings.removeAttachment)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 48)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var uploadButton: some View {
        let hasDocs = !vm.uploadedDocs.isEmpty
        return Button(action: { showFilePicker = true }) {
            HStack(spacing: 8) {
                if vm.isUploading {
                    ProgressView().scaleEffect(0.8).tint(theme.primary)
                    Text(PCStrings.uploading)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(theme.font(size: hasDocs ? 18 : 28))
                    Text(hasDocs ? PCStrings.uploadFileButton : PCStrings.uploadFile)
                }
            }
            .font(theme.font(size: 13))
            .foregroundColor(theme.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: hasDocs ? 48 : 96)
            .background(theme.background)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.isUploading)
        .accessibilityLabel(PCStrings.uploadFile)
    }

    // MARK: - Labels

    func requiredText(_ text: String) -> String {
        "\(text) *"
    }

    func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.font(size: 13))
            .foregroundColor(theme.text)
    }

    func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
