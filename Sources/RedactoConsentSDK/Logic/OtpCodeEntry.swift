import Foundation

enum OtpCodeEntry {
    static func empty(length: Int = OtpGateCopy.length) -> [String] {
        Array(repeating: "", count: length)
    }

    static func code(of digits: [String]) -> String {
        digits.joined()
    }

    static func isComplete(_ digits: [String]) -> Bool {
        !digits.isEmpty && digits.allSatisfy { $0.count == 1 && onlyDigits($0) == $0 }
    }

    static func applyText(_ digits: [String], index: Int, text: String) -> OtpEntry? {
        let length = digits.count
        let previous = digits.indices.contains(index) ? digits[index] : ""

        if text.isEmpty {
            return OtpEntry(digits: replacing(digits, at: index, with: ""), focus: nil)
        }

        let typed = onlyDigits(typedOver(text, previous: previous))
        if typed.isEmpty {
            return nil
        }

        if typed.count == 1 {
            return OtpEntry(
                digits: replacing(digits, at: index, with: typed),
                focus: index + 1 < length ? index + 1 : nil
            )
        }

        let code = String(withoutPrevious(typed, previous: previous, length: length).prefix(length))
        return OtpEntry(
            digits: fillFromStart(code, length: length),
            focus: min(code.count, length - 1)
        )
    }

    static func applyBackspace(_ digits: [String], index: Int) -> OtpEntry {
        if digits.indices.contains(index), !digits[index].isEmpty {
            return OtpEntry(digits: replacing(digits, at: index, with: ""), focus: nil)
        }
        if index <= 0 {
            return OtpEntry(digits: digits, focus: nil)
        }
        return OtpEntry(digits: replacing(digits, at: index - 1, with: ""), focus: index - 1)
    }

    private static func onlyDigits(_ value: String) -> String {
        String(value.filter { ("0"..."9").contains($0) })
    }

    private static func replacing(_ digits: [String], at index: Int, with digit: String) -> [String] {
        digits.enumerated().map { $0.offset == index ? digit : $0.element }
    }

    private static func fillFromStart(_ code: String, length: Int) -> [String] {
        let characters = Array(code)
        return (0..<length).map { $0 < characters.count ? String(characters[$0]) : "" }
    }

    private static func typedOver(_ text: String, previous: String) -> String {
        guard !previous.isEmpty, text.count == previous.count + 1 else {
            return text
        }
        if text.hasPrefix(previous) {
            return String(text.dropFirst(previous.count))
        }
        if text.hasSuffix(previous) {
            return String(text.dropLast(previous.count))
        }
        return text
    }

    private static func withoutPrevious(_ code: String, previous: String, length: Int) -> String {
        guard !previous.isEmpty, code.count > length else {
            return code
        }
        if code.hasPrefix(previous) {
            return String(code.dropFirst(previous.count))
        }
        if code.hasSuffix(previous) {
            return String(code.dropLast(previous.count))
        }
        return code
    }
}
