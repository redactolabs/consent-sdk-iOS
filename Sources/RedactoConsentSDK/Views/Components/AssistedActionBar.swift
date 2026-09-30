import SwiftUI

/// The footer buttons (React tsx ~2152-2297). On the notice step: Accept All,
/// Accept Selected and Decline; once verifying, the progressing primary button
/// and Decline.
struct AssistedActionBar: View {
    @ObservedObject var viewModel: AssistedNoticeViewModel
    let acceptSelectedLabel: String
    let acceptAllLabel: String
    let declineLabel: String
    let theme: AssistedTheme

    private var colors: NoticeAppearanceColors { theme.appearance.colors }
    private var isVerify: Bool { viewModel.step == .verify }

    var body: some View {
        Group {
            if isVerify {
                if theme.isMobile {
                    VStack(spacing: 12) {
                        primaryButton
                        declineButton
                    }
                } else {
                    HStack(spacing: 29) {
                        primaryButton
                        declineButton
                    }
                }
            } else if theme.isMobile {
                VStack(spacing: 12) {
                    acceptAllButton
                    primaryButton
                    declineButton
                }
            } else {
                HStack(spacing: 12) {
                    declineButton
                    Spacer(minLength: 0)
                    primaryButton
                    acceptAllButton
                }
            }
        }
        .padding(.top, 15)
    }

    private var ts: AssistedI18n { viewModel.ts }

    private var primaryLabel: String {
        switch viewModel.primaryAction {
        case .acceptSelected: return acceptSelectedLabel
        case .sendOtp: return viewModel.isSendingOtp ? ts(.sending) : ts(.sendOtp)
        case .confirmOtp: return viewModel.isVerifying ? ts(.verifying) : ts(.confirmOtp)
        }
    }

    private func performPrimary() {
        switch viewModel.primaryAction {
        case .acceptSelected: viewModel.acceptSelected()
        case .sendOtp: viewModel.sendOtp()
        case .confirmOtp: viewModel.confirmOtp()
        }
    }

    /// A full-width button wherever React's is `width: 100%`: the phone stack
    /// and both verify-step buttons.
    private var fills: Bool { theme.isMobile || isVerify }

    private var primaryButton: some View {
        let disabled = viewModel.isPrimaryDisabled
        let fill: Color
        let text: Color
        let edge: Color?
        if isVerify {
            fill = theme.primary
            text = .white
            edge = nil
        } else {
            let accent = AppearanceColor.color(colors[.acceptText]) ?? theme.primary
            fill = AppearanceColor.color(colors[.acceptBg]) ?? .white
            text = accent
            edge = accent
        }
        return Button(action: performPrimary) {
            label(primaryLabel)
                .foregroundColor(disabled ? Color(hex: "#98a2b3") : text)
                .modifier(AssistedButtonShape(
                    fill: disabled ? Color(hex: "#eaecf0") : fill,
                    edge: edge,
                    radius: theme.buttonRadius,
                    fills: fills,
                    isMobile: theme.isMobile
                ))
                .modifier(PairHighlight(
                    isOn: viewModel.isHighlighted(AssistedElementId.confirmButton),
                    background: theme.highlightBackground
                ))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .id(AssistedElementId.confirmButton)
    }

    private var acceptAllButton: some View {
        Button {
            viewModel.acceptAll()
        } label: {
            label(acceptAllLabel)
                .foregroundColor(AppearanceColor.color(colors[.acceptAllText]) ?? .white)
                .modifier(AssistedButtonShape(fill: theme.primary, edge: nil, radius: theme.buttonRadius, fills: fills, isMobile: theme.isMobile))
        }
        .buttonStyle(.plain)
    }

    private var declineButton: some View {
        Button {
            viewModel.decline()
        } label: {
            label(declineLabel)
                .foregroundColor(AppearanceColor.color(colors[.declineText]) ?? .black)
                .modifier(AssistedButtonShape(
                    fill: AppearanceColor.color(colors[.declineBg]) ?? .white,
                    edge: AppearanceColor.color(colors[.declineBorder]) ?? Color(hex: "#d0d5dd"),
                    radius: theme.buttonRadius,
                    fills: fills,
                    isMobile: theme.isMobile
                ))
                .modifier(PairHighlight(
                    isOn: viewModel.isHighlighted(AssistedElementId.declineButton),
                    background: theme.highlightBackground
                ))
        }
        .buttonStyle(.plain)
        .id(AssistedElementId.declineButton)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .noticeFont(size: theme.buttonSize, weight: theme.buttonWeight)
            .multilineTextAlignment(.center)
    }
}

private struct AssistedButtonShape: ViewModifier {
    let fill: Color
    let edge: Color?
    let radius: CGFloat
    let fills: Bool
    let isMobile: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isMobile ? 20 : 45)
            .padding(.vertical, isMobile ? 10 : 9)
            .frame(maxWidth: fills ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(edge ?? Color.clear, lineWidth: 1))
    }
}
