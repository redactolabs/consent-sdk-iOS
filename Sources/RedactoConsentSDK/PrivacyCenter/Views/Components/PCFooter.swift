import SwiftUI

/// "Powered by Redacto" (React ui/Footer); hidden by the store when the
/// workspace sets `hide_platform_branding`.
public struct PCFooter: View {
    @Environment(\.privacyCenterTheme) private var theme

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text(PCStrings.poweredBy)
                .font(theme.font(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary)
            Text("Redacto")
                .font(theme.font(size: 11, weight: .bold))
                .foregroundColor(theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

/// The footer the published settings describe (React `ui/Footer.tsx`): links,
/// the privacy policy, contact lines and a copyright above "Powered by", which
/// the settings or a white-labelled workspace can drop.
struct PCSettingsFooter: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: PrivacyCenterStore

    private var content: PrivacyCenterFooterContent {
        PrivacyCenterFooterContent.make(
            footer: store.settings.footer,
            brandContact: store.brandContact,
            brandingPrivacyPolicyUrl: store.branding?.privacyPolicyUrl,
            brandingDpoEmail: store.branding?.dpoEmail,
            hidePlatformBranding: store.branding?.hidePlatformBranding == true,
            privacyPolicyLabel: PCStrings.privacyPolicy,
            copyright: { store.copy($0) }
        )
    }

    var body: some View {
        let content = self.content
        if !content.isEmpty {
            VStack(spacing: 6) {
                if !content.links.isEmpty {
                    links(content.links)
                }
                if content.showsContact {
                    contactLines(content)
                }
                if let copyright = content.copyright {
                    Text(copyright)
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if content.showsPoweredBy {
                    PCFooter()
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .padding(.top, content.hasExtras ? 8 : 0)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
    }

    /// Wraps onto more rows on a narrow screen. Keyed by label and address,
    /// as two links may share an address.
    private func links(_ links: [PrivacyCenterFooterLink]) -> some View {
        FlowLayoutCompat(spacing: 12, centered: true) {
            ForEach(links, id: \.pcFooterKey) { link in
                if let url = URL(string: link.url) {
                    Button(link.label) { openURL(url) }
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundColor(theme.link)
                        .buttonStyle(.plain)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PCStrings.footerLinks)
    }

    @ViewBuilder
    private func contactLines(_ content: PrivacyCenterFooterContent) -> some View {
        VStack(spacing: 4) {
            if content.grievanceEmail != nil || content.grievanceUrl != nil {
                HStack(spacing: 4) {
                    Text(PCStrings.footerGrievanceOfficer)
                        .foregroundColor(theme.textSecondary)
                    if let email = content.grievanceEmail, let url = URL(string: "mailto:\(email)") {
                        Button(email) { openURL(url) }
                            .foregroundColor(theme.link)
                            .buttonStyle(.plain)
                    }
                    if content.grievanceEmail != nil, content.grievanceUrl != nil {
                        Text("·").foregroundColor(theme.textSecondary)
                    }
                    if let form = content.grievanceUrl.flatMap(URL.init(string:)) {
                        Button(PCStrings.footerGrievanceForm) { openURL(form) }
                            .foregroundColor(theme.link)
                            .buttonStyle(.plain)
                    }
                }
            }
            if let board = content.dpBoardUrl.flatMap(URL.init(string:)) {
                Button(PCStrings.footerDataProtectionBoard) { openURL(board) }
                    .foregroundColor(theme.link)
                    .buttonStyle(.plain)
                    .multilineTextAlignment(.center)
            } else {
                Text(PCStrings.footerDataProtectionBoard)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .font(theme.font(size: 12))
    }
}

private extension PrivacyCenterFooterLink {
    var pcFooterKey: String {
        "\(label)|\(url)"
    }
}
