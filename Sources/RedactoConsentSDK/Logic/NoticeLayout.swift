import SwiftUI
import UIKit

enum NoticeLayout {
    static func resolveLogoPosition(_ raw: String?) -> LogoPosition {
        switch raw {
        case LogoPosition.center.rawValue:
            return .center
        case LogoPosition.right.rawValue:
            return .right
        default:
            return .left
        }
    }

    static func alignment(for position: LogoPosition) -> Alignment {
        switch position {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

enum NoticeFontResolver {
    static let defaultFamilyId = "arial"

    static let catalogue: [String: [String]] = [
        "montserrat": ["Montserrat", "Trebuchet MS", "Segoe UI", "Arial"],
        "arial": ["Arial", "Helvetica"],
        "georgia": ["Georgia", "Times New Roman", "Times"],
        "times new roman": ["Times New Roman", "Times"],
        "trebuchet ms": ["Trebuchet MS", "Lucida Sans Unicode", "Lucida Grande"],
        "verdana": ["Verdana", "Geneva"],
    ]

    static let genericKeywords: Set<String> = [
        "inherit", "initial", "revert", "revert-layer", "unset", "serif", "sans-serif",
        "monospace", "cursive", "fantasy", "system-ui", "ui-serif", "ui-sans-serif",
        "ui-monospace", "ui-rounded", "math", "emoji", "fangsong",
    ]

    static func candidates(hostFont: String?, noticeFont: String?) -> [String] {
        if let host = hostFont?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ").union(.whitespacesAndNewlines)) }
                .filter { !$0.isEmpty && !genericKeywords.contains($0.lowercased()) }
        }
        guard let stored = noticeFont?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty else {
            return []
        }
        return catalogue[stored.lowercased()] ?? catalogue[defaultFamilyId] ?? []
    }

    static func resolve(hostFont: String?, noticeFont: String?, installed: (String) -> String?) -> String? {
        for candidate in candidates(hostFont: hostFont, noticeFont: noticeFont) {
            if let family = installed(candidate) {
                return family
            }
        }
        return nil
    }

    static func installedFamily(_ name: String) -> String? {
        if let family = UIFont.familyNames.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return family
        }
        return UIFont(name: name, size: 12) == nil ? nil : name
    }

    static func font(family: String?, size: CGFloat, weight: Font.Weight) -> Font {
        guard let family else {
            return .system(size: size, weight: weight)
        }
        return Font.custom(family, fixedSize: size).weight(cssMatchedWeight(weight, family: family))
    }

    /// CSS draws a 500 the family lacks with its 400 face, where iOS reaches for
    /// the bold one: Arial has no medium, so the web's medium purpose titles
    /// read as regular there and must here too.
    static func cssMatchedWeight(_ weight: Font.Weight, family: String) -> Font.Weight {
        guard weight == .medium else { return weight }
        let faces = UIFont.fontNames(forFamilyName: family)
        return faces.contains { $0.localizedCaseInsensitiveContains("medium") } ? .medium : .regular
    }
}
