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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(theme.font(size: 40, weight: .light))
                .foregroundColor(theme.textTertiary)
                .frame(width: 48, height: 48)
            Text(title)
                .font(theme.font(size: 16, weight: .semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
