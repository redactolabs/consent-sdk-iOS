import SwiftUI

/// Custom checkbox toggle matching the React Native SDK's Checkbox component.
/// Inside the modal notice it paints with the notice's theme.
struct CheckboxView: View {
    let checked: Bool
    let onChange: () -> Void
    var size: CheckboxSize = .large
    var accentColor: String = "#4f87ff"
    var indeterminate: Bool = false

    @Environment(\.noticeTheme) private var theme

    enum CheckboxSize {
        case large, medium, small

        var dimension: CGFloat {
            switch self {
            case .large: return 20
            case .medium: return 17
            case .small: return 16
            }
        }
    }

    private var onColor: Color { theme?.checkboxOn ?? Color(hex: accentColor) }
    private var offColor: Color { theme?.checkboxOff ?? Color(hex: "#d0d5dd") }
    private var lineWidth: CGFloat { size == .small ? 1.5 : 2 }

    var body: some View {
        Button(action: onChange) {
            ZStack {
                if checked {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(onColor)
                        .frame(width: size.dimension, height: size.dimension)

                    Path { path in
                        let w = size.dimension
                        let h = size.dimension
                        path.move(to: CGPoint(x: w * 0.25, y: h * 0.5))
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.67))
                        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.33))
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: size.dimension, height: size.dimension)
                } else if indeterminate {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(onColor)
                        .frame(width: size.dimension, height: size.dimension)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: size.dimension * 0.5, height: lineWidth)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme?.checkboxFill ?? .clear)
                        .frame(width: size.dimension, height: size.dimension)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(offColor, lineWidth: 1.5)
                        .frame(width: size.dimension, height: size.dimension)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
