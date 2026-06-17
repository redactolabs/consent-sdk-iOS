import SwiftUI

public struct PCLoader: View {
    @Environment(\.privacyCenterTheme) private var theme
    let label: String?

    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.primary)
            if let label {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
