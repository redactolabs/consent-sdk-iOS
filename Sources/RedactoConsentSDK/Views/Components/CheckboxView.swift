import SwiftUI

/// Custom checkbox toggle matching the React Native SDK's Checkbox component.
struct CheckboxView: View {
    let checked: Bool
    let onChange: () -> Void
    var size: CheckboxSize = .large
    var accentColor: String = "#4f87ff"

    enum CheckboxSize {
        case large, small

        var dimension: CGFloat {
            switch self {
            case .large: return 20
            case .small: return 16
            }
        }
    }

    var body: some View {
        Button(action: onChange) {
            ZStack {
                if checked {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: accentColor))
                        .frame(width: size.dimension, height: size.dimension)

                    // Checkmark
                    Path { path in
                        let w = size.dimension
                        let h = size.dimension
                        path.move(to: CGPoint(x: w * 0.25, y: h * 0.5))
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.67))
                        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.33))
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size == .large ? 2 : 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: size.dimension, height: size.dimension)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "#d0d5dd"), lineWidth: 1.5)
                        .frame(width: size.dimension, height: size.dimension)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
