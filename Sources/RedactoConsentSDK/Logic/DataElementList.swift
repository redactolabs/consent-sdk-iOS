import SwiftUI

/// A purpose's data elements as the one line a notice draws once they carry no
/// tick of their own (`show_data_element_controls: false`): the names,
/// comma-separated, each mandatory one followed by the required marker, and
/// the one talkback is reading highlighted.
enum DataElementList {
    static let separator = ", "
    static let requiredMarker = " *"

    static func line(
        _ elements: [ActiveConfigDataElement],
        name: (ActiveConfigDataElement) -> String,
        isHighlighted: (ActiveConfigDataElement) -> Bool,
        highlightBackground: Color,
        highlightText: Color?
    ) -> AttributedString {
        var line = AttributedString()
        for (index, element) in elements.enumerated() {
            if index > 0 {
                line.append(AttributedString(separator))
            }
            let highlighted = isHighlighted(element)
            var label = AttributedString(name(element))
            if highlighted, let highlightText {
                label.foregroundColor = highlightText
            }
            if ProductConsent.isBlockingRequiredElement(element) {
                var marker = AttributedString(requiredMarker)
                marker.foregroundColor = Color.red
                label.append(marker)
            }
            if highlighted {
                label.backgroundColor = highlightBackground
            }
            line.append(label)
        }
        return line
    }

    /// What VoiceOver reads for the line: the names, a mandatory one said so.
    static func accessibilityLabel(
        _ elements: [ActiveConfigDataElement],
        name: (ActiveConfigDataElement) -> String
    ) -> String {
        elements
            .map { ProductConsent.isBlockingRequiredElement($0) ? "\(name($0)) (required)" : name($0) }
            .joined(separator: separator)
    }
}
