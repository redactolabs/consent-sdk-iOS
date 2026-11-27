import SwiftUI

/// The top bar, laid out as the Android SDK's: the workspace logo and name,
/// then language, the notification bell and the account menu, each of the
/// last two opening a dropdown under its control. Leaving the Privacy Center
/// sits in the account menu, so there is no close control.
struct PCTopBar: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    let showsNotifications: Bool
    @ObservedObject var notifications: NotificationsViewModel
    @State private var showBellSheet = false
    @State private var openMenu: Dropdown?

    enum Dropdown {
        case language
        case account
    }

    var body: some View {
        bar
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(theme.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.background))
            .background(alignment: .top) {
                if openMenu != nil {
                    Color.black.opacity(0.001)
                        .frame(height: 4000)
                        .onTapGesture { openMenu = nil }
                        .accessibilityHidden(true)
                }
            }
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
        Button(action: {
            openMenu = nil
            store.navigate(to: store.homePage)
        }) {
            HStack(spacing: 10) {
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
            languageButton
        }
        if showsNotifications {
            bell
        }
        userMenu
    }

    /// The dropdowns open from the control's far edge, which sits inside the
    /// bar; with the controls on the leading side they open from the near edge.
    private var dropdownAlignment: Alignment {
        store.settings.branding.logoAlign == .right ? .bottomLeading : .bottomTrailing
    }

    private func toggle(_ menu: Dropdown) {
        openMenu = openMenu == menu ? nil : menu
    }

    private var languageButton: some View {
        Button(action: { toggle(.language) }) {
            PCLanguagePill(code: store.language)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.languageOptions.first { $0.code == store.language }?.label ?? store.language)
        .overlay(alignment: dropdownAlignment) {
            if openMenu == .language {
                PCLanguageDropdown(
                    selectedCode: store.language,
                    options: store.languageOptions,
                    onSelect: { code in
                        openMenu = nil
                        if code != store.language { store.chooseLanguage(code) }
                    }
                )
                .fixedSize()
                .alignmentGuide(.bottom) { $0[.top] - 4 }
                .accessibilityAction(.escape) { openMenu = nil }
            }
        }
    }

    /// The published logo height, capped at what the 56pt bar can hold.
    private var logoHeight: CGFloat {
        store.settings.branding.logoHeight.map { CGFloat(min($0, 40)) } ?? 32
    }

    @ViewBuilder
    private var brandMark: some View {
        let name = store.displayOrgName
        switch PCBrandMark.resolve(logoUrl: store.logoUrl, iconUrl: store.iconUrl) {
        case .logo(let logo):
            PCRemoteImage(url: logo) { image in
                PCCappedWidthLayout(maxWidth: 160) {
                    image.resizable().scaledToFit().frame(height: logoHeight)
                }
            } placeholder: {
                Color.clear.frame(width: logoHeight, height: logoHeight)
            }
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
            openMenu = nil
            showBellSheet = true
            Task { await notifications.loadRecent() }
        }) {
            Image(systemName: "bell")
                .font(theme.font(size: 16, weight: .regular))
                .foregroundColor(theme.text)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .background(theme.background)
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if notifications.unreadCount > 0 {
                        Text(notifications.unreadCount > 9 ? "9+" : "\(notifications.unreadCount)")
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

    /// The signed-in contact, as Android's user row shows it. With no email or
    /// mobile in the token the contact is the org_user_id, which is not shown
    /// as the person's identity.
    private var userContact: String? {
        guard let contact = store.contact.pcNonEmpty, contact != store.currentOrgUserId else { return nil }
        return contact
    }

    /// The person's initials from their contact, else the brand's initial
    /// (never the org_user_id's, which reads as "04").
    private var accountInitials: String {
        if let contact = userContact { return PCAvatar.initials(fromContact: contact) }
        let brand = String(store.displayOrgName.prefix(1)).uppercased()
        return brand.isEmpty ? "?" : brand
    }

    private var userMenu: some View {
        Button(action: { toggle(.account) }) {
            HStack(spacing: 6) {
                PCAvatar(initial: accountInitials, size: Self.controlHeight - 8, style: .solid)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .frame(height: Self.controlHeight)
            .background(theme.background)
            .overlay(Capsule().stroke(theme.border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PCStrings.accountMenu)
        .overlay(alignment: dropdownAlignment) {
            if openMenu == .account {
                PCAccountMenuCard(
                    contact: userContact,
                    initials: accountInitials,
                    onClose: { openMenu = nil }
                )
                .fixedSize()
                .alignmentGuide(.bottom) { $0[.top] - 4 }
                .accessibilityAction(.escape) { openMenu = nil }
            }
        }
    }
}

/// Android's UserMenuPopover card: a "Your Privacy Center" header over the
/// brand name, the signed-in user's row, then the actions. iOS keeps the
/// User ID line and Switch profile, as React's menu has them.
struct PCAccountMenuCard: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    let contact: String?
    let initials: String
    let onClose: () -> Void

    private static let width: CGFloat = 296

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(theme.border).frame(height: 1)
            if contact != nil || store.currentOrgUserId != nil {
                identityRow
            }
            if store.canSwitchProfile {
                actionRow(PCStrings.switchProfile, icon: "person.2") {
                    store.switchProfile()
                }
            }
            if let exit = store.exitAction {
                let signsOut = exit == .signout
                actionRow(
                    signsOut ? PCStrings.signOut : PCStrings.back,
                    icon: signsOut ? "rectangle.portrait.and.arrow.right" : "arrow.left"
                ) {
                    store.performExitAction()
                }
            }
        }
        .frame(width: Self.width)
        .pcDropdownCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PCStrings.yourPrivacyCenter.uppercased())
                .font(theme.font(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(theme.textSecondary)
            Text(store.displayOrgName.isEmpty ? "-" : store.displayOrgName)
                .font(theme.font(size: 16, weight: .semibold))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.badgeSecondaryBg, theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var identityRow: some View {
        HStack(spacing: 10) {
            PCAvatar(initial: initials, size: 28, style: .solid)
            VStack(alignment: .leading, spacing: 2) {
                if let contact {
                    Text(contact)
                        .font(theme.font(size: 13, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let id = store.currentOrgUserId {
                    Text(PCStrings.userIdLabel(id))
                        .font(theme.font(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func actionRow(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            onClose()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.text)
                    .frame(width: 16, height: 16)
                Text(label)
                    .font(theme.font(size: 14, weight: .medium))
                    .foregroundColor(theme.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

/// Offers its child at most `maxWidth` and takes the child's own size, so a
/// wide logo is capped without the slot growing to the cap (a `maxWidth`
/// frame fills it, which pushed the brand name toward the middle).
struct PCCappedWidthLayout: Layout {
    var maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let width = min(proposal.width ?? maxWidth, maxWidth)
        return child.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(bounds.size))
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
