import SwiftUI

public struct RedactoPrivacyCenter: View {
    public typealias InternalPage = PrivacyCenterStore.InternalPage
    public typealias OnBackBehavior = PrivacyCenterStore.OnBackBehavior

    @StateObject private var store: PrivacyCenterStore
    private let accessToken: String
    private let refreshToken: String

    public init(
        baseUrl: String,
        slug: String,
        accessToken: String = "",
        refreshToken: String = "",
        theme: PrivacyCenterThemeMode = .light,
        initialPage: InternalPage = .consentManager,
        onBack: OnBackBehavior? = nil,
        onError: @escaping @Sendable (Error) -> Bool,
        onDismiss: (() -> Void)? = nil,
        language: String? = nil,
        contact: String? = nil,
        // Sandbox mode (additive): a non-empty `sandboxToken` switches the Privacy
        // Center to the consent-server test path (X-Consent-Token header, no JWT and
        // no OTP refresh). Org/workspace come from the provided UUIDs; the acting
        // identity is a UCIC (`org_user_id`), else email (`primary_email`), else
        // mobile (`primary_mobile`).
        sandboxToken: String? = nil,
        email: String? = nil,
        mobile: String? = nil,
        ucic: String? = nil,
        organisationUuid: String? = nil,
        workspaceUuid: String? = nil,
        ledgerBaseUrl: String? = nil,
        settings: PrivacyCenterSettings? = nil,
        // Told of every token the Privacy Center refreshes, so the host can
        // persist the rotated pair (the old refresh token is spent).
        onTokensRefreshed: (@Sendable (String, String?) -> Void)? = nil
    ) {
        // Resolve the sandbox config here but never call `onError` synchronously
        // during view construction: capture any resolve failure and let the store
        // surface it once from the load path (see checkDataAvailability).
        let sandbox: SandboxConfig?
        let sandboxConfigError: Error?
        do {
            sandbox = try SandboxConfig.resolve(
                token: sandboxToken,
                email: email,
                mobile: mobile,
                ucic: ucic,
                organisationUuid: organisationUuid,
                workspaceUuid: workspaceUuid
            )
            sandboxConfigError = nil
        } catch {
            sandbox = nil
            sandboxConfigError = error
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        // Built inside the autoclosure: SwiftUI evaluates it once per view
        // identity. Built outside, every host re-render constructed a throwaway
        // store, and its init reset the shared UI language the user had picked.
        _store = StateObject(wrappedValue: PrivacyCenterStore(
            baseUrl: baseUrl,
            slug: slug,
            accessToken: accessToken,
            refreshToken: refreshToken,
            themeMode: theme,
            initialPage: initialPage,
            onBack: onBack,
            onError: onError,
            onDismiss: onDismiss,
            language: language,
            contact: contact,
            sandbox: sandbox,
            sandboxConfigError: sandboxConfigError,
            ledgerBaseUrl: ledgerBaseUrl,
            settings: settings,
            onTokensRefreshed: onTokensRefreshed
        ))
    }

    public var body: some View {
        PrivacyCenterContent()
            .environmentObject(store)
            .environment(\.privacyCenterTheme, store.theme)
            // A host that prefers the other scheme would otherwise win for the
            // system-drawn parts (placeholders, bars): pin them to our theme.
            .environment(\.colorScheme, store.themeMode == .dark ? .dark : .light)
            .preferredColorScheme(store.themeMode == .dark ? .dark : .light)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .ignoresSafeArea(.keyboard)
            // The store outlives re-renders, so rotated tokens in new props are
            // handed to it (React AuthContext re-syncs from props).
            .onChange(of: accessToken) { _ in syncTokens() }
            .onChange(of: refreshToken) { _ in syncTokens() }
    }

    private func syncTokens() {
        let access = accessToken
        let refresh = refreshToken
        Task { await store.syncHostTokens(accessToken: access, refreshToken: refresh) }
    }
}

struct PrivacyCenterContent: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var notifications: NotificationsViewModelHolder = NotificationsViewModelHolder()

    private var showsNav: Bool {
        !store.isSessionExpired && store.profilePhase == .resolved && store.dataStatus == .hasData
    }

