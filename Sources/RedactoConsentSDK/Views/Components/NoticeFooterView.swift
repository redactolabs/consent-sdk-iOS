import SwiftUI

/// One of the notice's buttons, painted from the theme.
struct NoticeActionButton: View {
    let title: String
    let paint: NoticeButtonPaint
    let theme: NoticeTheme
    var fullWidth = true
    var opacity: Double = 1
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .noticeFont(size: theme.size(.button), weight: theme.weight(.button))
                .multilineTextAlignment(.center)
                .foregroundColor(paint.foreground)
                .padding(.horizontal, theme.isGlass ? (theme.isPhone ? 16 : 24) : 20)
                .padding(.vertical, theme.isGlass ? 10 : (theme.isPhone ? 10 : 9))
                // Web: 9px padding around a 21px line, plus the 1px border when drawn.
                .frame(
                    maxWidth: fullWidth ? .infinity : nil,
                    minHeight: theme.isGlass ? (theme.isPhone ? 48 : 44) : (paint.border == nil ? 39 : 41)
                )
                .background(RoundedRectangle(cornerRadius: theme.buttonRadius).fill(paint.background))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.buttonRadius)
                        .stroke(paint.border ?? .clear, lineWidth: 1)
                )
                .noticeShadow(paint.shadow)
                .opacity(opacity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// The notice's three actions.
///
///   wide:   [Decline] <-- gap --> [Accept Selected] [Accept All]
///   narrow: [Accept All] / [Accept Selected] / [Decline], stacked full width
///   paired: [Accept All] / [Accept Selected] [Decline]
///
/// Emitted in a different order per layout rather than reordered, so focus
/// order follows visual order. Only Accept Selected is gated on the required
/// data elements.
struct NoticeFooterView: View {
    let acceptAllLabel: String
    let acceptSelectedLabel: String
    let declineLabel: String
    let acceptSelectedDisabled: Bool
    let acceptSelectedHint: String?
    let isSubmittingAccept: Bool
    let isSubmitting: Bool
    let theme: NoticeTheme
    let activeTTSSegmentKey: String?
    let onAcceptAll: () -> Void
    let onAcceptSelected: () -> Void
    let onDecline: () -> Void

    var body: some View {
        if theme.isPhone && theme.layout.pairedFooter {
            VStack(spacing: theme.isGlass ? 8 : 12) {
                acceptAll(fullWidth: true)
                HStack(spacing: 8) {
                    acceptSelected(fullWidth: true)
                    decline(fullWidth: true)
                }
            }
        } else if theme.isPhone {
            VStack(spacing: theme.isGlass ? 8 : 12) {
                acceptAll(fullWidth: true)
                acceptSelected(fullWidth: true)
                decline(fullWidth: true)
            }
        } else {
            HStack(spacing: theme.isGlass ? 10 : 12) {
                decline(fullWidth: false)
                Spacer(minLength: 12)
                acceptSelected(fullWidth: false)
                acceptAll(fullWidth: false)
            }
        }
    }

    private func acceptAll(fullWidth: Bool) -> some View {
        NoticeActionButton(
            title: isSubmittingAccept ? NoticeCopy.submitting : acceptAllLabel,
            paint: theme.acceptAll,
            theme: theme,
            fullWidth: fullWidth,
            opacity: isSubmitting ? 0.5 : 1,
            disabled: isSubmitting,
            action: onAcceptAll
        )
        .ttsSegmentHighlighted(activeTTSSegmentKey == "accept_all_button_text", buttonStyle: true)
        .id("accept_all_button_text")
        .accessibilityLabel(acceptAllLabel)
    }

    private func acceptSelected(fullWidth: Bool) -> some View {
        NoticeActionButton(
            title: isSubmittingAccept ? NoticeCopy.submitting : acceptSelectedLabel,
            paint: theme.acceptSelected,
            theme: theme,
            fullWidth: fullWidth,
            opacity: acceptSelectedDisabled ? 0.5 : 1,
            disabled: acceptSelectedDisabled,
            action: onAcceptSelected
        )
        .ttsSegmentHighlighted(activeTTSSegmentKey == "confirm_button_text", buttonStyle: true)
        .id("confirm_button_text")
        .accessibilityLabel(acceptSelectedLabel)
        .accessibilityHint(acceptSelectedHint ?? "")
    }

    private func decline(fullWidth: Bool) -> some View {
        NoticeActionButton(
            title: declineLabel,
            paint: theme.decline,
            theme: theme,
            fullWidth: fullWidth,
            opacity: isSubmittingAccept ? 0.5 : 1,
            disabled: isSubmitting,
            action: onDecline
        )
        .ttsSegmentHighlighted(activeTTSSegmentKey == "decline_button_text", buttonStyle: true)
        .id("decline_button_text")
        .accessibilityLabel(declineLabel)
    }
}
