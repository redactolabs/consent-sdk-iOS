import Foundation

enum SelectionControlLogic {
    static func shouldReport(_ next: Bool, checked: Bool, indeterminate: Bool) -> Bool {
        indeterminate || next != checked
    }

    static func holds(_ value: Bool, checked: Bool, indeterminate: Bool, locked: Bool) -> Bool {
        locked ? value : (!indeterminate && checked == value)
    }

    static func rendering(control: SelectionControlType, locked: Bool) -> SelectionControlRendering {
        switch control {
        case .checkbox:
            return locked ? .lockedTick : .checkbox
        case .radio:
            return .radio
        case .dropdown:
            return locked ? .settledAnswer : .dropdown
        }
    }

    static func dropdownAnswer(checked: Bool, indeterminate: Bool) -> DropdownAnswer {
        if indeterminate {
            return .mixed
        }
        return checked ? .yes : .no
    }

    static func optionLabel(_ label: String, value: Bool, recordedAnswer: Bool?) -> String {
        recordedAnswer == value ? "\(label) \(SelectionControlCopy.onRecord(label))" : label
    }
}
