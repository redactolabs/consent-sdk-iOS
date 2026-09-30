import SwiftUI

/// The inline verify section under the locked notice (React tsx ~1935-2150):
/// contact entry, then the code boxes once the OTP is sent.
struct AssistedVerifyPanel: View {
    @ObservedObject var viewModel: AssistedNoticeViewModel
    let theme: AssistedTheme

    private let labelColor = Color(hex: "#475467")
    private let fieldText = Color(hex: "#344054")
    private let errorColor = Color(hex: "#d92d20")
    private let edge = Color(hex: "#d0d5dd")

    private var ts: AssistedI18n { viewModel.ts }
    private var isEmail: Bool { viewModel.verifyMethod == .email }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(alignment: .leading, spacing: 10) {
                labelRow
                contactField
                statusRow

                if let createError = viewModel.createError {
                    errorText(createError)
                }

                if viewModel.otpSent {
                    codeSection
                }
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 152 / 255, green: 162 / 255, blue: 179 / 255).opacity(0.3))
                .frame(height: 1)
        }
        .padding(.top, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label {
                Text(ts(.verifyWithOtp))
            } icon: {
                Image(systemName: "lock")
                    .foregroundColor(theme.primary)
            }
            .noticeFont(size: 14, weight: .semibold)
            .foregroundColor(fieldText)

            Spacer(minLength: 0)

            Button(ts(.editSelections)) {
                viewModel.editSelections()
            }
            .noticeFont(size: 13, weight: .medium)
            .foregroundColor(theme.primary)
            .disabled(viewModel.isVerifying)
        }
    }

    private var labelRow: some View {
        HStack(spacing: 10) {
            Label(isEmail ? ts(.emailAddress) : ts(.mobileNumber), systemImage: isEmail ? "envelope" : "phone")
                .noticeFont(size: 13, weight: .medium)
                .foregroundColor(labelColor)

            Spacer(minLength: 0)

            if !viewModel.otpSent {
                Button {
                    viewModel.selectMethod(isEmail ? .mobile : .email)
                } label: {
                    Label(isEmail ? ts(.useMobileInstead) : ts(.useEmailInstead), systemImage: isEmail ? "phone" : "envelope")
                        .noticeFont(size: 13, weight: .medium)
                        .foregroundColor(theme.primary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSendingOtp)
            }
        }
    }

    private var contactField: some View {
        let locked = viewModel.otpSent || viewModel.isSendingOtp
        return HStack(spacing: 0) {
            if isEmail {
                TextField(AssistedConfig.emailPlaceholder, text: Binding(get: { viewModel.email }, set: { viewModel.setEmail($0) }))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel(ts(.emailAddress))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            } else {
                Text(AssistedConfig.dialCode)
                    .noticeFont(size: 15)
                    .foregroundColor(fieldText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#f9fafb"))
                    .overlay(alignment: .trailing) { Rectangle().fill(edge).frame(width: 1) }
                TextField(AssistedConfig.mobilePlaceholder, text: Binding(get: { viewModel.mobile }, set: { viewModel.setMobile($0) }))
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .accessibilityLabel(ts(.mobileNumber))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .noticeFont(size: 15)
        .foregroundColor(fieldText)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(edge, lineWidth: 1))
        .opacity(locked ? 0.7 : 1)
        .disabled(locked)
    }

    @ViewBuilder
    private var statusRow: some View {
        if viewModel.otpSent {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))
                    Text("\(ts(.otpSentTo)) \(viewModel.otpRecipientLabel)")
                        .noticeFont(size: 13)
                        .foregroundColor(Color(hex: "#067647"))
                }

                Spacer(minLength: 0)

                Button(isEmail ? ts(.changeEmail) : ts(.changeMobile)) {
                    viewModel.changeContact()
                }
                .noticeFont(size: 13, weight: .medium)
                .foregroundColor(theme.primary)
                .disabled(viewModel.isVerifying)
            }
        } else {
            Text(isEmail ? ts(.otpHelperEmail) : ts(.otpHelper))
                .noticeFont(size: 13)
                .foregroundColor(labelColor)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .noticeFont(size: 12)
            .foregroundColor(errorColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var codeSection: some View {
        VStack(spacing: 12) {
            Text(ts(.enterNDigitOtp, ["count": AssistedConfig.otpLength]))
                .noticeFont(size: 13, weight: .medium)
                .foregroundColor(labelColor)
                .frame(maxWidth: .infinity)

            OtpCodeField(
                digits: viewModel.otpDigits,
                isDisabled: viewModel.isVerifying,
                hasError: viewModel.otpError != nil,
                onChange: { viewModel.setOtpDigits($0) },
                digitLabel: { ts(.otpDigit, ["index": $0 + 1]) },
                filledBorder: UIColor(theme.primary),
                filledBackground: UIColor(theme.primaryTint),
                groupGapBefore: 3,
                boxSize: 44
            )
            .frame(maxWidth: .infinity)

            if let otpError = viewModel.otpError {
                errorText(otpError)
            }

            Group {
                if viewModel.resendCountdown > 0 {
                    Label(ts(.resendIn, ["seconds": viewModel.resendCountdown]), systemImage: "clock")
                        .noticeFont(size: 13)
                        .foregroundColor(labelColor)
                } else {
                    Button(viewModel.isSendingOtp ? ts(.sending) : ts(.resendOtp)) {
                        viewModel.resendOtp()
                    }
                    .noticeFont(size: 13, weight: .semibold)
                    .foregroundColor(theme.primary)
                    .disabled(viewModel.isSendingOtp)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
