import Foundation

extension String {
    /// Strip HTML tags and decode common HTML entities.
    /// Port of the `stripHtml` function from the React Native SDK.
    func strippingHTML() -> String {
        var result = self
            .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
