import Foundation

enum PurposePreselectionLogic {
    static let inactiveStatus = "INACTIVE"

    static func resolve(_ raw: String?) -> PurposePreselection {
        switch raw {
        case PurposePreselection.mandatory.rawValue:
            return .mandatory
        case PurposePreselection.all.rawValue:
            return .all
        default:
            return .none
        }
    }

    static func hasRecordedState(_ selection: PurposeSelection?) -> Bool {
        guard let selection else {
            return false
        }
        if !selection.status.isEmpty && selection.status != inactiveStatus {
            return true
        }
        return !selection.dataElements.isEmpty
    }

    static func build(purposes: [ActiveConfigPurpose], mode: PurposePreselection) -> SelectionState {
        if mode == .all {
            return buildSelection(
                purposes: purposes,
                mode: .all,
                current: SelectionState(selectedPurposes: [:], selectedDataElements: [:])
            )
        }

        var selectedPurposes: [String: Bool] = [:]
        var selectedDataElements: [String: Bool] = [:]
        for purpose in purposes {
            var hasPreselectedElement = false
            for element in purpose.dataElements {
                let isPreselected = mode == .mandatory && element.required && element.enabled
                selectedDataElements[dataElementKey(purposeUuid: purpose.uuid, elementUuid: element.uuid)] = isPreselected
                hasPreselectedElement = hasPreselectedElement || isPreselected
            }
            selectedPurposes[purpose.uuid] = hasPreselectedElement
        }
        return SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
    }

    static func seed(rows: [NoticePurposeRow], recordedFor: RecordedLookup, mode: PurposePreselection) -> SelectionState {
        let preselection = build(purposes: uniquePurposes(rows), mode: mode)
        var selectedPurposes: [String: Bool] = [:]
        var selectedDataElements: [String: Bool] = [:]
        for row in rows {
            let seeded = seedRow(
                purpose: row.purpose,
                recorded: recordedFor(row.purpose.uuid, row.productUuid),
                preselection: preselection
            )
            selectedPurposes[ProductMatrix.productPurposeKey(row.productUuid, row.purpose.uuid)] = seeded.purposeSelected
            for element in row.purpose.dataElements {
                let key = dataElementKey(purposeUuid: row.purpose.uuid, elementUuid: element.uuid, productUuid: row.productUuid)
                selectedDataElements[key] = seeded.dataElements[element.uuid] ?? false
            }
        }
        return SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
    }

    private static func uniquePurposes(_ rows: [NoticePurposeRow]) -> [ActiveConfigPurpose] {
        var seen = Set<String>()
        return rows.compactMap { row in
            seen.insert(row.purpose.uuid).inserted ? row.purpose : nil
        }
    }

    static func seedRow(
        purpose: ActiveConfigPurpose,
        recorded: PurposeSelection?,
        preselection: SelectionState
    ) -> PurposeRowSeed {
        let isRecorded = hasRecordedState(recorded)
        let purposeSelected = isRecorded
            ? (recorded?.selected ?? false)
            : (preselection.selectedPurposes[purpose.uuid] ?? false)

        var dataElements: [String: Bool] = [:]
        for element in purpose.dataElements {
            if let recordedElement = recorded?.dataElements[element.uuid] {
                dataElements[element.uuid] = recordedElement.selected
            } else if isRecorded {
                dataElements[element.uuid] = false
            } else {
                dataElements[element.uuid] = preselection.selectedDataElements[
                    dataElementKey(purposeUuid: purpose.uuid, elementUuid: element.uuid)
                ] ?? false
            }
        }
        return PurposeRowSeed(purposeSelected: purposeSelected, dataElements: dataElements)
    }
}
