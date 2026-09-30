import SwiftUI

/// A colour as channels: `r`, `g`, `b` in 0...255 and `a` in 0...1, the shape
/// the React SDK's colour maths works in.
public struct AppearanceRGBA: Equatable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public var color: Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// Colour helpers ported from the React SDK's `shared/appearance/color.ts`.
///
/// CSS hex is `#RRGGBBAA`, unlike `Color(hex:)`, which reads eight digits as
/// ARGB; console colours (an `overlay` of `#00000080`) must go through here.
public enum AppearanceColor {
    private static let hexPattern = try! NSRegularExpression(
        pattern: "^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})\\z",
        options: [.caseInsensitive]
    )

    private static let number = #"(\d+(?:\.\d+)?|\.\d+)"#
    // Each channel is a number or a percentage, as CSS allows.
    private static let rgbPattern = try! NSRegularExpression(
        pattern: #"^rgba?\(\s*"# + number + #"(%?)[\s,]+"# + number + #"(%?)[\s,]+"# + number
            + #"(%?)(?:[\s,/]+"# + number + #"(%?))?\s*\)\z"#,
        options: [.caseInsensitive]
    )

    /// Served colours are hex only: `#RGB`, `#RRGGBB` or `#RRGGBBAA`.
    private static let servedHexPattern = try! NSRegularExpression(
        pattern: "^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\\z",
        options: [.caseInsensitive]
    )

    static func isServedHex(_ value: String) -> Bool {
        matches(servedHexPattern, value) != nil
    }

    /// Parses hex and `rgb()`/`rgba()`; anything else (names, `var()`, `hsl()`)
    /// returns `nil`.
    public static func parse(_ input: String?) -> AppearanceRGBA? {
        guard let input, !input.isEmpty else { return nil }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let groups = matches(hexPattern, value), var digits = groups[1] {
            if digits.count <= 4 {
                digits = digits.map { "\($0)\($0)" }.joined()
            }
            let chars = Array(digits)
            func byte(_ index: Int) -> Double {
                Double(UInt8(String(chars[index..<index + 2]), radix: 16) ?? 0)
            }
            return AppearanceRGBA(r: byte(0), g: byte(2), b: byte(4), a: chars.count == 8 ? byte(6) / 255 : 1)
        }
        if let groups = matches(rgbPattern, value) {
            func channel(_ index: Int) -> Double {
                let raw = Double(groups[index] ?? "") ?? 0
                return groups[index + 1]?.isEmpty == false ? raw * 255 / 100 : raw
            }
            let alpha: Double
            if let rawAlpha = groups[7].flatMap(Double.init) {
                alpha = groups[8]?.isEmpty == false ? rawAlpha / 100 : rawAlpha
            } else {
                alpha = 1
            }
            return AppearanceRGBA(
                r: clampByte(channel(1)),
                g: clampByte(channel(3)),
                b: clampByte(channel(5)),
                a: clampUnit(alpha)
            )
        }
        return nil
    }

    /// `color` when it parses, else `fallback`. A malformed value ("4f87ff",
    /// "#12345") would otherwise paint black and poison every colour derived
    /// from it. Named colours and CSS functions, which the web passes through
    /// to the browser, have no native painter and take the fallback too.
    public static func paintable(_ color: String?, fallback: String) -> String {
        guard let value = color?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return parse(value) != nil ? value : fallback
    }

    /// The SwiftUI colour for a CSS colour string, or `nil` when it does not parse.
    public static func color(_ value: String?) -> Color? {
        parse(value)?.color
    }

    /// `color` at `alpha` opacity.
    public static func withAlpha(_ color: AppearanceRGBA, _ alpha: Double) -> AppearanceRGBA {
        normalised(AppearanceRGBA(r: color.r, g: color.g, b: color.b, a: color.a * alpha))
    }

    /// `a` blended toward `b` by `t` (0 = a, 1 = b), fully opaque.
    public static func mix(_ a: AppearanceRGBA, _ b: AppearanceRGBA, _ t: Double) -> AppearanceRGBA {
        let k = clampUnit(t)
        return normalised(AppearanceRGBA(
            r: a.r + (b.r - a.r) * k,
            g: a.g + (b.g - a.g) * k,
            b: a.b + (b.b - a.b) * k,
            a: 1
        ))
    }

    /// `color` composited over `base`, so a translucent value becomes the solid
    /// colour it would look like there.
    public static func opaqueOver(_ color: AppearanceRGBA, _ base: AppearanceRGBA) -> AppearanceRGBA {
        mix(base, AppearanceRGBA(r: color.r, g: color.g, b: color.b, a: 1), color.a)
    }

    /// String forms of the above for callers holding CSS colour strings; `nil`
    /// when an input does not parse.
    public static func withAlpha(_ color: String, _ alpha: Double) -> AppearanceRGBA? {
        parse(color).map { withAlpha($0, alpha) }
    }

    public static func mix(_ a: String, _ b: String, _ t: Double) -> AppearanceRGBA? {
        guard let pa = parse(a), let pb = parse(b) else { return nil }
        return mix(pa, pb, t)
    }

    // MARK: - Private

    /// Rounds as the web's `rgba()` output does: whole bytes, alpha to 3 places.
    private static func normalised(_ c: AppearanceRGBA) -> AppearanceRGBA {
        AppearanceRGBA(
            r: clampByte(c.r),
            g: clampByte(c.g),
            b: clampByte(c.b),
            a: (clampUnit(c.a) * 1000).rounded() / 1000
        )
    }

    private static func clampByte(_ n: Double) -> Double {
        min(255, max(0, n.rounded()))
    }

    private static func clampUnit(_ n: Double) -> Double {
        min(1, max(0, n))
    }

    /// Capture groups of a whole-string match, `nil` for groups that did not take part.
    private static func matches(_ regex: NSRegularExpression, _ value: String) -> [String?]? {
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: value).map { String(value[$0]) }
        }
    }
}
