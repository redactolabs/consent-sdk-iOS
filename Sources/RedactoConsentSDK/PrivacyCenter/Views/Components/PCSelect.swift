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

/// A select whose list opens under the field, with the chosen row ticked.
/// `allOptionLabel` adds a first row that clears the selection ("All") and is
/// shown in place of the placeholder; the placeholder itself is never a row.
public struct PCSelect<Value: Hashable>: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selection: Value?
    let options: [PCSelectOption<Value>]
    let placeholder: String
    let label: String?
    let leadingIcon: String?
    let allOptionLabel: String?

    @State private var isOpen = false
    @State private var anchor = PCPresentationAnchor()

    public init(
        selection: Binding<Value?>,
        options: [PCSelectOption<Value>],
        placeholder: String,
        label: String? = nil,
        leadingIcon: String? = nil,
        allOptionLabel: String? = nil
    ) {
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
        self.label = label
        self.leadingIcon = leadingIcon
        self.allOptionLabel = allOptionLabel
    }

    private var selectedLabel: String? {
        if let value = selection, let opt = options.first(where: { $0.value == value }) {
            return opt.label
        }
        return allOptionLabel
    }

    private var rows: [PCSelectDropdownRow] {
        var result: [PCSelectDropdownRow] = []
        if let allOptionLabel {
            result.append(PCSelectDropdownRow(id: "all", label: allOptionLabel, isSelected: selection == nil) { selection = nil })
        }
        for (index, option) in options.enumerated() {
            let value = option.value
            result.append(PCSelectDropdownRow(id: "\(index)", label: option.label, isSelected: selection == value) { selection = value })
        }
        return result
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(theme.font(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            Button(action: open) {
                HStack(spacing: 8) {
                    if let leadingIcon {
                        Image(systemName: leadingIcon)
                            .font(theme.font(size: 13, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    Text(selectedLabel ?? placeholder)
                        .font(theme.font(size: 15))
                        .foregroundColor(selectedLabel == nil ? theme.textTertiary : theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.border, lineWidth: 1)
                )
                .cornerRadius(8)
                .contentShape(Rectangle())
                .background(PCPresentationAnchorView(anchor: anchor))
            }
            .buttonStyle(.plain)
            .accessibilityValue(selectedLabel ?? placeholder)
            .accessibilityHint(label ?? placeholder)
        }
    }

    private func open() {
        let presented = PCSelectDropdownPresenter.present(
            from: anchor.view,
            rows: rows,
            overlay: PCOverlayEnvironment(theme: theme, layoutDirection: layoutDirection, colorScheme: colorScheme),
            onDismiss: { withAnimation(.easeOut(duration: 0.18)) { isOpen = false } }
        )
        if presented {
            withAnimation(.easeOut(duration: 0.18)) { isOpen = true }
        }
    }
}
