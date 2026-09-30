import Foundation

public enum SelectionControlType: String {
    case checkbox
    case radio
    case dropdown
}

public enum LogoPosition: String {
    case left
    case center
    case right
}

public enum PurposePreselection: String {
    case none = "NONE"
    case mandatory = "MANDATORY"
    case all = "ALL"
}

public enum ConfirmAction: Equatable {
    case acceptAll
    case acceptSelected
    case decline
}

enum SelectionControlLevel {
    case product
    case purpose
}

enum SelectionControlRendering: Equatable {
    case checkbox
    case lockedTick
    case radio
    case dropdown
    case settledAnswer
}

enum DropdownAnswer: Equatable {
    case yes
    case no
    case mixed
}

struct PurposeRowSeed: Equatable {
    let purposeSelected: Bool
    let dataElements: [String: Bool]
}
