import SwiftUI

public enum PCButtonVariant {
    case primary, outline, ghost, destructive
}

public enum PCButtonSize {
    case regular, compact
}

public struct PCButton: View {
    @Environment(\.privacyCenterTheme) private var theme

    let title: String
    let variant: PCButtonVariant
    let size: PCButtonSize
    let fullWidth: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let leadingIcon: String?
    let trailingIcon: String?
    let action: () -> Void

    public init(
        _ title: String,
        variant: PCButtonVariant = .primary,
        size: PCButtonSize = .regular,
        fullWidth: Bool? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.fullWidth = fullWidth ?? (variant == .primary && size == .regular)
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    public var body: some View {
        Button(action: { if !isDisabled && !isLoading { action() } }) {
            HStack(spacing: size == .compact ? 6 : 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: size == .compact ? 13 : 15, weight: .semibold))
                if let trailingIcon, !isLoading {
                    Image(systemName: trailingIcon)
                        .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size == .compact ? 14 : 20)
            .padding(.vertical, size == .compact ? 8 : 12)
            .frame(minHeight: size == .compact ? 34 : 44)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: size == .compact ? 8 : 10)
                    .stroke(borderColor, lineWidth: variant == .outline ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: size == .compact ? 8 : 10))
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return theme.primaryText
        case .outline: return theme.text
        case .ghost: return theme.text
        case .destructive: return Color.white
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return theme.primary
        case .outline: return theme.surfaceElevated
        case .ghost: return Color.clear
        case .destructive: return theme.error
        }
    }

    private var borderColor: Color {
        switch variant {
        case .outline: return theme.border
        default: return Color.clear
        }
    }
}
