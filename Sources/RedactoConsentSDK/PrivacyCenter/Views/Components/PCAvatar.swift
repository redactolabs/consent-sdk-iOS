import SwiftUI

public struct PCAvatar: View {
    @Environment(\.privacyCenterTheme) private var theme
    let initial: String
    let size: CGFloat
    private var style: Style = .soft

    enum Style {
        case soft
        case solid
    }

    public init(initial: String, size: CGFloat = 36) {
        self.initial = initial
        self.size = size
    }

    /// `solid` is the Android PCAvatar's INFO disc: the brand colour with text on it.
    init(initial: String, size: CGFloat, style: Style) {
        self.initial = initial
        self.size = size
        self.style = style
    }

    public var body: some View {
        Circle()
            .fill(style == .solid ? theme.info : theme.primarySoft)
            .frame(width: size, height: size)
            .overlay(
                Text(initial.uppercased())
                    .font(.system(size: size * (style == .solid ? 0.4 : 0.42), weight: .semibold))
                    .foregroundColor(style == .solid ? theme.primaryText : theme.primary)
            )
    }

    /// Android's `initialsFromEmail`: the first letters of a dotted handle, else
    /// its first character. A mobile number gives its first digit.
    static func initials(fromContact contact: String) -> String {
        let trimmed = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let handle = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
        let parts = handle.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
        if parts.count >= 2, let a = parts[0].first, let b = parts[1].first {
            return "\(a)\(b)".uppercased()
        }
        if let first = handle.first(where: { $0.isLetter || $0.isNumber }) {
            return String(first).uppercased()
        }
        return "?"
    }
}
