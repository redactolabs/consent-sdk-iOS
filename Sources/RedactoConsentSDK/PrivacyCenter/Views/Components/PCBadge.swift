import SwiftUI

public enum PCBadgeVariant {
    case success, error, warning, info, secondary, pending
}

public struct PCBadge: View {
    @Environment(\.privacyCenterTheme) private var theme

    let label: String
    let variant: PCBadgeVariant
    let icon: String?

    public init(_ label: String, variant: PCBadgeVariant = .secondary, icon: String? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch variant {
        case .success: return theme.badgeSuccessBg
        case .error: return theme.badgeErrorBg
        case .warning, .pending: return theme.badgeWarningBg
        case .info: return theme.badgeInfoBg
        case .secondary: return theme.badgeSecondaryBg
        }
    }

    private var textColor: Color {
        switch variant {
        case .success: return theme.badgeSuccessText
        case .error: return theme.badgeErrorText
        case .warning, .pending: return theme.badgeWarningText
        case .info: return theme.badgeInfoText
        case .secondary: return theme.badgeSecondaryText
        }
    }
}
