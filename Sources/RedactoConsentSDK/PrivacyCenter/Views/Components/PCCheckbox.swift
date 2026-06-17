import SwiftUI

public struct PCCheckbox: View {
    @Environment(\.privacyCenterTheme) private var theme

    @Binding var isOn: Bool
    let label: String
    let isDisabled: Bool

    public init(isOn: Binding<Bool>, label: String, isDisabled: Bool = false) {
        self._isOn = isOn
        self.label = label
        self.isDisabled = isDisabled
    }

    public var body: some View {
        Button(action: { if !isDisabled { isOn.toggle() } }) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn ? theme.primary : theme.surfaceElevated)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isOn ? theme.primary : theme.border, lineWidth: 1)
                        )
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}
