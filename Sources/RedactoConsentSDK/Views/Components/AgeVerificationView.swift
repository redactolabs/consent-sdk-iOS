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

    private var headingColor: Color {
        Color(hex: settings?.headingColor ?? "#323B4B")
    }

    private var textColor: Color {
        Color(hex: settings?.textColor ?? "#344054")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section
            HStack {
                HStack(spacing: 8) {
                    if let logoUrl {
                        RemoteLogoView(url: logoUrl, size: 32)
                    }

                    Text("Age Verification Required")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(headingColor)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(headingColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .overlay(Divider(), alignment: .bottom)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To proceed with this consent form, we need to verify your age.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(textColor)

                    Text("Are you 18 years of age or older?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)

            // Buttons
            VStack(spacing: 8) {
                Button(action: onYes) {
                    Text("Yes, I am 18 or older")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: settings?.button?.accept?.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color(hex: settings?.button?.accept?.backgroundColor ?? primaryColor ?? "#4f87ff"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onNo) {
                    Text("No, I am under 18")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: settings?.button?.decline?.textColor ?? "#000000"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color(hex: settings?.button?.decline?.backgroundColor ?? "#ffffff"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: settings?.borderColor ?? "#d0d5dd"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .overlay(Divider(), alignment: .top)
        }
    }
}
