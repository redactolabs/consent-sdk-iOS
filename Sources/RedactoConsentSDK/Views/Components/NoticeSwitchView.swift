import SwiftUI

/// A purpose or product checkbox drawn as a switch, when the console or the
/// host asks for switches. A partly ticked product parks the thumb mid-track.
struct NoticeSwitchView: View {
    let checked: Bool
    var indeterminate = false
    var large = false
    let theme: NoticeTheme
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var width: CGFloat { large ? 44 : 40 }
    private var height: CGFloat { large ? 26 : 24 }
    private var thumb: CGFloat { large ? 20 : 18 }
    private let inset: CGFloat = 3

    private var offset: CGFloat {
        let travel = width - thumb - inset * 2
        if indeterminate { return travel / 2 }
        return checked ? travel : 0
    }

    private var track: Color {
        if indeterminate { return theme.switchOn.opacity(0.55) }
        return checked ? theme.switchOn : theme.switchTrack
    }

    var body: some View {
        Button(action: onChange) {
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Circle()
                    .fill(theme.knob)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255).opacity(0.25), radius: 3, y: 2)
                    .offset(x: inset + offset)
            }
            .frame(width: width, height: height)
            .animation(
                NoticeMotion.animation(NoticeMotion.collapse, enabled: NoticeMotion.isEnabled(theme.layout, reduceMotion: reduceMotion)),
                value: offset
            )
        }
        .buttonStyle(.plain)
    }
}

/// A data element's round check, the switch's companion.
struct NoticeRoundCheckView: View {
    let checked: Bool
    let theme: NoticeTheme
    let onChange: () -> Void

    var body: some View {
        Button(action: onChange) {
            ZStack {
                Circle()
                    .fill(checked ? theme.switchOn : (theme.glass?.control.color ?? .white))
                Circle()
                    .stroke(checked ? theme.switchOn : (theme.glass?.outline.color ?? theme.switchTrack), lineWidth: 1.5)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}
