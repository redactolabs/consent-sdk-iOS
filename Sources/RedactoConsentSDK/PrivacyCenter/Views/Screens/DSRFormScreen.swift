import SwiftUI
import UniformTypeIdentifiers

public struct DSRFormScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: DSRFormViewModel
    @State private var showFilePicker: Bool = false

    public init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: DSRFormViewModel(store: store))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if vm.isLoading {
                    PCLoader(label: PCStrings.loading)
                        .padding(.top, 40)
                } else if vm.caseSubmitted {
                    successView
                } else {
                    formCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(theme.background)
        .task { await vm.loadFormData() }
        .sheet(isPresented: $showFilePicker) {
            FilePickerView(
                allowedTypes: [.pdf, .image, .text, .data],
                onPick: { picked in
                    showFilePicker = false
                    Task {
                        await vm.uploadDocument(fileData: picked.data, filename: picked.fileName, mimeType: picked.mimeType)
                    }
                },
                onCancel: { showFilePicker = false }
            )
        }
    }

    // MARK: - Top description

    @ViewBuilder
    private var description: some View {
        Text(PCStrings.dataRequestsSubtitleLong)
            .font(.system(size: 13))
            .foregroundColor(theme.textSecondary)
            .lineSpacing(2)
    }

    // MARK: - Card

    @ViewBuilder
    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            description

            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                cardBody
            }
            .background(theme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var cardHeader: some View {
        Text(PCStrings.grievanceRequests)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.surface)
            .overlay(
                Rectangle().fill(theme.border).frame(height: 1),
                alignment: .bottom
            )
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            contactField
            requestTypeField
            requestDetailsAccordion
            supportingDocs
            additionalNote
            confirmRow
            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
            }
            actionButtons
        }
        .padding(14)
    }

    // MARK: - Sections

    @ViewBuilder
    private var contactField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel(PCStrings.contact)
            PCInput(
                text: .constant(store.contact ?? ""),
                placeholder: PCStrings.contact,
                isDisabled: true
            )
        }
    }

    @ViewBuilder
    private var requestTypeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel(PCStrings.requestType)
            PCSelect(
                selection: $vm.requestType,
                options: [
                    PCSelectOption(value: RequestType.access, label: PCStrings.access),
                    PCSelectOption(value: RequestType.correction, label: PCStrings.correction),
                    PCSelectOption(value: RequestType.erasure, label: PCStrings.erasure),
                    PCSelectOption(value: RequestType.grievance, label: PCStrings.grievance),
                    PCSelectOption(value: RequestType.nomination, label: PCStrings.nomination),
                ],
                placeholder: PCStrings.selectRequestType
            )
        }
    }

    @ViewBuilder
    private var requestDetailsAccordion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { vm.isRequestDetailsExpanded.toggle() }) {
                HStack {
                    HStack(spacing: 4) {
                        Text(PCStrings.requestDetails)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.text)
                        Text("*")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.error)
                    }
                    Spacer()
                    Image(systemName: vm.isRequestDetailsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(12)
                .background(theme.surface)
            }
            .buttonStyle(.plain)
            if vm.isRequestDetailsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    requestDetailsBody
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .overlay(
                    Rectangle().fill(theme.border).frame(height: 1),
                    alignment: .top
                )
            }
        }
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var requestDetailsBody: some View {
        if let type = vm.requestType {
            switch type {
            case .access, .erasure:
                purposesList(title: type == .access ? PCStrings.purposeQuestionAccess : PCStrings.purposeQuestionErasure)
            case .correction:
                correctionList
            case .grievance:
                grievanceList
            case .nomination:
                nominationFields
            }
        } else {
            Text(PCStrings.selectRequestType)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Purposes (ACCESS / ERASURE)

    @ViewBuilder
    private func purposesList(title: String) -> some View {
        if vm.purposes.isEmpty {
            Text(PCStrings.noPurposes)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        } else {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            Text(PCStrings.revocationNotDeletionNote)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 8)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(theme.primary)
                        .frame(width: 2)
                }
            VStack(spacing: 8) {
                ForEach(vm.purposes) { purpose in
                    purposeCard(purpose)
                }
            }
        }
    }

    @ViewBuilder
    private func purposeCard(_ purpose: PrivacyPurpose) -> some View {
        let isSelected = vm.selectedPurposeIds.contains(purpose.uuid)
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { vm.togglePurpose(purpose) }) {
                HStack(alignment: .top, spacing: 10) {
                    checkbox(isOn: isSelected, size: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purpose.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.text)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if !purpose.description.isEmpty {
                            Text(purpose.description)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            if isSelected, !purpose.dataElements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PCStrings.dataCollected)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 2)
                    ForEach(purpose.dataElements) { de in
                        let deSelected = vm.selectedDataElementsByPurpose[purpose.uuid]?.contains(de.uuid) ?? false
                        Button(action: { vm.toggleDataElement(purpose: purpose, elementUuid: de.uuid) }) {
                            HStack(spacing: 8) {
                                checkbox(isOn: deSelected, size: 16, lineWidth: 1.5)
                                Text(de.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Correction list

    @ViewBuilder
    private var correctionList: some View {
        if vm.uniqueDataElements.isEmpty {
            Text(PCStrings.noFieldsAvailable)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        } else {
            Text(PCStrings.selectFieldsToUpdate)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            VStack(spacing: 8) {
                ForEach(vm.uniqueDataElements) { de in
                    correctionRow(de)
                }
            }
        }
    }

    @ViewBuilder
    private func correctionRow(_ de: PrivacyDataElement) -> some View {
        let isSelected = vm.selectedCorrectionFields.contains(de.uuid)
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { vm.toggleCorrectionField(de.uuid) }) {
                HStack(spacing: 10) {
                    checkbox(isOn: isSelected, size: 20)
                    Text(de.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.text)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            if isSelected {
                VStack(spacing: 8) {
                    PCInput(
                        text: Binding(
                            get: { vm.correctionValues[de.uuid]?.current ?? "" },
                            set: { vm.updateCorrection(uuid: de.uuid, current: $0) }
                        ),
                        placeholder: PCStrings.currentValue,
                        label: PCStrings.currentValue
                    )
                    PCInput(
                        text: Binding(
                            get: { vm.correctionValues[de.uuid]?.updated ?? "" },
                            set: { vm.updateCorrection(uuid: de.uuid, updated: $0) }
                        ),
                        placeholder: PCStrings.newValue,
                        label: PCStrings.newValue
                    )
                }
                .padding(.leading, 30)
            }
        }
    }

    // MARK: - Grievance list

    @ViewBuilder
    private var grievanceList: some View {
        if vm.grievanceOptions.isEmpty {
            Text(PCStrings.noGrievanceTypes)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        } else {
            Text(PCStrings.selectGrievanceType)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            VStack(spacing: 6) {
                ForEach(vm.grievanceOptions) { option in
                    Button(action: { vm.toggleGrievance(option.value) }) {
                        HStack(spacing: 10) {
                            checkbox(isOn: vm.selectedGrievances.contains(option.value), size: 20)
                            Text(option.label)
                                .font(.system(size: 14))
                                .foregroundColor(theme.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Nomination

    @ViewBuilder
    private var nominationFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PCStrings.enterNomineeDetails)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            PCInput(
                text: $vm.nominationData.nomineeEmail,
                placeholder: "nominee@example.com",
                label: PCStrings.nomineeEmail,
                keyboardType: .emailAddress
            )
            PCInput(
                text: Binding(
                    get: { vm.nominationData.nomineeMobile ?? "" },
                    set: { vm.nominationData.nomineeMobile = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "+919876543210",
                label: PCStrings.nomineeMobile,
                keyboardType: .phonePad
            )
        }
    }

    // MARK: - Supporting docs / Note / Confirm / Actions

    @ViewBuilder
    private var supportingDocs: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PCStrings.supportingDocuments)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            VStack(alignment: .leading, spacing: 8) {
                if !vm.uploadedDocs.isEmpty {
                    FlowLayoutCompat(spacing: 8) {
                        ForEach(vm.uploadedDocs) { doc in
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                                Text(doc.fileName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(theme.text)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button(action: { vm.removeDocument(doc.id) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(theme.error)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(theme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Button(action: { showFilePicker = true }) {
                    HStack(spacing: 8) {
                        if vm.isUploading {
                            ProgressView().scaleEffect(0.8).tint(theme.primary)
                        } else {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: vm.uploadedDocs.isEmpty ? 22 : 14))
                                .foregroundColor(theme.primary)
                        }
                        Text(vm.uploadedDocs.isEmpty ? PCStrings.uploadFile : PCStrings.uploadAnotherFile)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, vm.uploadedDocs.isEmpty ? 18 : 10)
                    .background(theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                theme.border,
                                style: StrokeStyle(lineWidth: 1, dash: vm.uploadedDocs.isEmpty ? [4, 3] : [])
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(vm.isUploading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var additionalNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PCStrings.additionalNote)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            PCTextarea(
                text: $vm.additionalNote,
                placeholder: PCStrings.additionalNotePlaceholder
            )
        }
    }

    @ViewBuilder
    private var confirmRow: some View {
        PCCheckbox(
            isOn: $vm.confirmChecked,
            label: "\(PCStrings.iConfirm) *"
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Spacer()
            PCButton(PCStrings.saveDraft, variant: .outline) {}
            PCButton(PCStrings.submit, isLoading: vm.isSubmitting, isDisabled: !vm.canSubmit) {
                Task { await vm.submit() }
            }
        }
    }

    // MARK: - Success

    @ViewBuilder
    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.badgeSuccessBg)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.success)
            }
            Text(PCStrings.requestSubmittedTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            Text(PCStrings.requestSubmittedSubtitle)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            if let id = vm.submittedCaseId {
                VStack(spacing: 6) {
                    Text(PCStrings.caseId)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .textCase(.uppercase)
                    Text(id)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(theme.text)
                    Text(PCStrings.saveCaseIdNotice)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(PCStrings.requestSubmittedNotice)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            PCButton(PCStrings.newRequest, variant: .primary) {
                vm.reset()
                Task { await vm.loadFormData() }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func requiredLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
            Text("*")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.error)
        }
    }

    @ViewBuilder
    private func checkbox(isOn: Bool, size: CGFloat, lineWidth: CGFloat = 2) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isOn ? theme.primary : theme.background)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn ? theme.primary : theme.border, lineWidth: lineWidth)
                )
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

/// Simple wrap-content layout (for uploaded-doc pills). Falls back to VStack on
/// older iOS versions.
struct FlowLayoutCompat<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content
    var body: some View {
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: spacing) { content() }
        } else {
            VStack(alignment: .leading, spacing: spacing) { content() }
        }
    }
}

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    let spacing: CGFloat

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
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        let maxX = bounds.maxX
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
