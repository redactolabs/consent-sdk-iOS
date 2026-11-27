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
                        .font(theme.font(size: 16, weight: .semibold))
                        .foregroundColor(theme.text)
                        .frame(width: 32, height: 32)
                        .background(theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.font(size: 17, weight: .semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(theme.font(size: 11, weight: .medium))
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
                        .font(theme.font(size: 14, weight: .semibold))
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
                .font(theme.font(size: 14, weight: .semibold))
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

/// Compact language picker button that opens the language list under the pill.
public struct PCLanguagePickerButton: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedCode: String
    let options: [PrivacyCenterLanguage]
    let onSelect: (String) -> Void
    @State private var anchor = PCPresentationAnchor()

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
        Button(action: handleOpen) {
            PCLanguagePill(code: selectedCode)
        }
        .buttonStyle(.plain)
        .background(PCPresentationAnchorView(anchor: anchor))
        .accessibilityLabel(options.first { $0.code == selectedCode }?.label ?? selectedCode)
    }

    private func handleOpen() {
        let current = selectedCode
        let options = options
        let overlay = PCOverlayEnvironment(theme: theme, layoutDirection: layoutDirection, colorScheme: colorScheme)
        _ = PCOverlayHost.present(from: anchor.view) { host, frame in
            let close: () -> Void = { [weak host] in PCOverlayHost.dismiss(host) }
            return AnyView(
                PCLanguageDropdownLayer(anchor: frame, onDismiss: close) { availableHeight in
                    PCLanguageDropdown(selectedCode: current, options: options, availableHeight: availableHeight) { code in
                        close()
                        if code != current {
                            selectedCode = code
                            onSelect(code)
                        }
                    }
                }
                .pcOverlayEnvironment(overlay)
            )
        }
    }
}

private struct PCLanguageDropdownLayer<Content: View>: View {
    @Environment(\.layoutDirection) private var contentDirection
    let anchor: CGRect
    let onDismiss: () -> Void
    @ViewBuilder let content: (CGFloat) -> Content

    private static var gap: CGFloat { 4 }
    private static var margin: CGFloat { 16 }

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = max(0, proxy.size.height - anchor.maxY - Self.gap - Self.margin)
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityLabel(PCStrings.close)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onDismiss)
                content(availableHeight)
                    .environment(\.layoutDirection, contentDirection)
                    .fixedSize()
                    .padding(.top, anchor.maxY + Self.gap)
                    .padding(.trailing, max(0, proxy.size.width - anchor.maxX))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .ignoresSafeArea()
    }
}

/// The header's language trigger, as Android's LanguageSelectorPill draws it.
struct PCLanguagePill: View {
    @Environment(\.privacyCenterTheme) private var theme
    let code: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(theme.textSecondary)
            Text(Self.shortCode(code))
                .font(theme.font(size: 12, weight: .semibold))
                .foregroundColor(theme.text)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: PCTopBar.controlHeight)
        .background(theme.background)
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
        .clipShape(Capsule())
    }

    static func shortCode(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code)).uppercased()
    }
}

/// The language list Android opens under the pill: one row per language,
/// the selected one in the primary colour with a tick at the end.
struct PCLanguageDropdown: View {
    @Environment(\.privacyCenterTheme) private var theme
    let selectedCode: String
    let options: [PrivacyCenterLanguage]
    var availableHeight: CGFloat = .infinity
    let onSelect: (String) -> Void

    private static let rowHeight: CGFloat = 44
    private static let maxHeight: CGFloat = 360

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(options) { lang in
                    row(lang)
                }
            }
        }
        .frame(width: 240, height: listHeight)
        .pcDropdownCard()
    }

    private var listHeight: CGFloat {
        let wanted = min(CGFloat(options.count) * Self.rowHeight, Self.maxHeight - 16)
        return max(Self.rowHeight, min(wanted, availableHeight - 16))
    }

    private func row(_ lang: PrivacyCenterLanguage) -> some View {
        let selected = lang.code == selectedCode
        return Button {
            onSelect(lang.code)
        } label: {
            HStack(spacing: 8) {
                Text(lang.label)
                    .font(theme.font(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundColor(selected ? theme.primary : theme.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    /// The surface of a Material DropdownMenu: the page background, small
    /// corners and a soft shadow, with 8pt above and below the rows.
    func pcDropdownCard() -> some View {
        modifier(PCDropdownCard())
    }
}

private struct PCDropdownCard: ViewModifier {
    @Environment(\.privacyCenterTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
    }
}
