import SwiftUI

/// The "Request Details" block of the form (Android DsrRequestDetailsBlock).
extension DSRFormScreen {
    @ViewBuilder
    var requestDetailsBody: some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Products (Android DsrProductSection)

    @ViewBuilder
    private var productSection: some View {
        if vm.isTranslating {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(theme.border.opacity(0.5)).frame(height: 48)
                }
            }
        } else if vm.groups.isEmpty {
            PCEmpty(title: PCStrings.noProductsAvailable, subtitle: PCStrings.noProductsAvailableDescription, icon: "shippingbox")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.requestType.map { PCStrings.selectProductsForRequest($0.label) } ?? PCStrings.selectProductsForRequestGeneric)
                    .font(theme.font(size: 12))
                    .foregroundColor(theme.textSecondary)
                ForEach(vm.directGroups + vm.nominatedGroups) { group in
                    productRow(group)
                }
            }
        }
    }

    private func productRow(_ group: FormProductGroup) -> some View {
        let isSelected = vm.selectedProductKey == group.id
        return Button(action: { vm.selectProduct(group) }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.productName)
                    .font(theme.font(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Text(PCStrings.activePurposes(DSRFormViewModel.groupPurposes(group).count))
                    .font(theme.font(size: 12))
                    .foregroundColor(theme.textTertiary)
                if let nominator = group.nominator {
                    Text(PCStrings.nominationChipSuffix(nominator.name.pcNonEmpty ?? nominator.email ?? ""))
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? theme.primarySoft : theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? theme.primary : theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Purposes (Android DsrPurposeSection)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Correction (Android DsrCorrectionSection)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        if !vm.selectedCorrectionNames.isEmpty {
            Divider()
            Text("\(PCStrings.enterCorrectValue) *")
                .font(theme.font(size: 13, weight: .medium))
                .foregroundColor(theme.text)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Grievance / Nomination

    private var grievanceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PCStrings.selectGrievance)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
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
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var nominationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PCStrings.enterNomineeDetails)
                .font(theme.font(size: 12))
                .foregroundColor(theme.textSecondary)
            labeledField(PCStrings.nomineeEmail) {
                PCInput(
                    text: $vm.nominationData.nomineeEmail,
                    placeholder: PCStrings.nomineeEmailPlaceholder,
                    keyboardType: .emailAddress
                )
            }
            labeledField(PCStrings.nomineeMobile) {
                PCInput(
                    text: Binding(
                        get: { vm.nominationData.nomineeMobile ?? "" },
                        set: { vm.nominationData.nomineeMobile = $0.isEmpty ? nil : $0 }
                    ),
                    placeholder: PCStrings.nomineeMobilePlaceholder,
                    keyboardType: .phonePad
                )
            }
        }
    }
}
