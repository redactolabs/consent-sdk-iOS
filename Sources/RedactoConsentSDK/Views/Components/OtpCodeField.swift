import SwiftUI

struct OtpCodeField: View {
    let digits: [String]
    let isDisabled: Bool
    let hasError: Bool
    let onChange: ([String]) -> Void
    var digitLabel: ((Int) -> String)?
    var filledBorder: UIColor?
    var filledBackground: UIColor?
    var spacing: CGFloat = 8
    /// Extra room before a box, as React's assisted flow groups 3 + 3.
    var groupGapBefore: Int?
    var boxSize: CGFloat?

    @State private var focusedIndex: Int? = 0

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(digits.indices, id: \.self) { index in
                OtpDigitField(
                    index: index,
                    digit: digits[index],
                    enabled: !isDisabled,
                    focused: focusedIndex == index,
                    onText: { text in apply(OtpCodeEntry.applyText(digits, index: index, text: text)) },
                    onBackspace: { apply(OtpCodeEntry.applyBackspace(digits, index: index)) },
                    onFocus: { focusedIndex = index },
                    accessibilityText: digitLabel?(index),
                    filledBorder: filledBorder,
                    filledBackground: filledBackground
                )
                .frame(height: boxSize ?? 48)
                .frame(maxWidth: boxSize ?? .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#D92D20"), lineWidth: hasError ? 1.5 : 0)
                )
                .padding(.leading, index == groupGapBefore ? 8 : 0)
            }
        }
        .onChange(of: hasError) { failed in
            if failed {
                focusedIndex = 0
            }
        }
    }

    private func apply(_ entry: OtpEntry?) {
        guard let entry else { return }
        onChange(entry.digits)
        if OtpCodeEntry.isComplete(entry.digits) {
            focusedIndex = nil
            return
        }
        if let focus = entry.focus {
            focusedIndex = focus
        }
    }
}
