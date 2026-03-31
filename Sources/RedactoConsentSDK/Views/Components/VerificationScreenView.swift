import SwiftUI

/// Verification status screen shown during guardian DigiLocker verification.
/// Port of the VerificationScreen component from RedactoNoticeConsent.tsx.
struct VerificationScreenView: View {
    @ObservedObject var viewModel: ConsentNoticeViewModel

    @State private var animateIcon = false
    @State private var animateContent = false
    @State private var pulseRing = false

    private var headingColor: Color {
        Color(hex: viewModel.settings?.headingColor ?? "#323B4B")
    }

    private var textColor: Color {
        Color(hex: viewModel.settings?.textColor ?? "#344054")
    }

    private var acceptBgColor: String {
        viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            Spacer()
            centerContent
            Spacer()
            if !viewModel.isAutoTransitioning {
                bottomSection
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                animateIcon = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                animateContent = true
            }
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack {
            HStack(spacing: 8) {
                if let logoUrl = viewModel.logoUrl {
                    RemoteLogoView(url: logoUrl, size: 32)
                }

                Text("Guardian Verification")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(headingColor)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        if viewModel.isVerificationComplete && viewModel.verificationError == nil {
            successState
        } else if viewModel.verificationError != nil {
            errorState
        } else {
            pendingState
        }
    }

    private var successState: some View {
        VStack(spacing: 0) {
            // Animated checkmark with ring
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Color(hex: "#D1FAE5"), lineWidth: 3)
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulseRing ? 1.15 : 1.0)
                    .opacity(pulseRing ? 0 : 0.6)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                            pulseRing = true
                        }
                    }

                // Green circle
                Circle()
                    .fill(Color(hex: "#D1FAE5"))
                    .frame(width: 72, height: 72)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color(hex: "#059669"))
            }
            .scaleEffect(animateIcon ? 1 : 0.3)
            .opacity(animateIcon ? 1 : 0)
            .padding(.bottom, 20)

            Text("Verification Completed")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(headingColor)
                .padding(.bottom, 8)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 8)

            Text("Your guardian's identity has been successfully verified. You can now proceed.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#6B7280"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var pendingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())

            // Status message in green banner
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "#059669"))
                    .font(.system(size: 14))

                Text(viewModel.isInitiatingVerification
                    ? "Opening DigiLocker in Safari..."
                    : "Please complete the verification in Safari. This screen will update automatically when verification is complete.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#059669"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#D1FAE5"))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var errorState: some View {
        VStack(spacing: 0) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#FEE2E2"))
                    .frame(width: 72, height: 72)

                Image(systemName: "xmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color(hex: "#DC2626"))
            }
            .scaleEffect(animateIcon ? 1 : 0.3)
            .opacity(animateIcon ? 1 : 0)
            .padding(.bottom, 20)

            Text("Verification Failed")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(headingColor)
                .padding(.bottom, 8)
                .opacity(animateContent ? 1 : 0)

            if let error = viewModel.verificationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "#DC2626"))
                        .font(.system(size: 14))

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#DC2626"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FEF2F2"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FCA5A5"), lineWidth: 1)
                )
                .opacity(animateContent ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Buttons

    private var bottomSection: some View {
        VStack(spacing: 8) {
            if viewModel.isVerificationComplete && viewModel.verificationError == nil {
                // Success: "Continue" button
                Button {
                    viewModel.handleVerificationContinue()
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: acceptBgColor))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

            } else if viewModel.verificationError != nil {
                if viewModel.canRetryVerification {
                    if viewModel.verificationErrorCode == "GUARDIAN_UNDER_18" {
                        // "Change Guardian" button
                        Button {
                            viewModel.handleBackToGuardianForm(clearName: true)
                        } label: {
                            Text("Change Guardian")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: acceptBgColor))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // "Try Again" button
                        Button {
                            viewModel.handleBackToGuardianForm()
                        } label: {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: acceptBgColor))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // "Go Back" button (decline style)
                    declineStyleButton(title: "Go Back") {
                        viewModel.handleBackToGuardianForm()
                    }
                }

            } else {
                // Polling/Initiating: "Cancel" button
                declineStyleButton(title: "Cancel") {
                    viewModel.handleBackToGuardianForm()
                }
            }
        }
        .padding(20)
        .overlay(Divider(), alignment: .top)
    }

    private func declineStyleButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: viewModel.settings?.button?.decline?.textColor ?? "#000000"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: viewModel.settings?.button?.decline?.backgroundColor ?? "#ffffff"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: viewModel.settings?.borderColor ?? "#d0d5dd"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
