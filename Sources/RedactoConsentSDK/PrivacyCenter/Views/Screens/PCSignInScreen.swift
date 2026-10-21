import SwiftUI

/// The built-in sign-in page (React `SignInFrame`, `ContactStep`, `OtpStep`):
/// the card, split or minimal layout the settings choose, with the brand
/// header, the language switcher and the footer around the two steps.
struct PCSignInScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var store: PrivacyCenterStore
    @StateObject private var vm: PCSignInViewModel

    init(store: PrivacyCenterStore) {
        self.store = store
        _vm = StateObject(wrappedValue: PCSignInViewModel(store: store))
    }

    private var signIn: PrivacyCenterSignInSettings { store.settings.signIn }
    private var isWide: Bool { sizeClass == .regular }
    private var centered: Bool { signIn.align == .center }
    private var alignment: HorizontalAlignment { centered ? .center : .leading }
    private var textAlignment: TextAlignment { centered ? .center : .leading }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch signIn.layout {
            case .split:
                splitLayout
            case .minimal:
                minimalLayout
            case .card:
                cardLayout
            }
            if store.showsLanguageSwitcher {
                PCLanguagePickerButton(
                    selectedCode: Binding(get: { store.language }, set: { _ in }),
                    options: store.languageOptions,
                    onSelect: { store.chooseLanguage($0) }
                )
                .padding(16)
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                PCToastView(toast: toast)
                    .padding(.top, 8)
                    .onTapGesture { store.toast = nil }
            }
        }
    }

    // MARK: - Layouts

    private var cardLayout: some View {
        ScrollView {
            VStack(spacing: isWide ? 32 : 24) {
                header(onPanel: false)
                VStack(alignment: .leading, spacing: 0) { step }
                    .padding(isWide ? EdgeInsets(top: 44, leading: 52, bottom: 44, trailing: 52) : EdgeInsets(top: 28, leading: 22, bottom: 28, trailing: 22))
                    .frame(maxWidth: 600)
                    .background(RoundedRectangle(cornerRadius: cardRadius).fill(theme.surfaceElevated))
                    .shadow(color: Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255).opacity(0.08), radius: 20, y: 16)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                PCSettingsFooter()
            }
            .padding(isWide ? EdgeInsets(top: 64, leading: 48, bottom: 32, trailing: 48) : EdgeInsets(top: 56, leading: 16, bottom: 24, trailing: 16))
        }
        .background(cardBackground.ignoresSafeArea())
    }

    private var splitLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: alignment, spacing: 28) {
                    header(onPanel: true)
                    if isWide { highlights }
                }
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .padding(isWide ? EdgeInsets(top: 48, leading: 44, bottom: 40, trailing: 44) : EdgeInsets(top: 56, leading: 20, bottom: 28, trailing: 20))
                .background(panelBackground)
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 0) { step }
                        .frame(maxWidth: 440)
                        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                    PCSettingsFooter()
                }
                .padding(isWide ? EdgeInsets(top: 64, leading: 52, bottom: 24, trailing: 52) : EdgeInsets(top: 28, leading: 20, bottom: 20, trailing: 20))
            }
        }
        .background(theme.background.ignoresSafeArea())
    }

    private var minimalLayout: some View {
        ScrollView {
            VStack(alignment: alignment, spacing: isWide ? 40 : 28) {
                header(onPanel: false)
                Rectangle().fill(theme.border).frame(height: 1)
                VStack(alignment: .leading, spacing: 0) { step }
                PCSettingsFooter()
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .padding(isWide ? EdgeInsets(top: 64, leading: 48, bottom: 28, trailing: 48) : EdgeInsets(top: 56, leading: 22, bottom: 20, trailing: 22))
        }
        .background(theme.background.ignoresSafeArea())
    }

    private var cardRadius: CGFloat {
        store.settings.branding.cornerRadius.map { min(CGFloat($0) * 2, 28) } ?? 24
    }

    /// The card layout's page: the white-to-blue gradient by default, a solid
    /// colour, or an image under a light wash.
    @ViewBuilder
    private var cardBackground: some View {
        switch signIn.backgroundType {
        case .solid:
            Color(hex: signIn.backgroundColor)
        case .image:
            if let url = signIn.backgroundImageUrl.flatMap(URL.init(string:)) {
                ZStack {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: signIn.backgroundColor)
                    }
                    Color.white.opacity(0.25)
                }
            } else {
                gradient
            }
        case .gradient:
            gradient
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [Color(hex: signIn.backgroundFrom), Color(hex: signIn.backgroundTo)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The split layout's brand panel: the primary colour, over an image when
    /// one is set.
    @ViewBuilder
    private var panelBackground: some View {
        let panel = LinearGradient(colors: [theme.primary, theme.primary.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        if signIn.backgroundType == .image, let url = signIn.backgroundImageUrl.flatMap(URL.init(string:)) {
            ZStack {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    theme.primary
                }
                panel.opacity(0.85)
            }
            .clipped()
        } else {
            panel
        }
    }

    // MARK: - Header

    private func header(onPanel: Bool) -> some View {
        let logoHeight = store.settings.branding.logoHeight.map { CGFloat($0) } ?? (isWide ? 64 : 48)
        let name = store.placeholderContext.brand
        return VStack(alignment: alignment, spacing: isWide ? 20 : 12) {
            if signIn.showLogo {
                if let logo = store.logoUrl.flatMap(URL.init(string:)) {
                    AsyncImage(url: logo) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(maxWidth: 240, maxHeight: logoHeight)
                    .accessibilityLabel(name)
                } else {
                    PCInitialsAvatar(text: PCInitialsAvatar.initials(name), seed: name, size: 48)
                }
            }
            VStack(alignment: alignment, spacing: 8) {
                Text(store.copy(signIn.title))
                    .font(theme.font(size: isWide ? 34 : 24, weight: .semibold))
                    .foregroundColor(onPanel ? theme.primaryText : theme.text)
                    .multilineTextAlignment(textAlignment)
                    .accessibilityAddTraits(.isHeader)
                let tagline = store.copy(signIn.tagline)
                if !tagline.isEmpty {
                    Text(tagline)
                        .font(theme.font(size: isWide ? 16 : 14))
                        .foregroundColor(onPanel ? theme.primaryText.opacity(0.85) : theme.textSecondary)
                        .multilineTextAlignment(textAlignment)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(signIn.highlights, id: \.self) { item in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(theme.font(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(theme.primaryText.opacity(0.16)))
                    Text(store.copy(item))
                        .font(theme.font(size: 15))
                }
                .foregroundColor(theme.primaryText)
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var step: some View {
        if vm.step == .otp, vm.sent != nil {
            otpStep
        } else {
            contactStep
        }
    }

    private func heading(_ title: String, _ description: Text?) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(theme.font(size: 24, weight: .semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(textAlignment)
                .accessibilityAddTraits(.isHeader)
            if let description {
                description
                    .font(theme.font(size: 15))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(textAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private var contactStep: some View {
        let description = store.copy(signIn.description)
        return VStack(alignment: .leading, spacing: 16) {
            heading(store.copy(signIn.heading), description.isEmpty ? nil : Text(description))
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                Text(vm.fieldLabel)
                    .font(theme.font(size: 15, weight: .semibold))
                    .foregroundColor(theme.text)
                HStack(spacing: 0) {
                    if vm.showsCountryCode {
                        Menu {
                            ForEach(PrivacyCenterSettingsLimits.countryCodes, id: \.self) { code in
                                Button(code) { vm.countryCode = code }
                            }
                        } label: {
                            Text(vm.countryCode)
                                .font(theme.font(size: 14, weight: .semibold))
                                .foregroundColor(theme.text)
                                .padding(.horizontal, 12)
                                .frame(height: 46)
                        }
                        .accessibilityLabel(PCStrings.signInCountryCode)
                        Rectangle().fill(theme.border).frame(width: 1, height: 46)
                    }
                    TextField(vm.placeholder, text: $vm.contactInput)
                        .font(theme.font(size: 15))
                        .foregroundColor(theme.text)
                        .keyboardType(signIn.channels == .sms ? .phonePad : (signIn.channels == .email ? .emailAddress : .default))
                        .textContentType(signIn.channels == .sms ? .telephoneNumber : (signIn.channels == .email ? .emailAddress : .username))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .onChange(of: vm.contactInput) { _ in vm.clearError() }
                        .onSubmit { Task { await vm.submitContact() } }
                }
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: theme.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.buttonRadius)
                        .stroke(vm.contactError == nil ? theme.border : theme.error, lineWidth: 1)
                )
                if let error = vm.contactError {
                    Text(error)
                        .font(theme.font(size: 13))
                        .foregroundColor(theme.error)
                        .accessibilityAddTraits(.updatesFrequently)
                } else if !vm.helpText.isEmpty {
                    Text(vm.helpText)
                        .font(theme.font(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            }
            if !vm.noticeLine.isEmpty {
                Text(vm.noticeLine)
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
            PCButton(
                store.copy(signIn.buttonText),
                fullWidth: true,
                isLoading: vm.busy || vm.organisationPending,
                isDisabled: vm.organisationUnavailable
            ) {
                Task { await vm.submitContact() }
            }
            if signIn.showSupportLink, let support = URL(string: "mailto:\(vm.supportEmail)") {
                HStack(spacing: 4) {
                    Text(store.copy(signIn.supportText))
                        .foregroundColor(theme.textSecondary)
                    Link(store.copy(signIn.supportLinkText), destination: support)
                        .foregroundColor(theme.link)
                }
                .font(theme.font(size: 13))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(
                store.copy(signIn.otpHeading),
                Text(vm.otpDescription + " ") + Text(vm.contactDisplay).foregroundColor(theme.link)
            )
            .onTapGesture { vm.backToContact() }
            .padding(.bottom, 6)
            HStack(spacing: 10) {
                ForEach(vm.digits.indices, id: \.self) { index in
                    OtpDigitField(
                        index: index,
                        digit: vm.digits[index],
                        enabled: !vm.busy,
                        focused: focusedDigit == index,
                        onText: { text in apply(OtpCodeEntry.applyText(vm.digits, index: index, text: text)) },
                        onBackspace: { apply(OtpCodeEntry.applyBackspace(vm.digits, index: index)) },
                        onFocus: { focusedDigit = index },
                        accessibilityText: PCStrings.otpDigitLabel(index + 1)
                    )
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(PCStrings.otpCodeLabel)
            if let error = vm.error {
                Text(error)
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.error)
            }
            PCButton(store.copy(signIn.otpButtonText), fullWidth: true, isLoading: vm.busy) {
                Task { await vm.verify() }
            }
            HStack {
                if vm.resendIn > 0 {
                    Text(PCStrings.otpResendIn(label: vm.resendLabel, seconds: vm.resendIn))
                        .foregroundColor(theme.textSecondary)
                } else {
                    Button(vm.resendLabel) {
                        focusedDigit = 0
                        Task { await vm.resend() }
                    }
                    .disabled(vm.resending)
                    .foregroundColor(theme.link)
                }
                Spacer(minLength: 12)
                Button(PCStrings.otpUseDifferentContact) { vm.backToContact() }
                    .foregroundColor(theme.link)
            }
            .font(theme.font(size: 13, weight: .medium))
            .buttonStyle(.plain)
        }
        .onChange(of: vm.error) { error in
            if error != nil { focusedDigit = 0 }
        }
    }

    @State private var focusedDigit: Int? = 0

    private func apply(_ entry: OtpEntry?) {
        guard let entry else { return }
        vm.updateDigits(entry.digits)
        if OtpCodeEntry.isComplete(entry.digits) {
            focusedDigit = nil
            return
        }
        if let focus = entry.focus {
            focusedDigit = focus
        }
    }
}
