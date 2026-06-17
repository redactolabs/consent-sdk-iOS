import SwiftUI

public struct PCAvatar: View {
    @Environment(\.privacyCenterTheme) private var theme
    let initial: String
    let size: CGFloat

    public init(initial: String, size: CGFloat = 36) {
        self.initial = initial
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(theme.primarySoft)
            .frame(width: size, height: size)
            .overlay(
                Text(initial.uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(theme.primary)
            )
    }
}
