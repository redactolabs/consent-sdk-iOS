import SwiftUI

public struct PCSelectOption<Value: Hashable>: Identifiable {
    public let value: Value
    public let label: String

    public var id: Value { value }

    public init(value: Value, label: String) {
        self.value = value
        self.label = label
    }
}

public struct PCSelect<Value: Hashable>: View {
    @Environment(\.privacyCenterTheme) private var theme

    @Binding var selection: Value?
    let options: [PCSelectOption<Value>]
    let placeholder: String
    let label: String?

    public init(
        selection: Binding<Value?>,
        options: [PCSelectOption<Value>],
        placeholder: String,
        label: String? = nil
    ) {
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
        self.label = label
    }

    private var selectedLabel: String {
        if let value = selection, let opt = options.first(where: { $0.value == value }) {
            return opt.label
        }
        return placeholder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            Menu {
                Button(placeholder) { selection = nil }
                ForEach(options) { option in
                    Button(option.label) { selection = option.value }
                }
            } label: {
                HStack {
                    Text(selectedLabel)
                        .font(.system(size: 15))
                        .foregroundColor(selection == nil ? theme.textTertiary : theme.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.border, lineWidth: 1)
                )
                .cornerRadius(8)
            }
        }
    }
}
