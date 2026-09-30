import SwiftUI

/// Page title and description under the top bar (React AppShell/PageHeader),
/// with an optional status chip beside the title.
struct PCPageHeader: View {
    @Environment(\.privacyCenterTheme) private var theme
    let title: String
    let description: String?
    var status: (label: String, isSuccess: Bool)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                if let status {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(status.isSuccess ? theme.success : theme.warning)
                            .frame(width: 7, height: 7)
                        Text(status.label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(status.isSuccess ? theme.success : theme.badgeWarningText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((status.isSuccess ? theme.success : theme.warning).opacity(0.12))
                    .overlay(Capsule().stroke((status.isSuccess ? theme.success : theme.warning).opacity(0.35), lineWidth: 1))
                    .clipShape(Capsule())
                }
            }
            if let description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }
}

/// "Rows per page" and "Page X of Y" with first/previous/next/last (React
/// AdvancedTablePagination, mobile layout).
struct PCPaginationBar: View {
    @Environment(\.privacyCenterTheme) private var theme
    let currentPage: Int
    let totalPages: Int
    let pageSize: Int
    var pageSizeOptions: [Int] = [5, 10, 15, 20, 25]
    let onPage: (Int) -> Void
    let onPageSize: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(PCStrings.rowsPerPage)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                Menu {
                    ForEach(pageSizeOptions, id: \.self) { size in
                        Button {
                            onPageSize(size)
                        } label: {
                            if size == pageSize { Label("\(size)", systemImage: "checkmark") } else { Text("\(size)") }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(pageSize)").font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(theme.border, lineWidth: 1))
                }
            }
            HStack(spacing: 8) {
                Text(PCStrings.pageOf(currentPage, total: max(totalPages, 1)))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                pageButton("chevron.left.2", PCStrings.goToFirstPage, enabled: currentPage > 1) { onPage(1) }
                pageButton("chevron.left", PCStrings.goToPreviousPage, enabled: currentPage > 1) { onPage(currentPage - 1) }
                pageButton("chevron.right", PCStrings.goToNextPage, enabled: currentPage < totalPages) { onPage(currentPage + 1) }
                pageButton("chevron.right.2", PCStrings.goToLastPage, enabled: currentPage < totalPages) { onPage(totalPages) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func pageButton(_ icon: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.text)
                .frame(width: 32, height: 32)
                .background(theme.surfaceElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

/// The toast React raises, as a banner along the top.
struct PCToastView: View {
    @Environment(\.privacyCenterTheme) private var theme
    let toast: PCToastMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(toast.text)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch toast.kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var foreground: Color {
        switch toast.kind {
        case .success: return theme.badgeSuccessText
        case .error: return theme.badgeErrorText
        case .info: return theme.badgeInfoText
        }
    }

    private var background: Color {
        switch toast.kind {
        case .success: return theme.badgeSuccessBg
        case .error: return theme.badgeErrorBg
        case .info: return theme.badgeInfoBg
        }
    }
}

/// Segmented pill tabs (case list statuses, notification categories).
struct PCSegmentedTabs<Value: Hashable>: View {
    @Environment(\.privacyCenterTheme) private var theme
    let options: [(value: Value, label: String)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    let isActive = option.value == selection
                    Button(action: { onSelect(option.value) }) {
                        Text(option.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isActive ? theme.primaryText : theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isActive ? theme.primary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.isGlass ? 999 : 6))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: theme.isGlass ? 999 : 8).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.isGlass ? 999 : 8))
        }
    }
}

/// A circle with initials, tinted by a hash of the seed (React product avatar).
struct PCInitialsAvatar: View {
    let text: String
    let seed: String
    var size: CGFloat = 36

    private static let palette = ["#4f46e5", "#0ea5e9", "#10b981", "#f59e0b", "#ec4899", "#6b7280"]

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        var hash: Int32 = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(truncatingIfNeeded: scalar.value)
        }
        let color = Self.palette[Int(abs(Int(hash)) % Self.palette.count)]
        return Circle()
            .fill(Color(hex: color))
            .frame(width: size, height: size)
            .overlay(
                Text(text)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

/// React's circular status pill with a leading dot (ConsentManagerCells).
struct PCConsentStatusPill: View {
    @Environment(\.privacyCenterTheme) private var theme
    let consent: UserConsent

    var body: some View {
        let color: Color = {
            switch consent.status {
            case .active: return theme.success
            case .withdrawn: return theme.error
            case .expired, .declined: return theme.warning
            case .unknown: return theme.textSecondary
            }
        }()
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(ConsentManagerViewModel.statusLabel(consent))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .fixedSize()
    }
}
