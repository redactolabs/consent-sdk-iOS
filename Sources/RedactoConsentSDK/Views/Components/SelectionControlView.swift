import SwiftUI

struct SelectionControlView: View {
    let control: SelectionControlType
    let checked: Bool
    var indeterminate = false
    var locked = false
    var recordedAnswer: Bool?
    var level: SelectionControlLevel = .purpose
    let label: String
    let lockedLabel: String
    var accentColor = "#4f87ff"
    let onSelect: (Bool) -> Void

    @Environment(\.noticeTheme) private var theme

    private var settledColor: Color { Color(hex: "#667085") }
    private var borderColor: Color { Color(hex: "#d0d5dd") }
    private var tickColor: Color { Color(hex: "#10B981") }

    private var tickSize: CGFloat { level == .product ? 20 : 17 }
    private var glyphSize: CGFloat { level == .product ? 12 : 10 }
    private var radioSize: CGFloat { level == .product ? 17 : 13 }
    private var optionFontSize: CGFloat { level == .product ? 14 : 12 }
    private var dropdownFontSize: CGFloat { level == .product ? 13 : 12 }
    private var slotWidth: CGFloat { level == .product ? 68 : 62 }

    /// Classic radios keep the SDK blue; glass paints them with the brand.
    private var radioAccent: Color {
        guard let theme else { return Color(hex: accentColor) }
        return theme.isGlass ? theme.accent : Color(hex: "#4f87ff")
    }

    private var optionColor: Color {
        if locked { return settledColor }
        return theme?.text ?? Color(hex: "#344054")
    }

    var body: some View {
        switch SelectionControlLogic.rendering(control: control, locked: locked) {
        case .lockedTick:
            lockedTick
        case .checkbox:
            if let theme, theme.layout.switchControl {
                NoticeSwitchView(
                    checked: checked,
                    indeterminate: indeterminate,
                    large: level == .product,
                    theme: theme,
                    onChange: { select(indeterminate ? true : !checked) }
                )
                .accessibilityLabel(label)
                .accessibilityValue(accessibilityValue)
            } else {
                checkbox
            }
        case .radio:
            radioGroup
        case .dropdown:
            dropdown
        case .settledAnswer:
            settledAnswer
        }
    }

    private var accessibilityValue: String {
        indeterminate ? SelectionControlCopy.mixed : (checked ? SelectionControlCopy.yes : SelectionControlCopy.no)
    }

    private func select(_ next: Bool) {
        guard !locked, SelectionControlLogic.shouldReport(next, checked: checked, indeterminate: indeterminate) else {
            return
        }
        onSelect(next)
    }

    private var lockedTick: some View {
        ZStack {
            Circle()
                .fill(tickColor)
                .frame(width: tickSize, height: tickSize)
            Image(systemName: "checkmark")
                .font(.system(size: glyphSize * 0.8, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.leading, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lockedLabel)
        .accessibilityAddTraits(.isImage)
    }

    private var checkbox: some View {
        CheckboxView(
            checked: checked,
            onChange: { select(indeterminate ? true : !checked) },
            size: level == .product ? .large : .medium,
            accentColor: accentColor,
            indeterminate: indeterminate
        )
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var radioGroup: some View {
        HStack(spacing: level == .product ? 10 : 8) {
            radioOption(SelectionControlCopy.yes, value: true)
            radioOption(SelectionControlCopy.no, value: false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(locked ? lockedLabel : label)
    }

    private func radioOption(_ title: String, value: Bool) -> some View {
        let held = SelectionControlLogic.holds(value, checked: checked, indeterminate: indeterminate, locked: locked)
        return Button {
            select(value)
        } label: {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(held ? radioAccent : borderColor, lineWidth: 1.5)
                    if held {
                        Circle()
                            .fill(radioAccent)
                            .padding(radioSize * 0.25)
                    }
                }
                .frame(width: radioSize, height: radioSize)
                Text(title)
                    .noticeFont(size: optionFontSize, weight: level == .product ? .medium : .regular)
                    .foregroundColor(optionColor)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(SelectionControlLogic.optionLabel(title, value: value, recordedAnswer: recordedAnswer))
        .accessibilityAddTraits(held ? .isSelected : [])
    }

    private var dropdownTitle: String {
        switch SelectionControlLogic.dropdownAnswer(checked: checked, indeterminate: indeterminate) {
        case .yes:
            return SelectionControlCopy.yes
        case .no:
            return SelectionControlCopy.no
        case .mixed:
            return SelectionControlCopy.mixed
        }
    }

    private var dropdownForeground: Color {
        guard let theme, theme.isGlass else { return Color(hex: "#344054") }
        return theme.heading
    }

    private var dropdown: some View {
        let glass = theme?.glass
        let radius: CGFloat = glass == nil ? 6 : GlassPalette.Radius.control
        return Menu {
            Button(SelectionControlCopy.yes) { select(true) }
            Button(SelectionControlCopy.no) { select(false) }
        } label: {
            HStack(spacing: 4) {
                Text(dropdownTitle)
                    .noticeFont(size: dropdownFontSize, weight: level == .product ? .medium : .regular)
                    .foregroundColor(dropdownForeground)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(dropdownForeground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: slotWidth)
            .background(glass?.control.color ?? Color.white)
            .cornerRadius(radius)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(glass?.outline.color ?? borderColor, lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityValue(dropdownTitle)
    }

    private var settledAnswer: some View {
        Text(SelectionControlCopy.yes)
            .noticeFont(size: dropdownFontSize, weight: level == .product ? .medium : .regular)
            .foregroundColor(settledColor)
            .lineLimit(1)
            .padding(.vertical, 5)
            .frame(width: slotWidth, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(lockedLabel)
    }
}
