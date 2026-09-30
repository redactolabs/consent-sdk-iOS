import SwiftUI

/// Agent-assisted consent: the public notice, verified by OTP and submitted
/// under the verified principal. Port of React's `RedactoNoticeAssisted`.
public struct RedactoNoticeAssisted: View {
    @StateObject private var viewModel: AssistedNoticeViewModel
    private let identity: AssistedNoticeIdentity

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        organisationUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        onComplete: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        identity = AssistedNoticeIdentity(
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            baseUrl: baseUrl
        )
        _viewModel = StateObject(wrappedValue: AssistedNoticeViewModel(
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            settings: settings,
            onComplete: onComplete,
            onDecline: onDecline,
            onError: onError
        ))
    }

    public var body: some View {
        let theme = AssistedTheme(
            appearance: NoticeAppearance.resolve(
                console: viewModel.activeConfig?.appearance,
                settings: viewModel.settings,
                colorScheme: colorScheme
            ),
            config: viewModel.activeConfig,
            isMobile: horizontalSizeClass == .compact
        )
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4f87ff")))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 220)
                    .accessibilityLabel(viewModel.ts(.loadingNotice))
            } else if viewModel.fetchErrorMessage == nil, let config = viewModel.activeConfig {
                noticeContent(config, theme)
            } else {
                loadFailed(theme)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .environment(\.noticeFontFamily, NoticeFontResolver.resolve(
            hostFont: viewModel.settings?.font,
            noticeFont: viewModel.activeConfig?.fontPreference,
            installed: NoticeFontResolver.installedFamily
        ))
        .onAppear {
            viewModel.loadIfNeeded()
        }
        .onChange(of: identity) { identity in
            viewModel.updateIdentity(identity)
        }
    }

    private func loadFailed(_ theme: AssistedTheme) -> some View {
        VStack(spacing: 12) {
            Text(viewModel.ts(.loadFailedTitle))
                .noticeFont(size: 16, weight: .semibold)
                .foregroundColor(Color(hex: "#101828"))

            Text(viewModel.fetchErrorMessage ?? viewModel.ts(.tryAgain))
                .noticeFont(size: 13)
                .foregroundColor(Color(hex: "#667085"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                viewModel.decline()
            } label: {
                Text(viewModel.ts(.close))
                    .noticeFont(size: theme.buttonSize)
                    .foregroundColor(.black)
                    .padding(.horizontal, theme.isMobile ? 20 : 45)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: theme.buttonRadius).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: theme.buttonRadius).stroke(Color(hex: "#d0d5dd"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 220)
    }

    private func noticeContent(_ config: ActiveConfig, _ theme: AssistedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AssistedHeader(viewModel: viewModel, config: config, theme: theme)
                .padding(.bottom, 15)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        noticeText(config, theme)

                        heading(config, theme)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.displayedPurposes, id: \.uuid) { purpose in
                                purposeRow(purpose, theme)
                            }
                        }
                        .allowsHitTesting(!viewModel.isLocked)

                        footer(config, theme)

                        if viewModel.step == .verify {
                            AssistedVerifyPanel(viewModel: viewModel, theme: theme)
                                .id(AssistedVerifyAnchor.panel)
                                .transition(.opacity)
                        }
                    }
                    .padding(.trailing, theme.isMobile ? 10 : 15)
                }
                .onChange(of: viewModel.highlightedElementId) { id in
                    guard let id, viewModel.isPlaying else { return }
                    withAnimation(motion(theme) ? .easeInOut : nil) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                .onChange(of: viewModel.step) { step in
                    guard step == .verify else { return }
                    withAnimation(motion(theme) ? .easeInOut : nil) {
                        proxy.scrollTo(AssistedVerifyAnchor.panel, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.otpSent) { sent in
                    guard sent else { return }
                    withAnimation(motion(theme) ? .easeInOut : nil) {
                        proxy.scrollTo(AssistedVerifyAnchor.panel, anchor: .bottom)
                    }
                }
            }

            AssistedActionBar(
                viewModel: viewModel,
                acceptSelectedLabel: viewModel.getTranslatedText(
                    "confirm_button_text",
                    defaultText: config.confirmButtonText.isEmpty ? NoticeButtonDefaults.acceptSelected : config.confirmButtonText
                ),
                acceptAllLabel: viewModel.getTranslatedText(
                    "accept_all_button_text",
                    defaultText: (config.acceptAllButtonText ?? "").isEmpty ? NoticeButtonDefaults.acceptAll : (config.acceptAllButtonText ?? "")
                ),
                declineLabel: viewModel.getTranslatedText(
                    "decline_button_text",
                    defaultText: config.declineButtonText.isEmpty ? NoticeButtonDefaults.decline : config.declineButtonText
                ),
                theme: theme
            )
        }
        .padding(22)
    }

    private func motion(_ theme: AssistedTheme) -> Bool {
        NoticeMotion.isEnabled(theme.appearance.layout, reduceMotion: reduceMotion)
    }

    private func noticeText(_ config: ActiveConfig, _ theme: AssistedTheme) -> some View {
        AssistedTextBlock(
            lines: AssistedFooter.noticeLines(
                config,
                showsPolicyLink: ProductPolicies.showsNoticePolicyLink(products: config.products, links: policyLinks(config)),
                translate: { viewModel.getTranslatedText($0, defaultText: $1) }
            ),
            size: theme.privacyTextSize,
            textColor: theme.text,
            linkColor: theme.link,
            highlightBackground: theme.highlightBackground,
            highlightText: theme.highlightText,
            isHighlighted: viewModel.isHighlighted
        )
        .id(AssistedElementId.noticeText)
    }

    private func heading(_ config: ActiveConfig, _ theme: AssistedTheme) -> some View {
        let highlighted = viewModel.isHighlighted(AssistedElementId.purposeSectionHeading)
        return Text(viewModel.getTranslatedText(
            "purpose_section_heading",
            defaultText: config.purposeSectionHeading.isEmpty ? AssistedDefaults.purposeSectionHeading : config.purposeSectionHeading
        ))
        .noticeFont(size: theme.subTitleSize, weight: .semibold)
        .foregroundColor(highlighted ? (theme.highlightText ?? theme.heading) : theme.heading)
        .modifier(PairHighlight(isOn: highlighted, background: theme.highlightBackground))
        .accessibilityAddTraits(.isHeader)
        .id(AssistedElementId.purposeSectionHeading)
    }

    private func purposeRow(_ purpose: ActiveConfigPurpose, _ theme: AssistedTheme) -> some View {
        PairPurposeRowView(
            purpose: purpose,
            dataElements: purpose.dataElements.filter(\.enabled),
            isCollapsed: viewModel.collapsedPurposes[purpose.uuid] ?? false,
            isSelected: viewModel.selectedPurposes[purpose.uuid] ?? false,
            isElementSelected: { viewModel.selectedDataElements[dataElementKey(purposeUuid: purpose.uuid, elementUuid: $0)] ?? false },
            translate: { viewModel.getTranslatedText($0, defaultText: $1, itemId: $2) },
            headingColor: theme.heading,
            textColor: theme.text,
            accentColor: AssistedConfig.checkboxAccent,
            locked: viewModel.isLocked,
            onToggleCollapse: { viewModel.handlePurposeCollapse(purpose.uuid) },
            onTogglePurpose: { viewModel.handlePurposeToggle(purpose.uuid) },
            onToggleElement: { viewModel.handleDataElementToggle($0, purposeUuid: purpose.uuid) },
            style: theme.rowStyle(ts: viewModel.ts, isHighlighted: viewModel.isHighlighted),
            motion: motion(theme)
        )
    }

    @ViewBuilder
    private func footer(_ config: ActiveConfig, _ theme: AssistedTheme) -> some View {
        let lines = AssistedFooter.footerLines(
            config,
            policyLinks: policyLinks(config),
            translate: { viewModel.getTranslatedText($0, defaultText: $1) },
            dpoText: { viewModel.getTranslatedDpoText($0, defaultText: $1) }
        )
        if !lines.isEmpty {
            AssistedTextBlock(
                lines: lines,
                size: theme.footerSize,
                textColor: theme.text,
                linkColor: theme.link,
                highlightBackground: theme.highlightBackground,
                highlightText: theme.highlightText,
                isHighlighted: viewModel.isHighlighted
            )
            .opacity(0.6)
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(red: 152 / 255, green: 162 / 255, blue: 179 / 255).opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.top, 12)
        }
    }

    private func policyLinks(_ config: ActiveConfig) -> [ProductPolicyLink] {
        ProductPolicies.links(products: config.products, policies: config.productPrivacyPolicies)
    }
}

private enum AssistedVerifyAnchor {
    static let panel = "redacto-assisted-verify"
}
