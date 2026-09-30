import SwiftUI

/// Verification status screen shown during guardian DigiLocker verification.
/// Port of the VerificationScreen component from RedactoNoticeConsent.tsx.
struct VerificationScreenView: View {
    @ObservedObject var viewModel: ConsentNoticeViewModel

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    private var succeeded: Bool {
        viewModel.isVerificationComplete && viewModel.verificationError == nil
    }

    private var pending: Bool {
        (viewModel.isInitiatingVerification || viewModel.isPollingStatus) && viewModel.verificationError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            FittedScrollView {
                centerContent
                    .frame(maxWidth: .infinity)
            }
            if !viewModel.isAutoTransitioning {
                bottomSection
            }
        }
    }

    private var topSection: some View {
        HStack(spacing: 10) {
            if let logoUrl = viewModel.logoUrl {
                RemoteLogoView(
                    url: logoUrl,
                    size: theme.appearance.logoHeight(isPhone: theme.isPhone),
                    maxWidth: theme.appearance.logoMaxWidth(isPhone: theme.isPhone)
                )
            }
            Text(GuardianCopy.title)
                .noticeFont(size: 16, weight: .semibold)
                .foregroundColor(theme.heading)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 15)
    }

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 0) {
            if succeeded {
                ZStack {
                    Circle().fill(Color(hex: "#D1FAE5")).frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(Color(hex: "#059669"))
                }
                Text(GuardianCopy.completed)
                    .noticeFont(size: 16, weight: .semibold)
                    .foregroundColor(theme.heading)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            } else if pending {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.checkboxOn))
                    .scaleEffect(1.6)
                    .padding(.vertical, 32)
                Text(viewModel.isInitiatingVerification ? GuardianCopy.opening : GuardianCopy.waiting)
                    .noticeFont(size: 14)
                    .foregroundColor(Color(hex: "#059669"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#D1FAE5"))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#A7F3D0"), lineWidth: 1))
                    .padding(.top, 16)
            }

            if let error = viewModel.verificationError {
                ZStack {
                    Circle().fill(Color(hex: "#fee2e2")).frame(width: 64, height: 64)
                    Image(systemName: "xmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(Color(hex: "#dc2626"))
                }
                .padding(.vertical, 24)
                Text(GuardianCopy.failed)
                    .noticeFont(size: 14)
                    .foregroundColor(theme.text)
                    .padding(.bottom, 12)
                Text(error)
                    .noticeFont(size: 14)
                    .foregroundColor(Color(hex: "#DC2626"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#FEF2F2"))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#FCA5A5"), lineWidth: 1))
                    .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var bottomSection: some View {
        Group {
            if succeeded {
                NoticeActionButton(title: GuardianCopy.continueLabel, paint: theme.acceptAll, theme: theme) {
                    viewModel.handleVerificationContinue()
                }
                .accessibilityLabel("Continue to consent form")
            } else if viewModel.verificationError != nil && viewModel.canRetryVerification {
                let underage = viewModel.verificationErrorCode == "GUARDIAN_UNDER_18"
                NoticeActionButton(
                    title: underage ? GuardianCopy.changeGuardian : GuardianCopy.tryAgain,
                    paint: theme.acceptAll,
                    theme: theme
                ) {
                    viewModel.handleBackToGuardianForm(clearName: underage)
                }
                .accessibilityLabel(underage ? "Change guardian details" : "Try verification again")
            } else if viewModel.verificationError != nil {
                NoticeActionButton(title: GuardianCopy.goBack, paint: theme.decline, theme: theme) {
                    viewModel.handleBackToGuardianForm()
                }
                .accessibilityLabel("Go back")
            } else {
                NoticeActionButton(title: GuardianCopy.cancel, paint: theme.decline, theme: theme) {
                    viewModel.handleBackToGuardianForm()
                }
                .accessibilityLabel("Cancel verification")
            }
        }
        .padding(.top, 12)
    }
}
