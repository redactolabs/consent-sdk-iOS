import SwiftUI

/// Confirms a footer action before it submits. Drawn over the notice rather
/// than as a system alert, so it takes the notice's style; the cancelling
/// button comes first, as on the web.
private struct ConfirmDialogModifier: ViewModifier {
    let action: ConfirmAction?
    let onConfirm: (ConfirmAction) -> Void
    let onCancel: () -> Void

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    func body(content: Content) -> some View {
        content.overlay {
            if let action {
                dialog(action)
            }
        }
    }

    private func dialog(_ action: ConfirmAction) -> some View {
        let glass = theme.glass
        let radius: CGFloat = glass == nil ? 12 : GlassPalette.Radius.panel
        let buttonRadius: CGFloat = glass == nil ? 8 : noticePillRadius
        let buttonText = glass == nil ? Color(hex: "#344054") : theme.text
        let buttonEdge = glass?.outline.color ?? Color(hex: "#d0d5dd")
        let confirm = theme.acceptAll
        return ZStack {
            (glass?.dim.color ?? Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255).opacity(0.45))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(alignment: .leading, spacing: 0) {
                Text(ConfirmDialogCopy.title(for: action))
                    .noticeFont(size: 16, weight: glass == nil ? .semibold : .bold)
                    .foregroundColor(glass == nil ? Color(hex: "#101828") : theme.heading)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
                Text(ConfirmDialogCopy.detail(for: action))
                    .noticeFont(size: 14)
                    .foregroundColor(glass == nil ? Color(hex: "#475467") : theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Button(action: onCancel) {
                        Text(ConfirmDialogCopy.cancel)
                            .noticeFont(size: 14, weight: glass == nil ? .regular : .semibold)
                            .foregroundColor(buttonText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: buttonRadius).fill(glass == nil ? Color.white : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: buttonRadius).stroke(buttonEdge, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button { onConfirm(action) } label: {
                        Text(ConfirmDialogCopy.confirm)
                            .noticeFont(size: 14, weight: glass == nil ? .regular : .semibold)
                            .foregroundColor(confirm.foreground)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: theme.buttonRadius).fill(confirm.background))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(RoundedRectangle(cornerRadius: radius).fill(glass?.sheetDense.color ?? Color.white))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(glass?.panelEdge.color ?? .clear, lineWidth: 1))
            .shadow(color: Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255).opacity(0.18), radius: 16, y: 12)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

extension View {
    func noticeConfirmDialog(
        action: ConfirmAction?,
        onConfirm: @escaping (ConfirmAction) -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmDialogModifier(action: action, onConfirm: onConfirm, onCancel: onCancel))
    }
}
