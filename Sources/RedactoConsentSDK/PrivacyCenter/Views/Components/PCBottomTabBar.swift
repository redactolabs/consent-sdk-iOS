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
    private var showsSelection = true

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

    /// With the notifications page open no tab is the current one, as on Android.
    func showingSelection(_ shows: Bool) -> PCBottomTabBar {
        var copy = self
        copy.showsSelection = shows
        return copy
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(shownTabs, id: \.page) { tab in
                tabButton(page: tab.page, icon: Self.icon(for: tab.page), label: tab.label)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(minHeight: 64)
        .background(theme.background)
    }

    /// The closest symbols to Android's outlined VerifiedUser, Article,
    /// History and ReceiptLong.
    private static func icon(for page: PrivacyCenterStore.InternalPage) -> String {
        switch page {
        case .consentManager: return "checkmark.shield"
        case .form, .caseDetails: return "doc.text"
        case .activity: return "clock.arrow.circlepath"
        case .receipts: return "doc.text.magnifyingglass"
        }
    }

    /// Material's navigation item: a pill behind the selected icon, the label
    /// under it on up to two lines.
    @ViewBuilder
    private func tabButton(page: PrivacyCenterStore.InternalPage, icon: String, label: String) -> some View {
        let isActive = showsSelection && (selectedPage == page || (page == .form && selectedPage == .caseDetails))
        Button(action: { selectedPage = page }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 56, height: 32)
                    .background(
                        Capsule().fill(isActive ? theme.surface : Color.clear)
                    )
                Text(label)
                    .font(theme.font(size: 10, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(isActive ? theme.primary : theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
