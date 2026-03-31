import SwiftUI

/// Modal consent view for the Redacto Consent SDK.
/// Present this as a `.sheet` or `.fullScreenCover` to collect user consent.
///
/// Port of the React Native `RedactoNoticeConsent` component.
public struct RedactoNoticeConsent: View {
    @StateObject private var viewModel: ConsentNoticeViewModel

    public init(
        noticeId: String,
        accessToken: String,
        refreshToken: String,
        baseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        blockUI: Bool = true,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void,
        onError: ((Error) -> Void)? = nil,
        applicationId: String? = nil,
        validateAgainst: ValidateAgainst = .all,
        includeFullyConsentedData: Bool = false,
        reviewModeButtonText: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ConsentNoticeViewModel(
            noticeId: noticeId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            baseUrl: baseUrl,
            settings: settings,
            language: language,
            blockUI: blockUI,
            onAccept: onAccept,
            onDecline: onDecline,
            onError: onError,
            applicationId: applicationId,
            validateAgainst: validateAgainst.rawValue,
            includeFullyConsentedData: includeFullyConsentedData,
            reviewModeButtonText: reviewModeButtonText
        ))
    }

    public var body: some View {
        ZStack {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.showAgeVerification {
                AgeVerificationView(
                    onYes: viewModel.handleAgeVerificationYes,
                    onNo: viewModel.handleAgeVerificationNo,
                    onClose: viewModel.handleDecline,
                    settings: viewModel.settings,
                    primaryColor: viewModel.activeConfig?.primaryColor,
                    logoUrl: viewModel.logoUrl
                )
            } else if viewModel.showGuardianForm {
                GuardianFormView(viewModel: viewModel)
            } else if viewModel.showVerificationScreen {
                VerificationScreenView(viewModel: viewModel)
            } else {
                consentContentView
            }
        }
        .background(Color(hex: viewModel.settings?.backgroundColor ?? "#ffffff"))
        .cornerRadius(
            CGFloat(Int(viewModel.settings?.borderRadius ?? "8") ?? 8)
        )
        .onAppear {
            viewModel.fetchContent()
        }
        .onChange(of: viewModel.selectedLanguage) { _ in
            viewModel.onLanguageChanged()
        }
    }

    private func isHighlighted(_ segmentKey: String) -> Bool {
        viewModel.activeTTSSegmentKey == segmentKey
    }

    private var headingColor: Color {
        Color(hex: viewModel.settings?.headingColor ?? "#323B4B")
    }

    private var textColor: Color {
        Color(hex: viewModel.settings?.textColor ?? "#344054")
    }

    private var linkColor: Color {
        Color(hex: viewModel.settings?.link ?? viewModel.activeConfig?.secondaryColor ?? "#4f87ff")
    }

    private func scrollTargetId(for segmentKey: String) -> String {
        switch segmentKey {
        case "privacy_policy_prefix_text":
            return "privacy_policy_anchor_text"
        case "additional_text":
            return "privacy_center_anchor_text"
        case "dpo_grievance_anchor_text":
            return "dpo_grievance_text"
        case "dpo_grievance_email":
            return "dpo_grievance_text"
        case "dpo_dp_board_anchor_text":
            return "dpo_dp_board_text"
        case "dpo_dpo_anchor_text":
            return "dpo_dpo_text"
        default:
            return segmentKey
        }
    }

    private func privacyCenterFooterText(additionalText: String, anchorText: String, urlString: String) -> AttributedString {
        var result = AttributedString()

        if !additionalText.isEmpty {
            result.append(AttributedString(additionalText))
            result.append(AttributedString(" "))
        }

        var anchor = AttributedString(anchorText)
        if let url = URL(string: urlString) {
            anchor.link = url
        }
        result.append(anchor)
        result.append(AttributedString("."))

        return result
    }

    // MARK: - Main Consent Content

    @ViewBuilder
    private var consentContentView: some View {
        VStack(spacing: 0) {
            // Error banner
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.errorMessage = nil
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Top section: logo + title + language + TTS
            topSection

            // Middle: scrollable consent content
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 0) {
                            if !viewModel.translatedNoticeText.isEmpty {
                                Text(viewModel.translatedNoticeText)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(textColor)
                                    .ttsSegmentHighlighted(isHighlighted("notice_text"))
                                    .id("notice_text")
                            }

                            if let ac = viewModel.activeConfig, !ac.privacyPolicyUrl.isEmpty {
                                HStack(spacing: 0) {
                                    Text(viewModel.getTranslatedText("privacy_policy_prefix_text", defaultText: ac.privacyPolicyPrefixText) + " ")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(textColor)
                                    Button {
                                        if let url = URL(string: ac.privacyPolicyUrl) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Text(viewModel.getTranslatedText("privacy_policy_anchor_text", defaultText: ac.privacyPolicyAnchorText))
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(linkColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .ttsSegmentHighlighted(isHighlighted("privacy_policy_prefix_text") || isHighlighted("privacy_policy_anchor_text"))
                                .id("privacy_policy_anchor_text")
                            }
                        }

                        if let ac = viewModel.activeConfig, !ac.purposes.isEmpty {
                            Text(viewModel.getTranslatedText("purpose_section_heading", defaultText: ac.purposeSectionHeading))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(headingColor)
                                .ttsSegmentHighlighted(isHighlighted("purpose_section_heading"))
                                .id("purpose_section_heading")
                        }

                        if let ac = viewModel.activeConfig {
                            VStack(spacing: 10) {
                                ForEach(ac.purposes, id: \.uuid) { purpose in
                                    let purposeSelection = viewModel.content?.detail.purposeSelections?[purpose.uuid]
                                    let isAlreadyConsented = !viewModel.isReconsentMode
                                        && (purposeSelection?.selected ?? false)
                                        && !(purposeSelection?.needsReconsent ?? false)

                                    PurposeItemView(
                                        purpose: purpose,
                                        selectedPurposes: viewModel.selectedPurposes,
                                        collapsedPurposes: viewModel.collapsedPurposes,
                                        selectedDataElements: viewModel.selectedDataElements,
                                        settings: viewModel.settings,
                                        primaryColor: viewModel.activeConfig?.primaryColor,
                                        onPurposeToggle: viewModel.handlePurposeToggle,
                                        onPurposeCollapse: viewModel.handlePurposeCollapse,
                                        onDataElementToggle: viewModel.handleDataElementToggle,
                                        getTranslatedText: viewModel.getTranslatedText,
                                        isAlreadyConsented: isAlreadyConsented,
                                        initialDataElementSelections: viewModel.initialDataElementSelections,
                                        activeTTSSegmentKey: viewModel.activeTTSSegmentKey
                                    )
                                    .id("\(purpose.uuid)-\(viewModel.selectedLanguage)")
                                }
                            }
                        }

                        if let ac = viewModel.activeConfig, (!ac.privacyCenterUrl.isEmpty || ac.dpoInfo != nil) {
                            VStack(alignment: .leading, spacing: 0) {
                                if !ac.privacyCenterUrl.isEmpty {
                                    Text(privacyCenterFooterText(
                                        additionalText: viewModel.translatedAdditionalText,
                                        anchorText: viewModel.getTranslatedText(
                                            "privacy_center_anchor_text",
                                            defaultText: ac.privacyCenterAnchorText ?? "Privacy Center"
                                        ),
                                        urlString: ac.privacyCenterUrl
                                    ))
                                    .foregroundColor(textColor)
                                    .tint(linkColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .ttsSegmentHighlighted(isHighlighted("additional_text") || isHighlighted("privacy_center_anchor_text"))
                                    .id("privacy_center_anchor_text")
                                }

                                if let dpoInfo = ac.dpoInfo {
                                    DpoInfoView(
                                        dpoInfo: dpoInfo,
                                        settings: viewModel.settings,
                                        getTranslatedDpoText: viewModel.getTranslatedDpoText,
                                        activeTTSSegmentKey: viewModel.activeTTSSegmentKey,
                                        linkColor: linkColor
                                    )
                                    .id("dpo-\(viewModel.selectedLanguage)")
                                }
                            }
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(textColor)
                            .opacity(0.6)
                            .padding(.top, 8)
                            .overlay(
                                Rectangle()
                                    .fill(Color(red: 152 / 255, green: 162 / 255, blue: 179 / 255).opacity(0.3))
                                    .frame(height: 1),
                                alignment: .top
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .onChange(of: viewModel.activeTTSSegmentKey) { segmentKey in
                    guard let segmentKey else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(scrollTargetId(for: segmentKey), anchor: .center)
                    }
                }
            }

            // Bottom: action buttons
            bottomSection
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack {
            HStack(spacing: 10) {
                if let logoUrl = viewModel.logoUrl {
                    RemoteLogoView(url: logoUrl, size: 32)
                }

                Text(viewModel.getTranslatedText(
                    "notice_banner_heading",
                    defaultText: viewModel.activeConfig?.noticeBannerHeading ?? "Privacy Notice"
                ))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(headingColor)
                .lineLimit(2)
                .ttsSegmentHighlighted(isHighlighted("notice_banner_heading"))
                .id("notice_banner_heading")
            }

            Spacer()

            HStack(spacing: 8) {
                // TTS button
                if viewModel.isTTSAvailable {
                    Button {
                        viewModel.toggleAudio()
                    } label: {
                        Image(systemName: viewModel.isPlaying && !viewModel.isPaused ? "pause.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: viewModel.settings?.button?.language?.textColor ?? "#344054"))
                            .padding(6)
                            .background(Color(hex: viewModel.settings?.button?.language?.backgroundColor ?? "#f2f4f7"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Language selector
                if !viewModel.supportedLanguages.isEmpty {
                    LanguageSelectorView(
                        languages: viewModel.supportedLanguages,
                        selectedLanguage: $viewModel.selectedLanguage,
                        isDropdownOpen: $viewModel.isLanguageDropdownOpen,
                        settings: viewModel.settings
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .zIndex(1)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 10) {
            if viewModel.isReviewMode {
                Button {
                    viewModel.isReviewMode = false
                } label: {
                    Text(viewModel.reviewModeButtonText ?? "Update Consent")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                // Accept button
                Button {
                    viewModel.handleAccept()
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff")))
                        } else {
                            Text(viewModel.getTranslatedText(
                                "confirm_button_text",
                                defaultText: viewModel.activeConfig?.confirmButtonText ?? "Accept"
                            ))
                        }
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: viewModel.settings?.button?.accept?.textColor ?? "#ffffff"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(hex: viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"))
                    .cornerRadius(8)
                    .opacity(viewModel.acceptDisabled ? 0.5 : 1)
                }
                .ttsSegmentHighlighted(isHighlighted("confirm_button_text"), buttonStyle: true)
                .id("confirm_button_text")
                .disabled(viewModel.acceptDisabled)
                .buttonStyle(.plain)

                // Decline button — always shown (matching React SDK)
                Button {
                    viewModel.handleDecline()
                } label: {
                    Text(viewModel.getTranslatedText(
                        "decline_button_text",
                        defaultText: viewModel.activeConfig?.declineButtonText ?? "Decline"
                    ))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: viewModel.settings?.button?.decline?.textColor ?? "#000000"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(hex: viewModel.settings?.button?.decline?.backgroundColor ?? "#ffffff"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: viewModel.settings?.borderColor ?? "#d0d5dd"), lineWidth: 1)
                    )
                    .opacity(viewModel.isSubmitting ? 0.5 : 1)
                }
                .ttsSegmentHighlighted(isHighlighted("decline_button_text"), buttonStyle: true)
                .id("decline_button_text")
                .disabled(viewModel.isSubmitting)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 16)
    }
}

/// Validation mode for consent checking.
public enum ValidateAgainst: String {
    case all
    case required
}
