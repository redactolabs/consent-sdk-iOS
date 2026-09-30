import SwiftUI

private struct NoticeBodyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Modal consent view for the Redacto Consent SDK.
///
/// Draws the notice the way the React SDK's `RedactoNoticeConsent` does: a
/// card over the host's screen (dimmed while `blockUI`), placed, styled and
/// sized by the appearance set in the Redacto console, under any `settings`
/// the host passes. Give it the whole screen, e.g. in a `ZStack` over your
/// content or a `.fullScreenCover`.
public struct RedactoNoticeConsent: View {
    @StateObject private var viewModel: ConsentNoticeViewModel

    /// `.compact` (every iPhone in portrait) is the phone layout; `.regular`
    /// (iPad, large iPhones in landscape) the wide one.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accessToken: String
    private let otpGate: OtpGate?
    private let settings: ConsentSettings?
    private let blockUI: Bool
    private let identity: NoticeIdentity

    @State private var bodyHeight: CGFloat = 0
    @State private var presented = false
    @State private var hasStarted = false

    public init(
        noticeId: String,
        accessToken: String = "",
        refreshToken: String = "",
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        blockUI: Bool = true,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void,
        onError: ((Error) -> Void)? = nil,
        applicationId: String? = nil,
        validateAgainst: ValidateAgainst = .all,
        includeFullyConsentedData: Bool = false,
        reviewModeButtonText: String? = nil,
        // Sandbox mode (additive): a non-empty `sandboxToken` switches the SDK to
        // the consent-server test path (X-Consent-Token header, no JWT). The acting
        // identity is a UCIC (`org_user_id`), else email (`primary_email`), else
        // mobile (`primary_mobile`); org/workspace come from these UUIDs, not the JWT.
        sandboxToken: String? = nil,
        email: String? = nil,
        mobile: String? = nil,
        ucic: String? = nil,
        organisationUuid: String? = nil,
        workspaceUuid: String? = nil,
        defaultOpenProducts: [String]? = nil,
        otpGate: OtpGate? = nil
    ) {
        self.accessToken = accessToken
        self.otpGate = otpGate
        self.settings = settings
        self.blockUI = blockUI
        let sandboxInputs = NoticeSandboxInputs(
            token: sandboxToken,
            email: email,
            mobile: mobile,
            ucic: ucic,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid
        )
        self.identity = NoticeIdentity(
            noticeId: noticeId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            language: language,
            applicationId: applicationId,
            ledgerBaseUrl: ledgerBaseUrl,
            validateAgainst: validateAgainst.rawValue,
            includeFullyConsentedData: includeFullyConsentedData,
            sandbox: sandboxInputs
        )
        // Resolve the sandbox config here but never call `onError` synchronously
        // during view construction: capture any resolve failure and let the view
        // model surface it once from the load path (see performFetch).
        let resolved = sandboxInputs.resolve()
        _viewModel = StateObject(wrappedValue: ConsentNoticeViewModel(
            noticeId: noticeId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            sandbox: resolved.config,
            sandboxConfigError: resolved.error,
            settings: settings,
            language: language,
            blockUI: blockUI,
            onAccept: onAccept,
            onDecline: onDecline,
            onError: onError,
            applicationId: applicationId,
            validateAgainst: validateAgainst.rawValue,
            includeFullyConsentedData: includeFullyConsentedData,
            reviewModeButtonText: reviewModeButtonText,
            defaultOpenProducts: defaultOpenProducts,
            otpGate: otpGate
        ))
    }

    private var isPhone: Bool { horizontalSizeClass != .regular }

    /// Read from this render's `settings`, so a host that restyles a mounted
    /// notice sees it repaint.
    private var theme: NoticeTheme {
        NoticeTheme(
            appearance: NoticeAppearance.resolve(
                console: viewModel.servedAppearance,
                settings: settings,
                colorScheme: colorScheme
            ),
            primaryColor: viewModel.activeConfig?.primaryColor,
            secondaryColor: viewModel.activeConfig?.secondaryColor,
            isPhone: isPhone,
            hasContent: viewModel.content != nil
        )
    }

