import SwiftUI

/// Inline consent view for embedding within a parent container.
/// Does not present as a modal — renders directly in the view hierarchy.
/// Auto-submits consent when all required elements are checked and a token is provided.
///
/// Port of the React Native `RedactoNoticeConsentInline` component.
public struct RedactoNoticeConsentInline: View {
    @StateObject private var viewModel: ConsentInlineViewModel

    public init(
        orgUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        accessToken: String? = nil,
        baseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        onAccept: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onValidationChange: ((Bool) -> Void)? = nil,
        applicationId: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ConsentInlineViewModel(
            orgUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            accessToken: accessToken,
            baseUrl: baseUrl,
            language: language,
            onAccept: onAccept,
            onDecline: onDecline,
            onError: onError,
            onValidationChange: onValidationChange,
            settings: settings,
            applicationId: applicationId
        ))
    }

    public var body: some View {
        Group {
            if viewModel.hasAlreadyConsented || viewModel.fetchError != nil {
                EmptyView()
            } else if viewModel.isLoading {
                LoadingView()
            } else if viewModel.activeConfig == nil {
                EmptyView()
            } else {
                inlineContent
            }
        }
        .onAppear {
            viewModel.fetchNotice()
        }
    }

    // MARK: - Inline Content

    @ViewBuilder
    private var inlineContent: some View {
        VStack(spacing: 16) {
            // Error message
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.errorMessage = nil
                }
            }

            // Language selector
            if !viewModel.supportedLanguages.isEmpty {
                HStack {
                    Spacer()
                    LanguageSelectorView(
                        languages: viewModel.supportedLanguages,
                        selectedLanguage: $viewModel.selectedLanguage,
                        isDropdownOpen: $viewModel.isLanguageDropdownOpen,
                        settings: viewModel.settings
                    )
                }
                .zIndex(1)
            }

            // Purposes
            if let ac = viewModel.activeConfig {
                ForEach(ac.purposes, id: \.uuid) { purpose in
                    VStack(spacing: 0) {
                        // Purpose row
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                viewModel.handlePurposeCollapse(purpose.uuid)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: viewModel.settings?.headingColor ?? "#323B4B"))
                                        .rotationEffect(.degrees((viewModel.collapsedPurposes[purpose.uuid] ?? true) ? 0 : 90))
                                        .frame(width: 16, height: 16)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(viewModel.getTranslatedText("purposes.name", defaultText: purpose.name, itemId: purpose.uuid))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hex: viewModel.settings?.headingColor ?? "#323B4B"))

                                        Text(viewModel.getTranslatedText("purposes.description", defaultText: purpose.description, itemId: purpose.uuid))
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: viewModel.settings?.textColor ?? "#344054"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            CheckboxView(
                                checked: viewModel.selectedPurposes[purpose.uuid] ?? false,
                                onChange: { viewModel.handlePurposeToggle(purpose.uuid) },
                                size: .large,
                                accentColor: viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"
                            )
                        }
                        .padding(.vertical, 8)

                        // Data elements
                        if !(viewModel.collapsedPurposes[purpose.uuid] ?? true) && !purpose.dataElements.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(purpose.dataElements, id: \.uuid) { dataElement in
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text(viewModel.getTranslatedText("data_elements.name", defaultText: dataElement.name, itemId: dataElement.uuid))
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: viewModel.settings?.textColor ?? "#344054"))

                                            if dataElement.required {
                                                Text("*")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.red)
                                            }
                                        }

                                        Spacer()

                                        CheckboxView(
                                            checked: viewModel.selectedDataElements["\(purpose.uuid)-\(dataElement.uuid)"] ?? false,
                                            onChange: { viewModel.handleDataElementToggle(dataElement.uuid, purposeUuid: purpose.uuid) },
                                            size: .small,
                                            accentColor: viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"
                                        )
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.leading, 24)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
}
