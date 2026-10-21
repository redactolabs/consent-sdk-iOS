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

/// The data-request form (React components/Form.tsx) and its success card
/// (RequestSubmit.tsx).
public struct DSRFormScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: DSRFormViewModel
    @State private var showFilePicker: Bool = false
    @State private var expandedPurposes: Set<String> = []
    private let onBack: (() -> Void)?

    public init(store: PrivacyCenterStore, onBack: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: DSRFormViewModel(store: store))
        self.onBack = onBack
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if vm.caseSubmitted {
                    PCPageHeader(title: PCStrings.grievanceRequests, description: PCStrings.grievanceSubtitle)
                    successView
                } else {
                    PCPageHeader(title: PCStrings.yourPrivacyCenter, description: PCStrings.yourRightsOverDataSimplified)
                    if let onBack {
                        backButton(onBack)
                    }
                    if vm.isLoading {
                        PCLoader(label: PCStrings.loading).padding(.top, 40)
                    } else {
                        formCard
                    }
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

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left").font(theme.font(size: 13, weight: .semibold))
                Text(PCStrings.backToHome).font(theme.font(size: 13, weight: .medium))
            }
            .foregroundColor(theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PCStrings.description)
                .font(theme.font(size: 13))
                .foregroundColor(theme.textSecondary)
                .lineSpacing(2)
            VStack(alignment: .leading, spacing: 0) {
                Text(PCStrings.raiseDataRequest)
                    .font(theme.font(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(theme.surface)
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        requiredLabel(PCStrings.contact)
                        PCInput(text: .constant(vm.contact), placeholder: PCStrings.contactPlaceholder, isDisabled: true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        requiredLabel(PCStrings.requestType)
                        PCSelect(
                            selection: $vm.requestType,
                            options: vm.requestTypeOptions.map { PCSelectOption(value: $0.type, label: $0.label) },
                            placeholder: PCStrings.selectRequestType
                        )
                    }
                    requestDetailsAccordion
                    supportingDocs
                    if vm.requestType == .access {
                        PCSelect(
                            selection: Binding(get: { vm.timePeriod.isEmpty ? nil : vm.timePeriod }, set: { vm.timePeriod = $0 ?? "" }),
                            options: [
                                PCSelectOption(value: "1", label: PCStrings.today),
                                PCSelectOption(value: "7", label: PCStrings.last7Days),
                                PCSelectOption(value: "30", label: PCStrings.last30Days),
                                PCSelectOption(value: "90", label: PCStrings.last3Months),
                            ],
                            placeholder: PCStrings.selectPlaceholder,
                            label: PCStrings.timePeriod
                        )
                    }
                    PCTextarea(text: $vm.additionalNote, placeholder: PCStrings.reasonOptional, label: PCStrings.additionalNote)
                    PCCheckbox(isOn: $vm.confirmChecked, label: "\(PCStrings.confirmCheckBox) *")
                    HStack {
                        Spacer()
                        PCButton(PCStrings.submit, fullWidth: false, isLoading: vm.isSubmitting, isDisabled: !vm.canSubmit) {
                            Task { await vm.submitTapped() }
                        }
                    }
                }
                .padding(14)
            }
            .background(theme.background)
            .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
        }
    }

    private var requestDetailsAccordion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { vm.isRequestDetailsExpanded.toggle() }) {
                HStack {
                    requiredLabel(PCStrings.requestDetails)
                    Spacer()
                    Image(systemName: vm.isRequestDetailsExpanded ? "chevron.up" : "chevron.down")
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            if vm.isRequestDetailsExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    requestDetailsBody
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius + 2).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius + 2))
    }

    @ViewBuilder
    private var requestDetailsBody: some View {
        if vm.isProductScoped {
            if !vm.skipProductStep {
                productSection
            }
            if let group = vm.selectedGroup {
                productPanel(group)
            }
        } else if vm.requestType == .grievance {
            grievanceSection
        } else if vm.requestType == .nomination {
            nominationSection
        } else {
            Text(PCStrings.selectRequestType)
                .font(theme.font(size: 13))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 100)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Products (React ProductSelectionSection)

    @ViewBuilder
    private var productSection: some View {
        if vm.isTranslating {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(theme.border.opacity(0.5)).frame(width: 90, height: 36)
                }
            }
        } else if vm.groups.isEmpty {
            PCEmpty(title: PCStrings.noProductsAvailable, subtitle: PCStrings.noProductsAvailableDescription, icon: "shippingbox")
        } else {
            Text(vm.requestType.map { PCStrings.selectProductsForRequest($0.label) } ?? PCStrings.selectProductsForRequestGeneric)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textSecondary)
            FlowLayoutCompat(spacing: 8) {
                ForEach(vm.directGroups + vm.nominatedGroups) { group in
                    productChip(group)
                }
            }
        }
    }

    private func productChip(_ group: FormProductGroup) -> some View {
        let isSelected = vm.selectedProductKey == group.id
        return Button(action: { vm.selectProduct(group) }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(group.productName)
                        .font(theme.font(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let nominator = group.nominator {
                        Text(PCStrings.nominationChipSuffix(nominator.name.pcNonEmpty ?? nominator.email ?? ""))
                            .font(theme.font(size: 12))
                            .lineLimit(1)
                    }
                }
                Text(PCStrings.activePurposes(DSRFormViewModel.groupPurposes(group).count))
                    .font(theme.font(size: 11))
                    .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
            }
            .foregroundColor(isSelected ? theme.primary : theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primarySoft : theme.background)
            .overlay(RoundedRectangle(cornerRadius: theme.isGlass ? 999 : 10).stroke(isSelected ? theme.primary : theme.border, lineWidth: isSelected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.isGlass ? 999 : 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func productPanel(_ group: FormProductGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.productName)
                        .font(theme.font(size: 15, weight: .semibold))
                        .foregroundColor(theme.text)
                    if let nominator = group.nominator {
                        Text(PCStrings.actingOnBehalfOfShort(nominator.name.pcNonEmpty ?? nominator.email ?? ""))
                            .font(theme.font(size: 11, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Text(PCStrings.selectPurposesForThisProduct)
                    .font(theme.font(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            if vm.requestType == .correction {
                correctionSection
            } else {
                purposeSection
            }
        }
        .padding(12)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.controlRadius))
    }

    // MARK: - Purposes (React PurposeSelectionSection)

    @ViewBuilder
    private var purposeSection: some View {
        let isErasure = vm.requestType == .erasure
        Text(isErasure ? PCStrings.whatDataToDelete : PCStrings.whatDataToAccess)
            .font(theme.font(size: 12))
            .foregroundColor(theme.textSecondary)
        Text(PCStrings.revocationNotDeletionNote)
            .font(theme.font(size: 12))
            .foregroundColor(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 8)
            .overlay(alignment: .leading) { Rectangle().fill(theme.primary).frame(width: 2) }
        if !isErasure {
            PCCheckbox(
                isOn: Binding(get: { vm.isAllSelected && !vm.purposes.isEmpty }, set: { vm.setAllPurposes(selected: $0) }),
                label: PCStrings.selectAll
            )
        }
        VStack(spacing: 6) {
            ForEach(vm.purposes) { purpose in
                purposeRow(purpose, isErasure: isErasure)
            }
        }
    }

    private func purposeRow(_ purpose: PrivacyPurpose, isErasure: Bool) -> some View {
        let isOpen = expandedPurposes.contains(purpose.uuid)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                PCCheckbox(
                    isOn: Binding(get: { vm.isPurposeFullySelected(purpose) }, set: { vm.setPurpose(purpose, selected: $0) }),
                    label: purpose.name.pcCapitalized
                )
                Spacer(minLength: 8)
                Button(action: {
                    if isOpen { expandedPurposes.remove(purpose.uuid) } else { expandedPurposes.insert(purpose.uuid) }
                }) {
                    Image(systemName: "chevron.down")
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            if isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    Text(PCStrings.dataCollected)
                        .font(theme.font(size: 13, weight: .medium))
                        .foregroundColor(theme.text)
                    if purpose.dataElements.isEmpty {
                        Text(PCStrings.noDataElementsAvailable)
                            .font(theme.font(size: 13))
                            .foregroundColor(theme.textSecondary)
                    }
                    ForEach(purpose.dataElements) { element in
                        if isErasure {
                            Text(element.name.pcCapitalized)
                                .font(theme.font(size: 13))
                                .foregroundColor(theme.text)
                        } else {
                            PCCheckbox(
                                isOn: Binding(
                                    get: { vm.selectedElements[purpose.uuid]?.contains(element.uuid) ?? false },
                                    set: { _ in vm.toggleDataElement(purpose: purpose, elementUuid: element.uuid) }
                                ),
                                label: element.name.pcCapitalized
                            )
                        }
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Correction (React CorrectionDataSection)

    @ViewBuilder
    private var correctionSection: some View {
        Text(PCStrings.selectFieldsToUpdate)
            .font(theme.font(size: 12))
            .foregroundColor(theme.textSecondary)
        VStack(alignment: .leading, spacing: 10) {
            PCCheckbox(
                isOn: Binding(get: { vm.isAllCorrectionSelected }, set: { vm.setAllCorrectionFields(selected: $0) }),
                label: PCStrings.selectAll
            )
            ForEach(vm.correctionFields) { field in
                PCCheckbox(
                    isOn: Binding(
                        get: { vm.selectedCorrectionNames.contains(field.element.name) },
                        set: { _ in vm.toggleCorrectionField(field.element.name) }
                    ),
                    label: field.element.name.pcCapitalized
                )
            }
        }
        .padding(10)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        if !vm.selectedCorrectionNames.isEmpty {
            Divider()
            (Text("* ").foregroundColor(theme.error) + Text(PCStrings.enterCorrectValue).foregroundColor(theme.text))
                .font(theme.font(size: 13, weight: .medium))
            ForEach(vm.selectedCorrectionNames, id: \.self) { name in
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(theme.font(size: 13, weight: .medium))
                        .foregroundColor(theme.text)
                    PCInput(
                        text: Binding(get: { vm.correctionValues[name]?.current ?? "" }, set: { vm.updateCorrection(name: name, current: $0) }),
                        placeholder: PCStrings.currentValuePlaceholder
                    )
                    PCInput(
                        text: Binding(get: { vm.correctionValues[name]?.updated ?? "" }, set: { vm.updateCorrection(name: name, updated: $0) }),
                        placeholder: PCStrings.updatedValuePlaceholder
                    )
                }
                .padding(8)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Grievance / Nomination

    @ViewBuilder
    private var grievanceSection: some View {
        Text(PCStrings.selectGrievance)
            .font(theme.font(size: 12))
            .foregroundColor(theme.textSecondary)
        VStack(alignment: .leading, spacing: 8) {
            PCCheckbox(
                isOn: Binding(get: { vm.isAllGrievancesSelected }, set: { vm.setAllGrievances(selected: $0) }),
                label: PCStrings.selectAll
            )
            ForEach(vm.grievanceOptions) { option in
                PCCheckbox(
                    isOn: Binding(get: { vm.selectedGrievances.contains(option.value) }, set: { _ in vm.toggleGrievance(option.value) }),
                    label: option.value.label
                )
            }
        }
        .padding(10)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var nominationSection: some View {
        Text(PCStrings.enterNomineeDetails)
            .font(theme.font(size: 12))
            .foregroundColor(theme.textSecondary)
        PCInput(
            text: $vm.nominationData.nomineeEmail,
            placeholder: PCStrings.nomineeEmailPlaceholder,
            label: PCStrings.nomineeEmail,
            keyboardType: .emailAddress
        )
        PCInput(
            text: Binding(
                get: { vm.nominationData.nomineeMobile ?? "" },
                set: { vm.nominationData.nomineeMobile = $0.isEmpty ? nil : $0 }
            ),
            placeholder: PCStrings.nomineeMobilePlaceholder,
            label: PCStrings.nomineeMobile,
            keyboardType: .phonePad
        )
    }

    // MARK: - Documents

    private var supportingDocs: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PCStrings.supportingDocumentation)
                .font(theme.font(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            VStack(alignment: .leading, spacing: 8) {
                if !vm.uploadedDocs.isEmpty {
                    FlowLayoutCompat(spacing: 8) {
                        ForEach(vm.uploadedDocs) { doc in
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(theme.font(size: 12))
                                    .foregroundColor(theme.textSecondary)
                                Text(doc.fileName)
                                    .font(theme.font(size: 13, weight: .medium))
                                    .foregroundColor(theme.text)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button(action: { vm.removeDocument(doc.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(theme.font(size: 13))
                                        .foregroundColor(theme.error)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(PCStrings.removeAttachment)
                            }
                            .padding(8)
                            .background(theme.background)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Button(action: { showFilePicker = true }) {
                    HStack(spacing: 8) {
                        if vm.isUploading {
                            ProgressView().scaleEffect(0.8).tint(theme.primary)
                            Text(PCStrings.uploading)
                        } else if vm.uploadedDocs.isEmpty {
                            Image(systemName: "arrow.up.doc").font(theme.font(size: 26)).foregroundColor(theme.primary)
                            Text(PCStrings.uploadFile).foregroundColor(theme.textSecondary)
                        } else {
                            Image(systemName: "square.and.arrow.up").font(theme.font(size: 14))
                            Text(PCStrings.uploadFileButton)
                        }
                    }
                    .font(theme.font(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: vm.uploadedDocs.isEmpty ? .infinity : nil, minHeight: vm.uploadedDocs.isEmpty ? 76 : 0)
                    .padding(vm.uploadedDocs.isEmpty ? 0 : 8)
                    .background(vm.uploadedDocs.isEmpty ? Color.clear : theme.background)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(vm.uploadedDocs.isEmpty ? Color.clear : theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(vm.isUploading)
                .accessibilityLabel(PCStrings.uploadFile)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 100)
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Erasure modal

    private var erasureModal: some View {
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

    // MARK: - Success (React RequestSubmit)

    private var successView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(theme.success.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "checkmark").font(theme.font(size: 18, weight: .bold)).foregroundColor(theme.success))
                VStack(alignment: .leading, spacing: 6) {
                    Text(PCStrings.requestSubmittedSuccessfully)
                        .font(theme.font(size: 16, weight: .semibold))
                        .foregroundColor(theme.text)
                    Text("\(PCStrings.thankYouForSubmittingYourRequest).")
                        .font(theme.font(size: 14, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
            }
            if let submitted = vm.submittedCase {
                VStack(alignment: .leading, spacing: 4) {
                    if !submitted.productName.isEmpty {
                        Text(submitted.productName)
                            .font(theme.font(size: 14, weight: .medium))
                            .foregroundColor(theme.text)
                    }
                    Text("\(PCStrings.caseID): \(submitted.caseId)")
                        .font(theme.font(size: 16, weight: .bold))
                        .foregroundColor(theme.primary)
                        .textSelection(.enabled)
                    Text("\(PCStrings.saveThisID).")
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "envelope").font(theme.font(size: 14)).foregroundColor(theme.textSecondary)
                Text("\(PCStrings.confirmationSentTo): \(vm.contact)")
                    .font(theme.font(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("\(PCStrings.processRequest).")
                .font(theme.font(size: 12, weight: .medium))
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
            PCButton(PCStrings.backToHome) {
                vm.reset()
                onBack?()
            }
            Text("\(PCStrings.yourDataIsSafeWithUs).")
                .font(theme.font(size: 12, weight: .medium))
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(theme.background)
        .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
        .padding(.top, 8)
    }

    private func requiredLabel(_ text: String) -> some View {
        (Text(text).foregroundColor(theme.text) + Text("*").foregroundColor(theme.error))
            .font(theme.font(size: 14, weight: .semibold))
    }
}

/// Simple wrap-content layout (for uploaded-doc pills, product chips and the
/// footer links, whose rows are centred).
struct FlowLayoutCompat<Content: View>: View {
    let spacing: CGFloat
    var centered = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        FlowLayout(spacing: spacing, centered: centered) { content() }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        // The same rows `sizeThatFits` measured: a view moves down once the
        // row it would join runs past the width.
        var rows: [Range<Int>] = []
        var rowStart = 0
        var advance: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if advance + size.width > bounds.width, advance > 0 {
                rows.append(rowStart..<index)
                rowStart = index
                advance = 0
            }
            advance += size.width + spacing
        }
        if rowStart < sizes.count {
            rows.append(rowStart..<sizes.count)
        }
        var y = bounds.minY
        for row in rows {
            let rowWidth = sizes[row].reduce(CGFloat(0)) { $0 + $1.width } + spacing * CGFloat(row.count - 1)
            var x = bounds.minX + (centered ? max(0, (bounds.width - rowWidth) / 2) : 0)
            var rowHeight: CGFloat = 0
            for index in row {
                let size = sizes[index]
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }
}
