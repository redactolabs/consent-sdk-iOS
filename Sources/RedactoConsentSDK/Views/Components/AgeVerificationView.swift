import SwiftUI

/// Age verification prompt for minors.
/// Port of the AgeVerification component from RedactoNoticeConsent.tsx.
struct AgeVerificationView: View {
    let onYes: () -> Void
    let onNo: () -> Void
    let onClose: () -> Void
    let settings: ConsentSettings?
    let primaryColor: String?
    let logoUrl: URL?

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                if let logoUrl {
                    RemoteLogoView(
                        url: logoUrl,
                        size: theme.appearance.logoHeight(isPhone: theme.isPhone),
                        maxWidth: theme.appearance.logoMaxWidth(isPhone: theme.isPhone)
                    )
                }
                Text("Age Verification Required")
                    .noticeFont(size: theme.size(.title), weight: theme.weight(.title))
                    .foregroundColor(theme.heading)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.isPhone ? 16 : 18, weight: .medium))
                        .foregroundColor(theme.heading)
                        .padding(theme.isPhone ? 2 : 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close modal")
            }
            .padding(.bottom, 15)

            FittedScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("To proceed with this consent form, we need to verify your age.")
                        .noticeFont(size: theme.size(.privacyText))
                        .foregroundColor(theme.text)
                        .padding(.bottom, 16)

                    Text("Are you 18 years of age or older?")
                        .noticeFont(size: theme.size(.subTitle), weight: theme.weight(.subTitle))
                        .foregroundColor(theme.text)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
                .padding(.top, 15)
        }
    }

    @ViewBuilder
    private var footer: some View {
        let yes = NoticeActionButton(title: "Yes, I am 18 or older", paint: theme.acceptAll, theme: theme, action: onYes)
            .accessibilityLabel("Confirm that I am 18 years of age or older")
        let no = NoticeActionButton(title: "No, I am under 18", paint: theme.decline, theme: theme, action: onNo)
            .accessibilityLabel("Indicate that I am under 18 years of age")
        if theme.isPhone {
            VStack(spacing: 12) { yes; no }
        } else {
            HStack(spacing: 16) { yes; no }
        }
    }
}