    var body: some View {
        VStack(spacing: 0) {
            PCTopBar(showsNotifications: showsNav, notifications: notifications.vm(for: store))
            ZStack {
                theme.background.ignoresSafeArea()
                // Gate on data availability so the tab bar never flashes before
                // the backend responds: a loader while checking, then either the
                // empty state or the current page.
                if store.isSessionExpired {
                    PCSessionExpiredView()
                } else {
                    switch (store.profilePhase, store.dataStatus) {
                    case (.checking, _):
                        PCLoader()
                    case (.picking, _):
                        ProfilePickerScreen(store: store)
                    case (.resolved, .checking):
                        PCLoader()
                    case (.resolved, .empty):
                        PCNoDataView()
                    case (.resolved, .hasData):
                        if store.isNotificationsOpen {
                            NotificationsScreen(vm: notifications.vm(for: store))
                        } else {
                            screenForCurrentPage
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if let toast = store.toast {
                    PCToastView(toast: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { store.toast = nil }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.toast)

            if showsNav && store.currentPage != .caseDetails && !store.isNotificationsOpen {
                PCBottomTabBar(selectedPage: Binding(
                    get: { store.currentPage },
                    set: { store.navigate(to: $0) }
                ))
            }
            if store.branding?.hidePlatformBranding != true {
                PCFooter()
            }
        }
        .background(theme.background.ignoresSafeArea())
        .task { await store.start() }
    }

    @ViewBuilder
    private var screenForCurrentPage: some View {
        switch store.currentPage {
        case .consentManager:
            ConsentManagerScreen(store: store)
        case .form:
            CaseAndFormSwitcher(store: store)
        case .activity:
            ActivityListScreen(store: store)
        case .receipts:
            ReceiptListScreen(store: store)
        case .caseDetails:
            if let caseRequest = store.selectedCase {
                CaseDetailsScreen(store: store, caseRequest: caseRequest)
                    .id(caseRequest.uuid)
            } else {
                PCLoader()
                    .onAppear { store.navigate(to: .form) }
            }
        }
    }
}

/// Keeps one notifications model for the bell and the page.
@MainActor
final class NotificationsViewModelHolder: ObservableObject {
    private var model: NotificationsViewModel?

    func vm(for store: PrivacyCenterStore) -> NotificationsViewModel {
        if let model { return model }
        let created = NotificationsViewModel(store: store)
        model = created
        return created
    }
}

/// The Requests tab: the case list, or the request form over it (React
/// PrivacyCenterFormPage). The list always comes first, as it does there.
struct CaseAndFormSwitcher: View {
    @EnvironmentObject private var store: PrivacyCenterStore
    @Environment(\.privacyCenterTheme) private var theme
    @StateObject private var vm: CaseHistoryViewModel

    init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: CaseHistoryViewModel(store: store))
    }

    var body: some View {
        Group {
            if store.isRequestFormOpen {
                DSRFormScreen(store: store, onBack: { store.isRequestFormOpen = false })
            } else {
                CaseHistoryScreen(store: store, vm: vm, onNewRequest: { store.isRequestFormOpen = true })
            }
        }
    }
}

/// Terminal screen for an expired session (React PrivacyCenterSessionExpired):
/// a message, and the host's exit action when it passed `onBack`.
struct PCSessionExpiredView: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Circle()
                    .fill(theme.primary.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "clock")
                            .font(.system(size: 56, weight: .light))
                            .foregroundColor(theme.primary)
                    )
                VStack(spacing: 8) {
                    Text(PCStrings.sessionExpiredTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                    Text(PCStrings.sessionExpiredDescription)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if let onBack = store.onBack {
                    PCButton(
                        onBack == .back ? PCStrings.back : PCStrings.signOut,
                        fullWidth: false,
                        leadingIcon: onBack == .back ? "arrow.left" : "rectangle.portrait.and.arrow.right"
                    ) {
                        store.performExitAction()
                    }
                }
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
        }
    }
}

/// Shown when the person has no consents, requests or activity (React
/// PrivacyCenterEmptyState).
struct PCNoDataView: View {
    @Environment(\.privacyCenterTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Circle()
                    .fill(theme.primary.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "tray")
                            .font(.system(size: 52, weight: .light))
                            .foregroundColor(theme.primary)
                    )
                VStack(spacing: 8) {
                    Text(PCStrings.noDataTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                    Text(PCStrings.noDataDescription)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
        }
    }
}
