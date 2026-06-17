import SwiftUI

public struct PCEmpty: View {
    @Environment(\.privacyCenterTheme) private var theme
    let title: String
    let subtitle: String?
    let icon: String

    public init(title: String, subtitle: String? = nil, icon: String = "tray") {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}
