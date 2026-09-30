import Foundation

/// Which of the two accept buttons was pressed. The submitted payload is
/// identical in shape for both — only the purpose/data-element selection
/// differs, so the host app still sees a single `onAccept`.
public enum AcceptMode {
    case all
    case selected
}

/// Checkbox state, keyed the way the view model holds it: purposes by uuid,
/// data elements by `"<purposeUuid>-<elementUuid>"`.
public struct SelectionState {
    public let selectedPurposes: [String: Bool]
    public let selectedDataElements: [String: Bool]

    public init(selectedPurposes: [String: Bool], selectedDataElements: [String: Bool]) {
        self.selectedPurposes = selectedPurposes
        self.selectedDataElements = selectedDataElements
    }
}

/// Composite key for a data element's checkbox state — a data element uuid is
/// only unique within its purpose, since the same element can be attached to
/// several purposes on one notice.
public func dataElementKey(purposeUuid: String, elementUuid: String, productUuid: String? = nil) -> String {
    "\(ProductMatrix.productPurposeKey(productUuid, purposeUuid))-\(elementUuid)"
}

/// Resolves the checkbox state that a given accept button should submit.
///
/// - `.all` selects every purpose and every enabled data element.
/// - `.selected` is the user's own ticks, returned untouched.
public func buildSelection(
    purposes: [ActiveConfigPurpose],
    mode: AcceptMode,
    current: SelectionState
) -> SelectionState {
    if mode == .selected { return current }

    var selectedPurposes: [String: Bool] = [:]
    var selectedDataElements: [String: Bool] = [:]

    for purpose in purposes {
        selectedPurposes[purpose.uuid] = true
        for element in purpose.dataElements {
            selectedDataElements[dataElementKey(purposeUuid: purpose.uuid, elementUuid: element.uuid)] = element.enabled
        }
    }

    return SelectionState(
        selectedPurposes: selectedPurposes,
        selectedDataElements: selectedDataElements
    )
}
