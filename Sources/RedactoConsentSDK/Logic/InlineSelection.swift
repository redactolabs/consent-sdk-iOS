import Foundation

enum InlineSelection {
    static func inlineElementKey(_ productUuid: String?, _ purposeUuid: String, _ elementUuid: String) -> String {
        dataElementKey(purposeUuid: purposeUuid, elementUuid: elementUuid, productUuid: productUuid)
    }

    static func inlinePurposeRows(_ config: ActiveConfig) -> [NoticePurposeRow] {
        ProductMatrix.noticePurposeRows(config.products, config.purposes, order: config.productPurposeOrder)
    }

    static func productGroups(_ config: ActiveConfig) -> [ProductPurposeGroup] {
        guard ProductMatrix.isMultiProduct(config.products) else { return [] }
        return ProductMatrix.groupPurposesByProduct(config.products, config.purposes, order: config.productPurposeOrder)
    }

    static func initialCollapsedPurposes(_ rows: [NoticePurposeRow]) -> [String: Bool] {
        ProductConsent.collapseEveryRow(rows)
    }

    /// Seeds from the notice's own pre-selection mode (NONE unless configured),
    /// as React's inline notice does; the inline read carries no recorded grants.
    static func initialSelection(_ rows: [NoticePurposeRow], preselection: PurposePreselection = .none) -> SelectionState {
        PurposePreselectionLogic.seed(rows: rows, recordedFor: { _, _ in nil }, mode: preselection)
    }

    static func allRequiredElementsChecked(_ rows: [NoticePurposeRow], _ selectedDataElements: [String: Bool]) -> Bool {
        rows.allSatisfy { row in
            row.purpose.dataElements
                .filter(ProductConsent.isBlockingRequiredElement)
                .allSatisfy { selectedDataElements[inlineElementKey(row.productUuid, row.purpose.uuid, $0.uuid)] ?? false }
        }
    }

    static func withPurposeElements(
        _ purpose: ActiveConfigPurpose,
        _ productUuid: String?,
        _ selected: Bool,
        _ selectedDataElements: [String: Bool]
    ) -> [String: Bool] {
        var updated = selectedDataElements
        for element in purpose.dataElements {
            updated[inlineElementKey(productUuid, purpose.uuid, element.uuid)] = selected
        }
        return updated
    }

    static func toggleDataElement(
        _ purpose: ActiveConfigPurpose,
        _ elementUuid: String,
        _ productUuid: String?,
        _ selectedDataElements: [String: Bool]
    ) -> DataElementToggle {
        let combinedId = inlineElementKey(productUuid, purpose.uuid, elementUuid)
        var next = selectedDataElements
        next[combinedId] = !(selectedDataElements[combinedId] ?? false)
        let purposeSelected = ProductConsent.purposeCheckedFromElements(
            purpose: purpose,
            productUuid: productUuid,
            selectedDataElements: next
        )
        return DataElementToggle(selectedDataElements: next, purposeSelected: purposeSelected)
    }

    static func buildInlineSubmitPurposes(_ rows: [NoticePurposeRow], _ selection: SelectionState) -> [Purpose] {
        rows.map { row in
            let purpose = row.purpose
            let key = ProductMatrix.productPurposeKey(row.productUuid, purpose.uuid)
            let isTicked = { (elementUuid: String) in
                selection.selectedDataElements["\(key)-\(elementUuid)"] ?? false
            }
            let hasSelectedRequiredElement = purpose.dataElements.contains { $0.required && isTicked($0.uuid) }
            let hasSelectedDataElement = purpose.dataElements.contains { isTicked($0.uuid) }
            let purposeSelected = (selection.selectedPurposes[key] ?? false)
                || hasSelectedRequiredElement
                || hasSelectedDataElement
            return Purpose(
                uuid: purpose.uuid,
                name: purpose.name,
                description: purpose.description,
                industries: purpose.industries,
                selected: purposeSelected,
                dataElements: purpose.dataElements.map { element in
                    DataElement(
                        uuid: element.uuid,
                        name: element.name,
                        description: element.description,
                        industries: element.industries,
                        enabled: element.enabled,
                        required: element.required,
                        selected: isTicked(element.uuid)
                    )
                },
                productUuid: row.productUuid
            )
        }
    }

    static func inlineSubmissionKey(token: String, configUuid: String, selection: SelectionState) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let state = ["purposes": selection.selectedPurposes, "elements": selection.selectedDataElements]
        let encoded = (try? encoder.encode(state)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return [token, configUuid, encoded].joined(separator: "\n")
    }
}
