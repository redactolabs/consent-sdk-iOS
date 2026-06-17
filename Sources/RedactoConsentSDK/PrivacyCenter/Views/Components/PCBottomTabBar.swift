import SwiftUI

public struct PCBottomTabBar: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Binding var selectedPage: PrivacyCenterStore.InternalPage

    public init(selectedPage: Binding<PrivacyCenterStore.InternalPage>) {
        self._selectedPage = selectedPage
    }

    public var body: some View {
        HStack(spacing: 0) {
            tabButton(page: .consentManager, icon: "shield.lefthalf.filled", label: PCStrings.consents)
            tabButton(page: .form, icon: "tray.full", label: PCStrings.requests)
            tabButton(page: .activity, icon: "clock.arrow.circlepath", label: PCStrings.activities)
            tabButton(page: .receipts, icon: "doc.text.magnifyingglass", label: PCStrings.myReceipt)
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

    @ViewBuilder
    private func tabButton(page: PrivacyCenterStore.InternalPage, icon: String, label: String) -> some View {
        let isActive = selectedPage == page || (page == .form && selectedPage == .caseDetails)
        Button(action: { selectedPage = page }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? theme.primary : theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
