import SwiftUI

/// The optional welcome message at the top of the consent manager (React
/// `WelcomeBanner`), off unless the settings turn it on.
struct PCWelcomeBanner: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @State private var firstName: String?

    var body: some View {
        if store.settings.portal.welcomeEnabled {
            let title = store.copy(store.settings.portal.welcomeTitle, contact: store.contact, name: firstName)
            let message = store.copy(store.settings.portal.welcomeMessage, contact: store.contact, name: firstName)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(theme.font(size: 20, weight: .semibold))
                    .foregroundColor(theme.text)
                    .accessibilityAddTraits(.isHeader)
                if !message.isEmpty {
                    Text(message)
                        .font(theme.font(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: theme.panelRadius)
                    .fill(theme.isGlass
                        ? AnyShapeStyle(theme.primary.opacity(0.12))
                        : AnyShapeStyle(LinearGradient(
                            colors: [theme.primary.opacity(0.08), theme.surfaceElevated],
                            startPoint: .leading,
                            endPoint: .trailing
                        )))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.panelRadius)
                    .stroke(theme.isGlass ? theme.primary.opacity(0.2) : theme.border, lineWidth: 1)
            )
            .padding(.top, 8)
            .task(id: store.contact) {
                // The session token today holds only contact identifiers, so
                // `{name}` usually collapses out of the copy.
                firstName = PrivacyCenterCopy.principalFirstName(PCJwt.claims(await store.tokenStore.currentRawToken()))
            }
        }
    }
}
