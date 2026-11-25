import SwiftUI

/// The top bar, laid out as the Android SDK's: the workspace logo and name,
/// then language, the notification bell and the account menu. Leaving the
/// Privacy Center sits in the account menu, so there is no close control.
struct PCTopBar: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    let showsNotifications: Bool
    @ObservedObject var notifications: NotificationsViewModel
    @State private var showBellSheet = false

    var body: some View {
        bar
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(theme.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.background))
            .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
            .sheet(isPresented: $showBellSheet) {
                NotificationDropdown(vm: notifications, onViewAll: {
                    showBellSheet = false
                    store.openNotifications()
                })
                .environmentObject(store)
                .environment(\.privacyCenterTheme, store.theme)
                .presentationDetents([.medium, .large])
            }
            .task(id: showsNotifications) {
                if showsNotifications { notifications.startBellPolling() }
            }
    }

    /// Lays the logo out where the published `logo_align` puts it, as React's
    /// TopAppBar does: leading by default, centred over the bar, or at the far
    /// edge with the actions ahead of it.
    @ViewBuilder
    private var bar: some View {
        switch store.settings.branding.logoAlign {
        case .center:
            PCCenteredLogoLayout(spacing: 8) {
                brandButton
                HStack(spacing: 8) {
                    actions
                }
            }
        case .right:
            HStack(spacing: 8) {
                pinnedActions
                Spacer(minLength: 4)
                brandButton
            }
        case .auto, .left:
            HStack(spacing: 8) {
                brandButton
                Spacer(minLength: 4)
                pinnedActions
            }
        }
    }

    /// Held at full size so a long brand name truncates instead of squeezing the controls.
    private var pinnedActions: some View {
        HStack(spacing: 8) {
            actions
        }
        .fixedSize()
    }

    private var brandButton: some View {
        Button(action: { store.navigate(to: store.homePage) }) {
            HStack(spacing: 8) {
                brandMark
                if !store.displayOrgName.isEmpty {
                    Text(store.displayOrgName)
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.displayOrgName)
    }

    @ViewBuilder
    private var actions: some View {
        if store.showsLanguageSwitcher {
            PCLanguagePickerButton(
                selectedCode: Binding(get: { store.language }, set: { _ in }),
                options: store.languageOptions,
                onSelect: { code in store.chooseLanguage(code) }
            )
        }
        if showsNotifications {
            bell
        }
        userMenu
    }

    /// The published logo height, capped at what the 56pt bar can hold.
    private var logoHeight: CGFloat {
        store.settings.branding.logoHeight.map { CGFloat(min($0, 40)) } ?? 32
    }

    private var logoFrameAlignment: Alignment {
        switch store.settings.branding.logoAlign {
        case .center: return .center
        case .right: return .trailing
        case .auto, .left: return .leading
        }
    }

    @ViewBuilder
    private var brandMark: some View {
        let name = store.displayOrgName
        switch PCBrandMark.resolve(logoUrl: store.logoUrl, iconUrl: store.iconUrl) {
        case .logo(let logo):
            PCRemoteImage(url: logo) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear.frame(width: logoHeight, height: logoHeight)
            }
            .frame(maxWidth: 160, maxHeight: logoHeight, alignment: logoFrameAlignment)
        case .icon(let icon):
            PCLogoAvatar(url: icon, name: name, size: 32)
        case .initials:
            Circle()
                .fill(theme.primarySoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(theme.font(size: 14, weight: .bold))
                        .foregroundColor(theme.primary)
                )
        }
    }

    private var bell: some View {
        Button(action: {
            showBellSheet = true
            Task { await notifications.loadRecent() }
        }) {
            Image(systemName: "bell")
                .font(theme.font(size: 15, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .background(theme.surface)
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if notifications.unreadCount > 0 {
                        Text("\(notifications.unreadCount)")
                            .font(theme.font(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(theme.error)
                            .clipShape(Capsule())
                            .offset(x: 5, y: -5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PCStrings.notifications)
    }

    /// The language pill, the bell and the account pill share one height.
    static let controlHeight: CGFloat = 36

    /// The workspace icon for the account button, as the Android SDK and
    /// React's UserMenu draw it: from the org branding, whatever the brand settings.
    private var accountIconUrl: URL? {
        store.branding?.iconUrl.pcNonEmpty.flatMap(URL.init(string:))
    }

    /// Without an icon the account button shows the brand's initial. Never the
    /// contact's: with no email or mobile in the token the contact is the
    /// org_user_id, and a UUID reads as initials like "04".
    private var accountInitial: String {
        String(store.displayOrgName.prefix(1)).uppercased()
    }

    private var userMenu: some View {
        let email = store.contact ?? ""
        return Menu {
            Section(store.displayOrgName.isEmpty ? "-" : store.displayOrgName) {
                if !email.isEmpty { Text(email) }
                if let id = store.currentOrgUserId { Text(PCStrings.userIdLabel(id)) }
            }
            if store.canSwitchProfile {
                Button {
                    store.switchProfile()
                } label: {
                    Label(PCStrings.switchProfile, systemImage: "person.2")
                }
            }
            if let exit = store.exitAction {
                let signsOut = exit == .signout
                Button {
                    store.performExitAction()
                } label: {
                    Label(
                        signsOut ? PCStrings.signOut : PCStrings.back,
                        systemImage: signsOut ? "rectangle.portrait.and.arrow.right" : "arrow.left"
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                accountAvatar
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.leading, 3)
            .padding(.trailing, 8)
            .frame(height: Self.controlHeight)
            .background(theme.surface)
            .overlay(Capsule().stroke(theme.border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .accessibilityLabel(PCStrings.accountMenu)
    }

    @ViewBuilder
    private var accountAvatar: some View {
        let side = Self.controlHeight - 8
        if let icon = accountIconUrl {
            PCLogoAvatar(url: icon, name: accountInitial, size: side)
        } else {
            Circle()
                .fill(theme.primarySoft)
                .frame(width: side, height: side)
                .overlay(
                    Text(accountInitial)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.primary)
                )
        }
    }
}

struct PCTopBarLogoSlot: Equatable {
    let x: CGFloat
    let width: CGFloat
    let centered: Bool

    static func resolve(barWidth: CGFloat, actionsWidth: CGFloat, logoWidth: CGFloat, spacing: CGFloat) -> PCTopBarLogoSlot {
        let room = barWidth - 2 * (actionsWidth + spacing)
        if logoWidth <= room {
            return PCTopBarLogoSlot(x: (barWidth - logoWidth) / 2, width: logoWidth, centered: true)
        }
        let leadingRoom = max(0, barWidth - actionsWidth - spacing)
        return PCTopBarLogoSlot(x: 0, width: min(logoWidth, leadingRoom), centered: false)
    }
}

struct PCCenteredLogoLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? sizes.map(\.width).reduce(spacing, +)
        let height = proposal.height ?? (sizes.map(\.height).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let logo = subviews[0]
        let actions = subviews[1]
        let actionsSize = actions.sizeThatFits(.unspecified)
        let slot = PCTopBarLogoSlot.resolve(
            barWidth: bounds.width,
            actionsWidth: actionsSize.width,
            logoWidth: logo.sizeThatFits(.unspecified).width,
            spacing: spacing
        )
        actions.place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(actionsSize)
        )
        logo.place(
            at: CGPoint(x: bounds.minX + slot.x, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: slot.width, height: bounds.height)
        )
    }
}
