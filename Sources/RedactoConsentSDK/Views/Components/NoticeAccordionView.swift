import SwiftUI

/// A collapsed-by-default section of the notice body (the notice text, the DPO
/// block), when the layout collapses them. Closed content leaves the view, so
/// its links leave the accessibility tree with it.
struct NoticeAccordionView<Content: View>: View {
    let icon: String
    let title: String
    var clampTitle = false
    var hint: String?
    let open: Bool
    /// Held open by talkback: toggles are ignored until it ends.
    var locked = false
    let theme: NoticeTheme
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let panel = theme.sectionPanel
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !locked { onToggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: theme.controlRadius).fill(theme.accentWash))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .noticeFont(size: 14, weight: clampTitle ? .semibold : .bold)
                            .foregroundColor(theme.heading)
                            .lineLimit(clampTitle ? 2 : nil)
                            .multilineTextAlignment(.leading)
                        if let hint, !open {
                            Text(hint)
                                .noticeFont(size: 12)
                                .foregroundColor(theme.text)
                                .opacity(0.75)
                                .lineLimit(1)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .opacity(0.7)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(theme.isPhone ? EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
                    : EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(clampTitle ? Self.briefName(title) : title)
            .accessibilityValue(open ? "Expanded" : "Collapsed")

            if open {
                content()
                    .noticeFont(size: theme.isPhone ? 13 : 14)
                    .foregroundColor(theme.text)
                    .padding(theme.isPhone ? EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14)
                        : EdgeInsets(top: 0, leading: 62, bottom: 16, trailing: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: panel.radius).fill(panel.fill))
        .overlay(RoundedRectangle(cornerRadius: panel.radius).stroke(panel.edge ?? .clear, lineWidth: 1))
        .animation(
            NoticeMotion.animation(NoticeMotion.collapse, enabled: NoticeMotion.isEnabled(theme.layout, reduceMotion: reduceMotion)),
            value: open
        )
    }

    /// A short accessible name that starts with the visible title.
    static func briefName(_ text: String, limit: Int = 80) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        let prefix = String(collapsed.prefix(limit))
        return prefix.trimmingCharacters(in: .whitespaces) + "…"
    }
}
