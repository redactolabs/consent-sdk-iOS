import SwiftUI

public struct PCNavbar<Trailing: View>: View {
    @Environment(\.privacyCenterTheme) private var theme

    let title: String
    let subtitle: String?
    let onBack: (() -> Void)?
    let onClose: (() -> Void)?
    let trailing: Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.onClose = onClose
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 32, height: 32)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            trailing
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 32, height: 32)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.background)
        .overlay(
            Rectangle()
                .fill(theme.border.opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

/// Round 32x32 icon button used in the navbar.
public struct PCIconButton: View {
    @Environment(\.privacyCenterTheme) private var theme
    let systemName: String
    let action: () -> Void

    public init(systemName: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 34, height: 34)
                .background(theme.surface)
                .overlay(
                    Circle().stroke(theme.border, lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Compact language picker button that opens a Menu of language options.
public struct PCLanguagePickerButton: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Binding var selectedCode: String
    let options: [PrivacyCenterLanguage]
    let onSelect: (String) -> Void

    public init(
        selectedCode: Binding<String>,
        options: [PrivacyCenterLanguage] = PrivacyCenterLanguages.all,
        onSelect: @escaping (String) -> Void
    ) {
        self._selectedCode = selectedCode
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options) { lang in
                Button {
                    selectedCode = lang.code
                    onSelect(lang.code)
                } label: {
                    HStack {
                        Text(lang.label)
                        if lang.code == selectedCode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                Text(selectedCode.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.surface)
            .overlay(
                Capsule().stroke(theme.border, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }
}
