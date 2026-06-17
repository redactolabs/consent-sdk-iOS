import SwiftUI

public struct PCInput: View {
    @Environment(\.privacyCenterTheme) private var theme
    @FocusState private var isFocused: Bool

    @Binding var text: String
    let placeholder: String
    let label: String?
    let leadingIcon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let errorMessage: String?
    let isDisabled: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        label: String? = nil,
        leadingIcon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        errorMessage: String? = nil,
        isDisabled: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.label = label
        self.leadingIcon = leadingIcon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.errorMessage = errorMessage
        self.isDisabled = isDisabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            HStack(spacing: 8) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .focused($isFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .focused($isFocused)
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(theme.text)
                .disabled(isDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isFocused ? 1.5 : 1)
            )
            .cornerRadius(10)
            .opacity(isDisabled ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: isFocused)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return theme.error }
        return isFocused ? theme.primary : theme.border
    }
}
