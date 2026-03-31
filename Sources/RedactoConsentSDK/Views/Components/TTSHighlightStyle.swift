import SwiftUI

struct TTSSegmentHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    let buttonStyle: Bool

    private let highlightColor = Color(hex: "#FFF9C4")
    private let textHighlightCornerRadius: CGFloat = 4
    private let textHighlightHorizontalInset: CGFloat = 2
    private let textHighlightVerticalInset: CGFloat = 1

    func body(content: Content) -> some View {
        if buttonStyle {
            content.overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(highlightColor.opacity(isHighlighted ? 1 : 0), lineWidth: 3)
            )
        } else {
            content
                // Keep layout metrics stable; only change highlight visuals.
                .background(
                    RoundedRectangle(cornerRadius: textHighlightCornerRadius)
                        .fill(highlightColor.opacity(isHighlighted ? 1 : 0))
                        .padding(.horizontal, -textHighlightHorizontalInset)
                        .padding(.vertical, -textHighlightVerticalInset)
                )
        }
    }
}

extension View {
    func ttsSegmentHighlighted(_ highlighted: Bool, buttonStyle: Bool = false) -> some View {
        modifier(TTSSegmentHighlightModifier(isHighlighted: highlighted, buttonStyle: buttonStyle))
    }
}
