import SwiftUI

public struct RedactoPrivacyCenter: View {
    public typealias InternalPage = PrivacyCenterStore.InternalPage
    public typealias OnBackBehavior = PrivacyCenterStore.OnBackBehavior

    @StateObject private var store: PrivacyCenterStore
    private let accessToken: String
    private let refreshToken: String
    private let eventHandlers: PrivacyCenterEventHandlers
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - baseUrl: the API host, e.g. `https://api.redacto.io` (recommended):
    ///     the Privacy Center reaches the consent server, the ledger and the
    ///     user service under it. The consent server URL (`…/consent`) still
    ///     works but is deprecated.
    ///   - ledgerBaseUrl: deprecated. Read only when `baseUrl` is the consent
    ///     server URL (`…/consent`) or omitted, as in earlier releases. Ignored
    ///     when `baseUrl` is the API host.
    ///   - slug: deprecated and ignored; passing it logs a one-time warning.
    ///     The organisation comes from the access token, or from
    ///     `organisationUuid` and `workspaceUuid`. Remove it.
    public init(
        baseUrl: String,
        slug: String? = nil,
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
        onTokensRefreshed: (@Sendable (String, String?) -> Void)? = nil,
        // With no access token, show the built-in OTP sign-in instead of the
        // loading state. Off by default, so a token that arrives a moment late
        // never flashes a sign-in screen.
        builtInSignIn: Bool = false,
        // Called once, when the first screen (sign-in or the centre) is on show.
        onReady: ((PrivacyCenterReadyEvent) -> Void)? = nil,
        // Called after the visitor withdrew, re-granted or renewed a consent.
        onConsentChange: ((PrivacyCenterConsentChange) -> Void)? = nil,
        // Called after the visitor submitted a data request.
        onRequestSubmit: ((PrivacyCenterRequestSubmission) -> Void)? = nil,
        // Called when the visitor is signed out, with the reason.
        onSignOut: ((PrivacyCenterSignOutEvent) -> Void)? = nil
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
        let handlers = PrivacyCenterEventHandlers(
            onReady: onReady,
            onConsentChange: onConsentChange,
            onRequestSubmit: onRequestSubmit,
            onSignOut: onSignOut
        )
        self.eventHandlers = handlers
        // Built inside the autoclosure: SwiftUI evaluates it once per view
        // identity. Built outside, every host re-render constructed a throwaway
        // store, and its init reset the shared UI language the user had picked.
        _store = StateObject(wrappedValue: PrivacyCenterStore(
            baseUrl: baseUrl,
            slug: slug ?? "",
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
            onTokensRefreshed: onTokensRefreshed,
            builtInSignIn: builtInSignIn,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            events: handlers
        ))
    }

    public var body: some View {
        // Handlers always see the latest props: swapped in on every render.
        let _ = syncEventHandlers()
        PrivacyCenterContent()
            .modifier(PCLayoutDirection(rightToLeft: store.isRightToLeft))
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
            .onChange(of: scenePhase) { phase in
                if phase == .active { store.resumeFromBackground() }
            }
    }

    private func syncEventHandlers() -> Bool {
        store.events.handlers = eventHandlers
        return true
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
        !store.showsSignIn && !store.isSessionExpired && store.profilePhase == .resolved && store.dataStatus == .hasData
    }

    var body: some View {
        if store.showsSignIn {
            PCSignInScreen(store: store)
                .background(theme.background.ignoresSafeArea())
                .task { await store.start() }
        } else {
            centre
        }
    }

    private var centre: some View {
        VStack(spacing: 0) {
            PCTopBar(
                showsNotifications: showsNav && store.isSectionEnabled(.notifications),
                notifications: notifications.vm(for: store)
            )
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

            if showsNav && store.visiblePage != .caseDetails && !store.isNotificationsOpen {
                PCBottomTabBar(
                    selectedPage: Binding(
                        get: { store.visiblePage },
                        set: { store.navigate(to: $0) }
                    ),
                    tabs: store.tabSections.compactMap { section in
                        PrivacyCenterStore.InternalPage(rawValue: section.key.rawValue).map {
                            PCBottomTabBar.Tab(page: $0, label: store.sectionLabel(section.key))
                        }
                    }
                )
            }
            PCSettingsFooter()
        }
        .background(theme.background.ignoresSafeArea())
        .background(PCActivityTracker { store.recordActivity() })
        .task { await store.start() }
    }

    @ViewBuilder
    private var screenForCurrentPage: some View {
        switch store.visiblePage {
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
                    .onAppear { store.navigate(to: store.isPageAllowed(.form) ? .form : store.homePage) }
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
                            .font(theme.font(size: 56, weight: .light))
                            .foregroundColor(theme.primary)
                    )
                VStack(spacing: 8) {
                    Text(PCStrings.sessionExpiredTitle)
                        .font(theme.font(size: 20, weight: .bold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                    Text(PCStrings.sessionExpiredDescription)
                        .font(theme.font(size: 15))
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
                } else if store.canSignInAgain {
                    // With no host exit to go back to, the built-in sign-in.
                    PCButton(PCStrings.signInAgain, fullWidth: false, leadingIcon: "person.crop.circle.badge.checkmark") {
                        store.restartSignIn()
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
                            .font(theme.font(size: 52, weight: .light))
                            .foregroundColor(theme.primary)
                    )
                VStack(spacing: 8) {
                    Text(PCStrings.noDataTitle)
                        .font(theme.font(size: 20, weight: .bold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                    Text(PCStrings.noDataDescription)
                        .font(theme.font(size: 15))
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

/// Urdu, Sindhi and Kashmiri read right to left once settings are customised;
/// otherwise the direction is inherited, exactly as before. The modifier is
/// always applied, so switching direction keeps the tree (and its state).
struct PCLayoutDirection: ViewModifier {
    let rightToLeft: Bool
    @Environment(\.layoutDirection) private var inherited

    func body(content: Content) -> some View {
        content.environment(\.layoutDirection, rightToLeft ? .rightToLeft : inherited)
    }
}
