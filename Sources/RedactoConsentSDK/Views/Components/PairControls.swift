import SwiftUI

/// How the inline and assisted purpose rows draw: sizes, colours, control and
/// copy. The defaults are the rows as they have always drawn.
struct PairRowStyle {
    var titleSize: CGFloat = 16
    var descriptionSize: CGFloat = 12
    var elementSize: CGFloat = 14
    /// `nil` draws the description in the row's text colour.
    var descriptionColor: Color?
    var chevronColor: Color?
    /// React's assisted rows leave an empty description out.
    var hidesEmptyDescription = false
    var selectionControl: SelectionControlType = .checkbox
    /// Checkbox rows as switches, their data elements as round checks.
    var switchControl = false
    var purposeBoxSize: CGFloat = 20
    var elementBoxSize: CGFloat = 16
    var controlOffColor = Color(hex: "#d0d5dd")
    var knobColor = Color.white
    var rowBackground: Color?
    var rowCornerRadius: CGFloat = 0
    var rowPadding = EdgeInsets()
    var rowDivider: Color?
    var lockedOpacity: Double = 1
    var collapseLabel: (_ collapsed: Bool, _ name: String) -> String = { collapsed, name in
        "\(collapsed ? "Expand" : "Collapse") \(name)"
    }
    var purposeControlLabel: (_ name: String) -> String = { "Select all data elements for \($0)" }
    var elementLabel: (_ name: String, _ required: Bool) -> String = { name, required in
        "Select \(name)\(required ? " (required)" : "")"
    }
    var requiredLabel = "required"
    /// Talkback: whether an element id is the one being read, and its paint.
    var isHighlighted: (String) -> Bool = { _ in false }
    var highlightBackground = Color(hex: NoticeAppearanceDefaults.ttsHighlightBackground)
    var highlightText: Color?
    var purposeNameId: (String) -> String = AssistedElementId.purposeName
    var purposeDescriptionId: (String) -> String = AssistedElementId.purposeDescription
    var elementId: (String, String) -> String = AssistedElementId.dataElement
}

/// A square checkbox drawn the way the React SDK's injected stylesheet draws
/// `.redacto-checkbox-*`: a 2pt outline off, the accent filled with a tick on.
struct PairCheckbox: View {
    let checked: Bool
    let size: CGFloat
    let accent: Color
    let offColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(checked ? accent : Color.clear)
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(checked ? accent : offColor, lineWidth: 2)
                if checked {
                    Path { path in
                        path.move(to: CGPoint(x: size * 0.28, y: size * 0.5))
                        path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.66))
                        path.addLine(to: CGPoint(x: size * 0.74, y: size * 0.34))
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size >= 17 ? 2 : 1.5, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/// The switch React draws over a checkbox when the notice asks for switches
/// (`switchCss.ts`): a pill track, the accent when on, a knob that slides.
struct PairSwitch: View {
    let isOn: Bool
    let width: CGFloat
    let height: CGFloat
    let thumb: CGFloat
    let accent: Color
    let track: Color
    let knob: Color
    var animates = true
    let action: () -> Void

    private let inset: CGFloat = 3

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? accent : track)
                Circle()
                    .fill(knob)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255).opacity(0.25), radius: 3, y: 2)
                    .offset(x: inset + (isOn ? width - thumb - inset * 2 : 0))
            }
            .frame(width: width, height: height)
            .animation(animates ? .easeOut(duration: 0.28) : nil, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The data element's round check that accompanies a switch.
struct PairRoundCheck: View {
    let checked: Bool
    let accent: Color
    let outline: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(checked ? accent : Color.white)
                Circle()
                    .strokeBorder(checked ? accent : outline, lineWidth: 1.5)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/// Talkback's highlight behind the text being read; the caller swaps the text
/// colour, which an outer modifier cannot override.
struct PairHighlight: ViewModifier {
    let isOn: Bool
    let background: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(background.opacity(isOn ? 1 : 0))
                    .padding(.horizontal, -2)
                    .padding(.vertical, -1)
            )
    }
}
