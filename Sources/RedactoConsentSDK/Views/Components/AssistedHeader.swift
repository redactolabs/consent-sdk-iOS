import SwiftUI

/// Logo, title, the talkback speaker and the language pill (React tsx ~1503-1697).
struct AssistedHeader: View {
    @ObservedObject var viewModel: AssistedNoticeViewModel
    let config: ActiveConfig
    let theme: AssistedTheme

    private var ts: AssistedI18n { viewModel.ts }

    private var title: String {
        viewModel.getTranslatedText(
            "notice_banner_heading",
            defaultText: config.noticeBannerHeading.isEmpty ? AssistedDefaults.noticeHeading : config.noticeBannerHeading
        )
    }

    private var logoPosition: LogoPosition {
        NoticeLayout.resolveLogoPosition(config.logoPosition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if logoPosition != .left, let logo {
                logo
                    .frame(maxWidth: .infinity, alignment: NoticeLayout.alignment(for: logoPosition))
            }

            if theme.isMobile {
                HStack(spacing: 10) {
                    if logoPosition == .left { logo }
                    Spacer(minLength: 0)
                    controls
                }
                titleText
            } else {
                HStack(alignment: .top, spacing: 10) {
                    HStack(spacing: 10) {
                        if logoPosition == .left { logo }
                        titleText
                    }
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
    }

    private var logo: AnyView? {
        guard !config.logoUrl.isEmpty,
              let url = URL(string: config.logoUrl)
                ?? config.logoUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
        else { return nil }
        return AnyView(
            RemoteLogoView(url: url, size: theme.isMobile ? 28 : 32)
                .accessibilityLabel(ts(.logoAlt))
        )
    }

    private var titleText: some View {
        let highlighted = viewModel.isHighlighted(AssistedElementId.title)
        return Text(title)
            .noticeFont(size: theme.titleSize, weight: .bold)
            .foregroundColor(highlighted ? (theme.highlightText ?? theme.heading) : theme.heading)
            .modifier(PairHighlight(isOn: highlighted, background: theme.highlightBackground))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .id(AssistedElementId.title)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if viewModel.showsSpeaker {
                Button {
                    viewModel.toggleAudio()
                } label: {
                    Image(systemName: viewModel.isNarrating ? "pause.fill" : "speaker.wave.2")
                        .font(.system(size: 13, weight: .medium))
                        .frame(height: 16)
                        .modifier(AssistedPill(theme: theme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isNarrating ? ts(.audioPause) : ts(.audioStart))
                .accessibilityHint(viewModel.isNarrating ? ts(.talkbackPause) : ts(.talkbackStart))
            }

            Menu {
                ForEach(viewModel.supportedLanguages, id: \.self) { language in
                    Button {
                        viewModel.selectLanguage(language)
                    } label: {
                        if language == viewModel.selectedLanguage {
                            Label(NoticeLanguageCodes.nativeLabel(language), systemImage: "checkmark")
                        } else {
                            Text(NoticeLanguageCodes.nativeLabel(language))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(NoticeLanguageCodes.nativeLabel(viewModel.selectedLanguage))
                        .noticeFont(size: theme.pillSize)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .modifier(AssistedPill(theme: theme))
            }
            .accessibilityLabel(ts(.selectLanguageCurrent, ["lang": NoticeLanguageCodes.nativeLabel(viewModel.selectedLanguage)]))
        }
        .fixedSize()
    }
}

/// The header pill the speaker and the language selector share.
private struct AssistedPill: ViewModifier {
    let theme: AssistedTheme

    func body(content: Content) -> some View {
        content
            .foregroundColor(Color(hex: "#344054"))
            .padding(.horizontal, theme.isMobile ? 6 : 9)
            .padding(.vertical, 3)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
    }
}
