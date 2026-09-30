import Foundation

/// English fallbacks for the action buttons, used when the notice config omits
/// a label — an older consent-server, or a notice published before the
/// accept-all shortcut existed.
public enum NoticeButtonDefaults {
    public static let acceptAll = "Accept All"
    public static let acceptSelected = "Accept Selected"
    public static let decline = "Decline"
}

enum PurposeStatus {
    static let active = "ACTIVE"
}

enum ConfirmHintCopy {
    static let nothingChosen = "Select at least one purpose to confirm."
    static let nothingEngaged = "Select or change a purpose for the product you are consenting to."
    static let requiredOutstanding = "Accept the required purposes to confirm."

    static func productsIncomplete(_ productNames: [String]) -> String {
        "Accept the required purposes for \(productNames.joined(separator: ", ")) to confirm."
    }
}

enum ProductSectionCopy {
    static func toggleSelection(_ productName: String, _ purposeCount: Int) -> String {
        "Toggle all \(purposeCount) purposes for \(productName)"
    }

    static func toggleRequired(_ productName: String, _ purposeCount: Int) -> String {
        "Toggle the \(purposeCount) required purposes for \(productName)"
    }

    static func expand(_ productName: String) -> String {
        "Expand \(productName)"
    }

    static func collapse(_ productName: String) -> String {
        "Collapse \(productName)"
    }

    static func settled(_ productName: String) -> String {
        "Already consented to \(productName)"
    }
}
