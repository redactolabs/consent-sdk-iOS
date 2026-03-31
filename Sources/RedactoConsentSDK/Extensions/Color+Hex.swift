import SwiftUI

extension Color {
    /// Initialize a Color from a hex string (e.g., "#4f87ff", "4f87ff", "#fff").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 3: // RGB (12-bit)
            r = Double((int >> 8) & 0xF) / 15
            g = Double((int >> 4) & 0xF) / 15
            b = Double(int & 0xF) / 15
            a = 1
        case 6: // RGB (24-bit)
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8: // ARGB (32-bit)
            a = Double((int >> 24) & 0xFF) / 255
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
