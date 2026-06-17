import SwiftUI

/// A grid that places children in adaptive columns. On narrow screens it falls
/// back to a single column. Used for filter rows, tile groups, etc.
public struct PCAdaptiveColumns<Content: View>: View {
    let minColumnWidth: CGFloat
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    public init(minColumnWidth: CGFloat = 140, spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minColumnWidth), spacing: spacing)],
            alignment: .leading,
            spacing: spacing,
            content: content
        )
    }
}

/// A horizontally-scrolling row of pills/tabs that gracefully overflows instead
/// of squishing on small screens.
public struct PCScrollingTabBar<Content: View>: View {
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    @ViewBuilder var content: () -> Content

    public init(spacing: CGFloat = 8, horizontalPadding: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing, content: content)
                .padding(.horizontal, horizontalPadding)
        }
    }
}

/// Card surface with consistent corner radius, padding and (light theme) shadow.
public struct PCCard<Content: View>: View {
    @Environment(\.privacyCenterTheme) private var theme
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder var content: () -> Content

    public init(padding: CGFloat = 14, cornerRadius: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .cornerRadius(cornerRadius)
            .shadow(
                color: theme.mode == .light ? Color.black.opacity(0.04) : Color.clear,
                radius: 4, x: 0, y: 1
            )
    }
}
