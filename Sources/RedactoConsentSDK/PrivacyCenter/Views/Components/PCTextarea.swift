import SwiftUI

public struct PCTextarea: View {
    @Environment(\.privacyCenterTheme) private var theme

    @Binding var text: String
    let placeholder: String
    let label: String?
    let minHeight: CGFloat
    let isDisabled: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        label: String? = nil,
        minHeight: CGFloat = 88,
        isDisabled: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.label = label
        self.minHeight = minHeight
        self.isDisabled = isDisabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(theme.text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: minHeight, alignment: .topLeading)
                    .disabled(isDisabled)
            }
            .background(theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border, lineWidth: 1)
            )
            .cornerRadius(8)
            .opacity(isDisabled ? 0.6 : 1)
        }
    }
}
