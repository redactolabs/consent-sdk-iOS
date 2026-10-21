import SwiftUI

public struct PCBottomTabBar: View {
    /// One tab: the page it opens and its label.
    public struct Tab: Equatable {
        public let page: PrivacyCenterStore.InternalPage
        public let label: String

        public init(page: PrivacyCenterStore.InternalPage, label: String) {
            self.page = page
            self.label = label
        }
    }

    @Environment(\.privacyCenterTheme) private var theme
    @Binding var selectedPage: PrivacyCenterStore.InternalPage
    private let tabs: [Tab]?

    public init(selectedPage: Binding<PrivacyCenterStore.InternalPage>) {
        self._selectedPage = selectedPage
        self.tabs = nil
    }

    /// The tabs the published settings enable, in their order and with their
    /// labels.
    public init(selectedPage: Binding<PrivacyCenterStore.InternalPage>, tabs: [Tab]) {
        self._selectedPage = selectedPage
        self.tabs = tabs
    }

    /// React's menu names (HREF_TO_NAME_KEY), shown when nothing is published.
    private var shownTabs: [Tab] {
        tabs ?? [
            Tab(page: .consentManager, label: PCStrings.consentManager),
            Tab(page: .form, label: PCStrings.grievance),
            Tab(page: .activity, label: PCStrings.activity),
            Tab(page: .receipts, label: PCStrings.myReceipt),
        ]
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(shownTabs, id: \.page) { tab in
                tabButton(page: tab.page, icon: Self.icon(for: tab.page), label: tab.label)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(minHeight: 56)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(theme.border.opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private static func icon(for page: PrivacyCenterStore.InternalPage) -> String {
        switch page {
        case .consentManager: return "shield.lefthalf.filled"
        case .form, .caseDetails: return "tray.full"
        case .activity: return "clock.arrow.circlepath"
        case .receipts: return "doc.text.magnifyingglass"
        }
    }

    @ViewBuilder
    private func tabButton(page: PrivacyCenterStore.InternalPage, icon: String, label: String) -> some View {
        let isActive = selectedPage == page || (page == .form && selectedPage == .caseDetails)
        Button(action: { selectedPage = page }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(theme.font(size: 18, weight: .medium))
                Text(label)
                    .font(theme.font(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isActive ? theme.primary : theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