    private var motionEnabled: Bool {
        NoticeMotion.isEnabled(theme.layout, reduceMotion: reduceMotion)
    }

    public var body: some View {
        let theme = theme
        Group {
            if viewModel.hasAlreadyConsented {
                EmptyView()
            } else {
                chrome(theme)
            }
        }
        .onAppear {
            if !hasStarted {
                hasStarted = true
                viewModel.fetchContent()
            }
            withAnimation(NoticeMotion.animation(theme.layout.isDocked(isPhone: isPhone) ? NoticeMotion.sheet : NoticeMotion.dim, enabled: motionEnabled)) {
                presented = true
            }
        }
        .onChange(of: viewModel.selectedLanguage) { _ in
            viewModel.onLanguageChanged()
        }
        .onChange(of: otpGate?.required) { _ in
            viewModel.otpGate = otpGate
        }
        .onChange(of: identity) { identity in
            viewModel.otpGate = otpGate
            viewModel.updateIdentity(identity)
        }
        .environment(\.noticeFontFamily, viewModel.noticeFontFamily)
        .environment(\.noticeTheme, theme)
        .environment(\.noticeTextScale, theme.appearance.textScaleFactor)
        .noticeConfirmDialog(
            action: viewModel.pendingConfirmAction,
            onConfirm: viewModel.confirmPendingAction,
            onCancel: viewModel.dismissConfirm
        )
    }

    // MARK: - Chrome

