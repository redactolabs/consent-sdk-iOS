import SwiftUI

/// The top bar (React AppShell/TopAppBar): workspace logo, language, the
/// notification bell, the account menu, and the host's close control.
struct PCTopBar: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    let showsNotifications: Bool
    @ObservedObject var notifications: NotificationsViewModel
    @State private var showBellSheet = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { store.navigate(to: .consentManager) }) {
                brandMark
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.displayOrgName)
            Spacer(minLength: 4)
            PCLanguagePickerButton(
                selectedCode: Binding(get: { store.language }, set: { _ in }),
                onSelect: { code in store.setLanguage(code) }
            )
            if showsNotifications {
                bell
            }
            userMenu
            if store.onDismiss != nil {
                PCIconButton(systemName: "xmark") { store.handleBackOrSignout() }
                    .accessibilityLabel(PCStrings.close)
            }
        }
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

    @ViewBuilder
    private var brandMark: some View {
        let name = store.displayOrgName
        if let logo = store.branding?.logoUrl.pcNonEmpty.flatMap(URL.init(string:)) {
            AsyncImage(url: logo) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                PCInitialsAvatar(text: PCInitialsAvatar.initials(name), seed: name, size: 32)
            }
            .frame(maxWidth: 160, maxHeight: 32, alignment: .leading)
        } else if let icon = store.branding?.iconUrl.pcNonEmpty.flatMap(URL.init(string:)) {
            AsyncImage(url: icon) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                PCInitialsAvatar(text: PCInitialsAvatar.initials(name), seed: name, size: 32)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(theme.primarySoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 34, height: 34)
                .background(theme.surface)
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if notifications.unreadCount > 0 {
                        Text("\(notifications.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
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

    /// React `initialsFromEmail`.
    static func initials(fromEmail email: String) -> String {
        guard !email.isEmpty else { return "?" }
        let handle = email.split(separator: "@").first.map(String.init) ?? ""
        let parts = handle.split(whereSeparator: { ".-_".contains($0) })
        if parts.count >= 2, let a = parts[0].first, let b = parts[1].first {
            return "\(a)\(b)".uppercased()
        }
        return (handle.first.map { String($0) } ?? "?").uppercased()
    }

    private var userMenu: some View {
        let email = store.contact ?? ""
        return Menu {
            Section(store.displayOrgName.isEmpty ? "—" : store.displayOrgName) {
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
            if let onBack = store.onBack {
                Button {
                    store.performExitAction()
                } label: {
                    Label(
                        onBack == .back ? PCStrings.back : PCStrings.signOut,
                        systemImage: onBack == .back ? "arrow.left" : "rectangle.portrait.and.arrow.right"
                    )
                }
            }
        } label: {
            Circle()
                .fill(theme.primarySoft)
                .frame(width: 34, height: 34)
                .overlay(
                    Text(email.isEmpty ? String(store.displayOrgName.prefix(1)).uppercased() : Self.initials(fromEmail: email))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.primary)
                )
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
        }
        .accessibilityLabel(PCStrings.accountMenu)
    }
}
