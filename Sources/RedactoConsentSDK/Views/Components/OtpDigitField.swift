import SwiftUI
import UIKit

final class OtpBackspaceTextField: UITextField {
    var onBackspace: (() -> Void)?

    override func deleteBackward() {
        onBackspace?()
    }
}

struct OtpDigitField: UIViewRepresentable {
    let index: Int
    let digit: String
    let enabled: Bool
    let focused: Bool
    let onText: (String) -> Void
    let onBackspace: () -> Void
    let onFocus: () -> Void
    var accessibilityText: String?
    /// A filled box's border and background; `nil` keeps the empty look.
    var filledBorder: UIColor?
    var filledBackground: UIColor?

    private static let emptyBorder = UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> OtpBackspaceTextField {
        let field = OtpBackspaceTextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 18, weight: .semibold)
        field.textColor = UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1)
        field.backgroundColor = .white
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = Self.emptyBorder.cgColor
        if index == 0 {
            field.textContentType = .oneTimeCode
        }
        field.accessibilityLabel = accessibilityText ?? OtpGateCopy.digitLabel(index)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: OtpBackspaceTextField, context: Context) {
        context.coordinator.parent = self
        let coordinator = context.coordinator
        field.onBackspace = { coordinator.parent.onBackspace() }
        if field.text != digit {
            field.text = digit
        }
        field.isEnabled = enabled
        let filled = !digit.isEmpty
        field.layer.borderColor = (filled ? filledBorder : nil)?.cgColor ?? Self.emptyBorder.cgColor
        field.backgroundColor = (filled ? filledBackground : nil) ?? .white
        if focused && enabled && !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !focused && field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OtpDigitField

        init(_ parent: OtpDigitField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = (textField.text ?? "") as NSString
            parent.onText(current.replacingCharacters(in: range, with: string))
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
            parent.onFocus()
        }
    }
}