    private func chrome(_ theme: NoticeTheme) -> some View {
        GeometryReader { geo in
            let placement = NoticePlacement.resolve(
                layout: theme.layout,
                isPhone: isPhone,
                isGlass: theme.isGlass,
                containerWidth: geo.size.width,
                desktopWidth: theme.desktopWidth
            )
            ZStack(alignment: placement.alignment) {
                if blockUI {
                    (theme.overlay ?? Color.clear)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .opacity(presented ? 1 : 0)
                        .accessibilityHidden(true)
                }
                if viewModel.isLoading && theme.appearance.style.layout.loaderPill && theme.isGlass {
                    NoticeLoaderPill(theme: theme)
                        .padding(.bottom, isPhone ? 28 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isPhone ? .bottom : .center)
                } else {
                    card(theme, placement: placement, maxHeight: geo.size.height * placement.maxHeightFraction)
                        .padding(placement.edgeInset)
                        .offset(y: placement.docked && !presented ? geo.size.height : 0)
                        .opacity(placement.docked || presented ? 1 : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: placement.alignment)
        }
    }

    private func card(_ theme: NoticeTheme, placement: NoticePlacement, maxHeight: CGFloat) -> some View {
        let shape = NoticeCardShape(radius: theme.modalRadius, docked: placement.docked)
        return NoticeHeightCap(cap: maxHeight) {
            VStack(spacing: 0) {
                if placement.docked && isPhone && !viewModel.isLoading {
                    Capsule()
                        .fill(theme.grabber)
                        .frame(width: 38, height: 5)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                }
                cardContent(theme)
                    .frame(maxWidth: placement.contentMaxWidth ?? .infinity)
            }
            .frame(width: placement.width)
            .frame(maxWidth: placement.width == nil ? .infinity : nil)
        }
        .background(theme.cardBackground.clipShape(shape).ignoresSafeArea(edges: placement.docked ? .bottom : []))
        .overlay(shape.stroke(theme.cardEdge ?? .clear, lineWidth: 1))
        .clipShape(shape)
        .noticeShadow(theme.cardShadow(docked: placement.docked))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func gutter(_ theme: NoticeTheme) -> CGFloat {
        if theme.isGlass { return isPhone ? 16 : 24 }
        return isPhone ? 20 : 22
    }

    @ViewBuilder
    private func cardContent(_ theme: NoticeTheme) -> some View {
        let gutter = gutter(theme)
        if let configurationError = viewModel.configurationErrorMessage {
            NoticeConfigurationErrorView(message: configurationError)
                .padding(gutter)
        } else if viewModel.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#3498db")))
                    .scaleEffect(1.4)
                Text(NoticeCopy.loading)
                    .noticeFont(size: theme.size(.privacyText))
                    .foregroundColor(theme.text)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(gutter)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading consent notice")
        } else if let fetchError = viewModel.fetchErrorMessage {
            NoticeErrorDialogView(
                message: fetchError,
                isPhone: isPhone,
                onRetry: { viewModel.fetchContent() },
                onClose: viewModel.handleDecline
            )
        } else if viewModel.showAgeVerification {
            AgeVerificationView(
                onYes: viewModel.handleAgeVerificationYes,
                onNo: viewModel.handleAgeVerificationNo,
                onClose: viewModel.handleDecline,
                settings: viewModel.settings,
                primaryColor: viewModel.activeConfig?.primaryColor,
                logoUrl: viewModel.logoUrl
            )
            .padding(gutter)
        } else if viewModel.showGuardianForm {
            GuardianFormView(viewModel: viewModel)
                .padding(gutter)
        } else if viewModel.showVerificationScreen {
            VerificationScreenView(viewModel: viewModel)
                .padding(gutter)
        } else {
            consentContentView(theme, gutter: gutter)
        }
    }

    private func isHighlighted(_ segmentKey: String) -> Bool {
        viewModel.activeTTSSegmentKey == segmentKey
    }

    private func scrollTargetId(for segmentKey: String) -> String {
        switch segmentKey {
        case "privacy_policy_prefix_text":
            return "privacy_policy_anchor_text"
        case "additional_text":
            return "privacy_center_anchor_text"
        case "dpo_grievance_anchor_text", "dpo_grievance_email", "dpo_grievance_email_connector_text":
            return "dpo_grievance_text"
        case "dpo_dp_board_anchor_text":
            return "dpo_dp_board_text"
        case "dpo_dpo_anchor_text":
            return "dpo_dpo_text"
        default:
            return segmentKey
        }
    }

    // MARK: - Main Consent Content

    private func consentContentView(_ theme: NoticeTheme, gutter: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.errorMessage = nil
                }
                .padding(.horizontal, gutter)
                .padding(.top, isPhone ? 12 : 16)
            }

            header(theme)
                .padding(.horizontal, gutter)
                .padding(.top, theme.isGlass ? (isPhone ? 12 : 22) : gutter)
                .padding(.bottom, theme.isGlass ? (isPhone ? 12 : 14) : 15)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    noticeBody(theme)
                        .padding(.horizontal, gutter)
                        .padding(.top, theme.isGlass ? 4 : 0)
                        .padding(.bottom, theme.isGlass ? (isPhone ? 14 : 18) : 4)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: NoticeBodyHeightKey.self, value: geo.size.height)
                        })
                }
                .frame(maxHeight: bodyHeight > 0 ? bodyHeight : nil)
                .onPreferenceChange(NoticeBodyHeightKey.self) { bodyHeight = $0 }
                .onChange(of: viewModel.activeTTSSegmentKey) { segmentKey in
                    guard let segmentKey else { return }
                    withAnimation(NoticeMotion.animation(.easeInOut(duration: 0.25), enabled: motionEnabled)) {
                        proxy.scrollTo(scrollTargetId(for: segmentKey), anchor: .center)
                    }
                }
            }

            footerBand(theme, gutter: gutter)
        }
    }

    // MARK: - Header

    private func header(_ theme: NoticeTheme) -> some View {
        VStack(spacing: theme.isGlass ? 12 : (isPhone ? 12 : 10)) {
            if let logoUrl = viewModel.logoUrl {
                NoticeLogoRow(
                    url: logoUrl,
                    position: viewModel.logoPosition,
                    height: theme.appearance.logoHeight(isPhone: isPhone),
                    maxWidth: theme.appearance.logoMaxWidth(isPhone: isPhone)
                )
            }
            HStack(alignment: .center, spacing: 10) {
                let titleHighlighted = isHighlighted("notice_banner_heading")
                Text(viewModel.getTranslatedText(
                    "notice_banner_heading",
                    defaultText: viewModel.activeConfig?.noticeBannerHeading.nonEmpty ?? NoticeCopy.bannerHeading
                ))
                .noticeFont(size: theme.size(.title), weight: theme.weight(.title))
                .foregroundColor(theme.ttsColor(theme.heading, highlighted: titleHighlighted))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .ttsSegmentHighlighted(titleHighlighted)
                .id("notice_banner_heading")
                .accessibilityAddTraits(.isHeader)

                HStack(spacing: 8) {
                    if viewModel.isTTSAvailable {
                        talkbackButton(theme)
                    }
                    if !viewModel.supportedLanguages.isEmpty {
                        LanguageSelectorView(
                            languages: viewModel.supportedLanguages,
                            selectedLanguage: $viewModel.selectedLanguage,
                            isDropdownOpen: $viewModel.isLanguageDropdownOpen,
                            settings: viewModel.settings,
                            label: NoticeLanguageCodes.nativeLabel,
                            chip: theme.chip,
                            fontSize: theme.size(.chip)
                        )
                    }
                }
                .fixedSize()
            }
        }
    }

    private func talkbackButton(_ theme: NoticeTheme) -> some View {
        let chip = theme.chip
        let playing = viewModel.isPlaying && !viewModel.isPaused
        return Button {
            viewModel.toggleAudio()
        } label: {
            Image(systemName: playing ? "pause.fill" : "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundColor(chip.foreground)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(minHeight: chip.height)
                .background(RoundedRectangle(cornerRadius: chip.radius).fill(chip.background))
                .overlay(RoundedRectangle(cornerRadius: chip.radius).stroke(chip.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? NoticeCopy.pauseTalkback : (viewModel.isPaused ? NoticeCopy.resumeTalkback : NoticeCopy.startTalkback))
    }

    // MARK: - Body

    private func noticeBody(_ theme: NoticeTheme) -> some View {
        let grouped = theme.isGlass || theme.layout.collapsibleSections
        return VStack(alignment: .leading, spacing: grouped ? 10 : 12) {
            section(.about, theme: theme, icon: "info.circle") {
                aboutParagraph(theme)
            }

            let headingHighlighted = isHighlighted("purpose_section_heading")
            Text(viewModel.getTranslatedText(
                "purpose_section_heading",
                defaultText: viewModel.activeConfig?.purposeSectionHeading.nonEmpty ?? NoticeCopy.purposeSectionHeading
            ))
            .noticeFont(size: theme.size(.subTitle), weight: theme.weight(.subTitle))
            .foregroundColor(theme.ttsColor(theme.heading, highlighted: headingHighlighted))
            .padding(.top, theme.isGlass ? 6 : 0)
            .padding(.horizontal, theme.isGlass ? 4 : 0)
            .ttsSegmentHighlighted(headingHighlighted)
            .id("purpose_section_heading")
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: grouped ? 10 : 12) {
                NoticePurposeListView(viewModel: viewModel, selectionControl: theme.appearance.effectiveSelectionControl)
                    .disabled(viewModel.otpLocked)
                    .opacity(viewModel.otpLocked ? 0.55 : 1)

                if viewModel.showsNoticeFooter {
                    section(.dpo, theme: theme, icon: "checkmark.shield") {
                        dpoBlock(theme)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Wraps a notice-body section in a disclosure when the layout collapses them.
    @ViewBuilder
    private func section<Content: View>(
        _ section: NoticeSection,
        theme: NoticeTheme,
        icon: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if theme.layout.collapsibleSections {
            let title = viewModel.sectionTitle(section)
            NoticeAccordionView(
                icon: icon,
                title: title.title.strippingHTML(),
                clampTitle: title.clamped,
                hint: title.hint?.strippingHTML(),
                open: viewModel.isSectionOpen(section),
                locked: viewModel.isTalkbackActive,
                theme: theme,
                onToggle: { viewModel.toggleSection(section) },
                content: content
            )
        } else {
            content()
        }
    }

    private func aboutParagraph(_ theme: NoticeTheme) -> some View {
        VStack(alignment: .leading, spacing: noticeLineGap(theme.size(.privacyText))) {
            let textHighlighted = isHighlighted("notice_text")
            Text(viewModel.translatedNoticeText)
                .noticeFont(size: theme.size(.privacyText))
                .foregroundColor(theme.ttsColor(theme.text, highlighted: textHighlighted))
                .fixedSize(horizontal: false, vertical: true)
                .ttsSegmentHighlighted(textHighlighted)
                .id("notice_text")

            if let ac = viewModel.activeConfig, viewModel.showsNoticePolicyLink {
                let highlighted = isHighlighted("privacy_policy_prefix_text") || isHighlighted("privacy_policy_anchor_text")
                Text(policyLine(ac))
                    .noticeFont(size: theme.size(.privacyText))
                    .foregroundColor(theme.ttsColor(theme.text, highlighted: highlighted))
                    .tint(theme.link)
                    .fixedSize(horizontal: false, vertical: true)
                    .ttsSegmentHighlighted(highlighted)
                    .id("privacy_policy_anchor_text")
            }
        }
    }

    private func policyLine(_ ac: ActiveConfig) -> AttributedString {
        var line = AttributedString(viewModel.getTranslatedText("privacy_policy_prefix_text", defaultText: ac.privacyPolicyPrefixText) + " ")
        var anchor = AttributedString(viewModel.getTranslatedText(
            "privacy_policy_anchor_text",
            defaultText: ac.privacyPolicyAnchorText.nonEmpty ?? NoticeCopy.privacyPolicyAnchor
        ))
        anchor.foregroundColor = theme.link
        if !ac.privacyPolicyUrl.isEmpty, let url = URL(string: ac.privacyPolicyUrl) {
            anchor.link = url
        }
        line.append(anchor)
        return line
    }

    private func privacyCenterLine(_ ac: ActiveConfig) -> AttributedString {
        var result = AttributedString()
        if !ac.additionalText.isEmpty {
            result.append(AttributedString(viewModel.translatedAdditionalText))
        }
        if !ac.privacyCenterUrl.isEmpty {
            result.append(AttributedString(" "))
            var anchor = AttributedString(viewModel.getTranslatedText(
                "privacy_center_anchor_text",
                defaultText: ac.privacyCenterAnchorText.flatMap { $0.isEmpty ? nil : $0 } ?? NoticeCopy.privacyCenterAnchor
            ))
            if let url = URL(string: ac.privacyCenterUrl) {
                anchor.link = url
            }
            result.append(anchor)
            result.append(AttributedString("."))
        }
        return result
    }

    private func dpoBlock(_ theme: NoticeTheme) -> some View {
        let collapsible = theme.layout.collapsibleSections
        return VStack(alignment: .leading, spacing: noticeLineGap(theme.size(.dpo))) {
            if let ac = viewModel.activeConfig {
                if viewModel.hasPrivacyCenterLine {
                    Text(privacyCenterLine(ac))
                        .tint(theme.link)
                        .fixedSize(horizontal: false, vertical: true)
                        .ttsSegmentHighlighted(isHighlighted("additional_text") || isHighlighted("privacy_center_anchor_text"))
                        .id("privacy_center_anchor_text")
                }

                if !viewModel.productPolicyLinks.isEmpty {
                    ProductPolicyLineView(
                        label: viewModel.getTranslatedText(
                            ProductPolicyCopy.translationKey,
                            defaultText: ProductPolicyCopy.label
                        ),
                        links: viewModel.productPolicyLinks,
                        linkColor: theme.link
                    )
                }

                if let dpoInfo = ac.dpoInfo {
                    DpoInfoView(
                        dpoInfo: dpoInfo,
                        settings: viewModel.settings,
                        getTranslatedDpoText: viewModel.getTranslatedDpoText,
                        activeTTSSegmentKey: viewModel.activeTTSSegmentKey,
                        linkColor: theme.link,
                        linksNeedTargets: true,
                        textColorOverride: theme.text,
                        lineGap: noticeLineGap(theme.size(.dpo))
                    )
                    .id("dpo-\(viewModel.selectedLanguage)")
                }
            }
        }
        .noticeFont(size: theme.size(.dpo))
        .foregroundColor(theme.text)
        .opacity(collapsible ? 1 : 0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, collapsible ? 0 : 12)
        .overlay(alignment: .top) {
            if !collapsible {
                Rectangle()
                    .fill(Color(red: 152 / 255, green: 162 / 255, blue: 179 / 255).opacity(0.3))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Footer

    /// The confirm hint, the OTP step and the actions. On glass they share one
    /// band pinned under the scrolling body.
    private func footerBand(_ theme: NoticeTheme, gutter: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.isReviewMode, let hint = viewModel.confirmHintText {
                ConfirmHintView(text: hint, color: theme.confirmHint, size: theme.size(.confirmHint))
                    .padding(.top, theme.isGlass ? 0 : 12)
                    .padding(.bottom, theme.isGlass ? 10 : 0)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if viewModel.otpLocked {
                otpGatePanel(theme)
            }
            Group {
                if viewModel.isReviewMode {
                    NoticeActionButton(
                        title: viewModel.reviewModeButtonText ?? NoticeCopy.reviewContinue,
                        paint: theme.acceptAll,
                        theme: theme,
                        action: viewModel.continueFromReview
                    )
                } else {
                    NoticeFooterView(
                        acceptAllLabel: viewModel.getTranslatedText(
                            "accept_all_button_text",
                            defaultText: viewModel.activeConfig?.acceptAllButtonText?.nonEmpty ?? NoticeButtonDefaults.acceptAll
                        ),
                        acceptSelectedLabel: viewModel.getTranslatedText(
                            "confirm_button_text",
                            defaultText: viewModel.activeConfig?.confirmButtonText.nonEmpty ?? NoticeButtonDefaults.acceptSelected
                        ),
                        declineLabel: viewModel.getTranslatedText(
                            "decline_button_text",
                            defaultText: viewModel.activeConfig?.declineButtonText.nonEmpty ?? NoticeButtonDefaults.decline
                        ),
                        acceptSelectedDisabled: viewModel.acceptDisabled,
                        acceptSelectedHint: viewModel.confirmHintText,
                        isSubmittingAccept: viewModel.isSubmittingAccept,
                        isSubmitting: viewModel.isSubmitting,
                        theme: theme,
                        activeTTSSegmentKey: viewModel.activeTTSSegmentKey,
                        onAcceptAll: { request(.acceptAll, theme) },
                        onAcceptSelected: { request(.acceptSelected, theme) },
                        onDecline: { request(.decline, theme) }
                    )
                }
            }
            .padding(.top, theme.isGlass ? 0 : 15)
        }
        .padding(.horizontal, gutter)
        .padding(.top, theme.isGlass ? (isPhone ? 12 : 14) : 0)
        .padding(.bottom, theme.isGlass ? (isPhone ? 16 : 22) : gutter)
        .background {
            if let glass = theme.glass {
                LinearGradient(
                    stops: [
                        .init(color: glass.footerTop.color, location: 0),
                        .init(color: glass.footerBottom.color, location: glass.footerBottomStop),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(alignment: .top) { Rectangle().fill(glass.hairline.color).frame(height: 1) }
            }
        }
    }

    private func request(_ action: ConfirmAction, _ theme: NoticeTheme) {
        viewModel.requestAction(action, confirmFirst: theme.appearance.confirmBeforeSubmit)
    }

    private func otpGatePanel(_ theme: NoticeTheme) -> some View {
        let paint = theme.acceptAll
        return OtpGatePanelView(
            title: viewModel.otpPanelTitle,
            description: viewModel.otpPanelDescription,
            submitLabel: viewModel.otpPanelSubmitLabel,
            digits: viewModel.otpPanel.digits,
            busy: viewModel.otpPanel.busy,
            error: viewModel.otpPanel.error,
            confirmEnabled: viewModel.otpConfirmEnabled,
            buttonBackground: paint.background,
            buttonTextColor: paint.foreground,
            onDigitsChange: viewModel.updateOtpDigits,
            onConfirm: { Task { await viewModel.confirmOtp() } }
        )
    }
}

/// Validation mode for consent checking.
public enum ValidateAgainst: String {
    case all
    case required
}
