import SwiftUI

struct OtpGatePanelView: View {
    let title: String
    let description: String
    let submitLabel: String
    let digits: [String]
    let busy: Bool
    let error: String?
    let confirmEnabled: Bool
    let buttonBackground: Color
    let buttonTextColor: Color
    let onDigitsChange: ([String]) -> Void
    let onConfirm: () -> Void

    @State private var focusedIndex: Int? = 0
    @Environment(\.noticeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .noticeFont(size: 13, weight: .semibold)
                .foregroundColor(theme?.otpTitle ?? Color(hex: "#111827"))
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .noticeFont(size: 12)
                .foregroundColor(theme?.otpDescription ?? Color(hex: "#6b7280"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                ForEach(digits.indices, id: \.self) { index in
                    OtpDigitField(
                        index: index,
                        digit: digits[index],
                        enabled: !busy,
                        focused: focusedIndex == index,
                        onText: { text in apply(OtpCodeEntry.applyText(digits, index: index, text: text)) },
                        onBackspace: { apply(OtpCodeEntry.applyBackspace(digits, index: index)) },
                        onFocus: { focusedIndex = index }
                    )
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                }
            }

            if let error {
                Text(error)
                    .noticeFont(size: 12)
                    .foregroundColor(Color(hex: "#dc2626"))
                    .padding(.top, 8)
            }

            Button(action: onConfirm) {
                Text(submitLabel)
                    .noticeFont(size: 16)
                    .foregroundColor(buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(buttonBackground)
                    .cornerRadius(theme?.buttonRadius ?? 8)
                    .opacity(confirmEnabled ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!confirmEnabled)
            .padding(.top, 10)
        }
        .padding(12)
        .background(theme?.otpPanel.fill ?? Color(hex: "#f9fafb"))
        .cornerRadius(theme?.otpPanel.radius ?? 8)
        .overlay(RoundedRectangle(cornerRadius: theme?.otpPanel.radius ?? 8).stroke(theme?.otpPanel.edge ?? Color(hex: "#e5e7eb"), lineWidth: 1))
        .padding(.top, 8)
        .padding(.bottom, 4)
        .onChange(of: error) { newError in
            if newError != nil {
                focusedIndex = 0
            }
        }
    }

    private func apply(_ entry: OtpEntry?) {
        guard let entry else { return }
        onDigitsChange(entry.digits)
        if OtpCodeEntry.isComplete(entry.digits) {
            focusedIndex = nil
            return
        }
        if let focus = entry.focus {
            focusedIndex = focus
        }
    }
}
