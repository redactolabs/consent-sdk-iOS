import Foundation
import SwiftUI

public extension Notification.Name {
    static let privacyCenterLanguageChanged = Notification.Name("PrivacyCenterLanguageChanged")
}

/// Whether the user has any Privacy Center data yet. Drives the gate that shows
/// a loader, then either the empty state or the full center.
public enum DataAvailabilityStatus: Sendable, Equatable {
    case checking, hasData, empty
}

/// A transient message over the Privacy Center, the native stand-in for the
/// toasts React raises.
public struct PCToastMessage: Identifiable, Equatable, Sendable {
    public enum Kind: Sendable { case success, error, info }

    public let id = UUID()
    public let text: String
    public let kind: Kind
}

/// Box the token store fires through when the session ends; the store is not
/// yet built when the token store is.
final class PCSessionSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable () -> Void)?

    func set(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
    }

    func fire() {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        handler?()
    }
}

@MainActor
public final class PrivacyCenterStore: ObservableObject {
    public enum InternalPage: String, Sendable, Equatable {
        case consentManager = "consent-manager"
        case form
        case activity
        case receipts
        case caseDetails = "case-details"
    }

    public enum OnBackBehavior: String, Sendable {
        case back, signout
    }

    @Published public var currentPage: InternalPage
    @Published public var selectedCase: CaseRequest?
    @Published public var pendingCaseUuid: String?
    @Published public var theme: PrivacyCenterTheme
    @Published public var themeMode: PrivacyCenterThemeMode
    @Published public var language: String
    @Published public var contact: String?
    @Published public var organisationUuid: String?
    @Published public var workspaceUuid: String?
    @Published public var dataStatus: DataAvailabilityStatus = .checking
    @Published public var profilePhase: ProfileGatePhase = .checking
    @Published public var profileCandidates: [IdentityCandidate] = []
    @Published public var profileBusyUuid: String?
    @Published public var profileSelectError: String?
    @Published public var currentOrgUserId: String?
    /// The refresh token is dead and the person has to sign in again (React
    /// `PrivacyCenterSessionExpired`). Nothing is fetched while this is set.
    @Published public internal(set) var isSessionExpired = false
    /// Workspace branding: logo, brand name, colours, platform footer.
    @Published public private(set) var branding: OrgBrandingDetail?
    private var brandingOrganisation: String?
    /// The notification hub page (React `notifications` page), shown over the
    /// current tab.
    @Published public var isNotificationsOpen = false
    /// Case list vs. request form on the Requests tab (React `pc_grievance_view`).
    @Published public var isRequestFormOpen = false
    @Published public var toast: PCToastMessage?
    /// The settings published in the Redacto console, with the host's
    /// `settings` merged over them; the defaults until they arrive.
    @Published public internal(set) var settings: ResolvedPrivacyCenterSettings
    /// True once the console has published settings or the host overrides them.
    @Published public internal(set) var isSettingsCustomised: Bool
    /// The Brand Identity details the published settings use.
    @Published public internal(set) var brandContact: PrivacyCenterBrandContact = .empty
    /// Whether there is a session to show; false sends a visitor with the
    /// built-in sign-in to it.
    @Published public internal(set) var hasSession: Bool
    /// The built-in sign-in has no organisation and workspace to send a code
    /// for: no token, and `organisationUuid` or `workspaceUuid` is missing.
    @Published public internal(set) var organisationLookupFailed = false
    /// Deprecated: always false. The organisation is never looked up; it comes
    /// from the access token, or from `organisationUuid` and `workspaceUuid`.
    @Published public internal(set) var isResolvingOrganisation = false
    var pickedOrgUserId: String?
    let isSandboxSession: Bool
    let hostSettings: PrivacyCenterSettings?
    /// With no access token, show the built-in OTP sign-in.
    public let builtInSignIn: Bool
    let events: PrivacyCenterEvents
    /// The language the visitor picked from the switcher, which wins while it
    /// stays enabled.
    var languageChoice: String?
    /// The language policy last applied (React `useLanguagePolicy`'s key):
    /// nil while nothing is customised.
    var appliedLanguagePolicy: PrivacyCenterLanguageSettings?
    var publishedSettings: PublicPrivacyCenterSettings?
    var publishedSettingsOrganisation: String?
    var settingsTask: Task<Void, Never>?
    var brandingTask: Task<Void, Never>?
    var inactivityClock: PrivacyCenterInactivityClock?
    var inactivityTask: Task<Void, Never>?
    var now: () -> Date = { Date() }

    public let tokenStore: TokenStore
    public let api: PrivacyCenterAPI
    public let onError: @Sendable (Error) -> Bool
    /// Deprecated and ignored: kept so existing code compiles. Passing one
    /// logs a one-time warning.
    public let slug: String
    public let onBack: OnBackBehavior?
    public let onDismiss: (() -> Void)?
    /// The consent server URL: `{host}/consent` when `baseUrl` was the API
    /// host, else the `baseUrl` passed.
    public let baseUrl: String
    /// The ledger URL: the one under the API host or the `ledgerBaseUrl`
    /// passed; `nil` when neither applies.
    public let ledgerBaseUrl: String?
    /// A sandbox config that failed to resolve (a non-empty sandbox token was
    /// supplied with a missing org/workspace/identity). Surfaced through `onError`
    /// from the load path — never synchronously during view construction.
    private let sandboxConfigError: Error?
    let urlSession: URLSession
    let userServerBaseUrl: String
    private var toastTask: Task<Void, Never>?

    /// - Parameters:
    ///   - baseUrl: the API host, e.g. `https://api.redacto.io` (recommended).
    ///     The consent server URL (`…/consent`) still works but is deprecated.
    ///   - ledgerBaseUrl: deprecated. Read only when `baseUrl` is the consent
    ///     server URL (`…/consent`) or omitted, as in earlier releases. Ignored
    ///     when `baseUrl` is the API host.
    public init(
        baseUrl: String,
        slug: String = "",
        accessToken: String,
        refreshToken: String,
        themeMode: PrivacyCenterThemeMode,
        initialPage: InternalPage,
        onBack: OnBackBehavior?,
        onError: @escaping @Sendable (Error) -> Bool,
        onDismiss: (() -> Void)? = nil,
        language: String? = nil,
        contact: String? = nil,
        sandbox: SandboxConfig? = nil,
        sandboxConfigError: Error? = nil,
        urlSession: URLSession = .shared,
        ledgerBaseUrl: String? = nil,
        settings: PrivacyCenterSettings? = nil,
        onTokensRefreshed: (@Sendable (String, String?) -> Void)? = nil,
        builtInSignIn: Bool = false,
        organisationUuid: String? = nil,
        workspaceUuid: String? = nil,
        events: PrivacyCenterEventHandlers = PrivacyCenterEventHandlers()
    ) {
        let endpoints = NoticeBaseUrl.endpoints(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl)
        self.baseUrl = endpoints.baseUrl ?? baseUrl
        self.ledgerBaseUrl = PrivacyCenterAPI.normalizedLedgerBaseUrl(endpoints.ledgerBaseUrl)
        self.userServerBaseUrl = PrivacyCenterBrandingAPI.userServerBaseUrl(for: endpoints)
        self.slug = slug
        Self.reportSlugDeprecation(slug: slug)
        self.themeMode = themeMode
        self.hostSettings = settings
        let resolvedSettings = PrivacyCenterSettingsResolver.resolve(published: nil, overrides: settings)
        self.settings = resolvedSettings
        let customised = settings?.overridesPublishedSettings ?? false
        self.isSettingsCustomised = customised
        self.theme = PrivacyCenterTheme.from(mode: themeMode, branding: nil)
            .applying(resolvedSettings.branding, workspaceFont: nil)
        self.builtInSignIn = builtInSignIn && sandbox == nil && sandboxConfigError == nil
        self.events = PrivacyCenterEvents(handlers: events)
        self.hasSession = sandbox != nil || sandboxConfigError != nil
            || !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.currentPage = initialPage
        self.onBack = onBack
        self.onError = onError
        self.onDismiss = onDismiss
        self.sandboxConfigError = sandboxConfigError
        self.urlSession = urlSession
        self.isSandboxSession = sandbox != nil || sandboxConfigError != nil
        self.currentOrgUserId = sandbox == nil ? PCProfileGate.orgUserId(fromToken: accessToken) : nil
        // The host's overrides apply from the first frame, as React runs the
        // language policy on mount, so the first fetch asks in that language.
        let detectedLanguage = Self.resolveLanguage(language)
        let initialPolicy: PrivacyCenterLanguageSettings? = customised ? resolvedSettings.languages : nil
        let resolvedLanguage = initialPolicy.map {
            PrivacyCenterLanguagePolicy.pick(current: detectedLanguage, languages: $0, userChoice: nil)
        } ?? detectedLanguage
        self.appliedLanguagePolicy = initialPolicy
        self.language = resolvedLanguage
        PCStrings.currentLanguage = resolvedLanguage

        let signal = PCSessionSignal()
        let store = TokenStore(
            baseUrl: baseUrl,
            accessToken: accessToken,
            refreshToken: refreshToken,
            onError: onError,
            updateTokens: onTokensRefreshed,
            sandbox: sandbox,
            urlSession: urlSession,
            onSessionExpired: { signal.fire() }
        )
        self.tokenStore = store
        self.api = PrivacyCenterAPI(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl, tokenStore: store, urlSession: urlSession)

        if let sandbox {
            // Sandbox: org/workspace/contact come from the config, not a JWT. The
            // `contact` drives the body-based endpoints (form-data / create-case /
            // manage-consent), mirroring the JWT path's resolvedContact.
            self.organisationUuid = sandbox.organisationUuid
            self.workspaceUuid = sandbox.workspaceUuid
            self.contact = sandbox.contact
        } else if let payload = JWTDecoder.decode(accessToken) {
            self.organisationUuid = payload.organisationUuid
            self.workspaceUuid = payload.workspaceUuid
            self.contact = contact ?? PCJwt.contact(fromToken: accessToken) ?? payload.resolvedContact
        } else {
            // No token: the props name the organisation for the settings and
            // the built-in sign-in.
            self.organisationUuid = organisationUuid.pcTrimmedNonEmpty
            self.workspaceUuid = workspaceUuid.pcTrimmedNonEmpty
            self.contact = contact
        }

        // The task takes its own weak reference: Swift 5.10 (Xcode 15) rejects
        // reading the enclosing closure's captured `self` from concurrent code.
        signal.set { [weak self] in
            Task { @MainActor [weak self] in self?.markSessionExpired() }
        }
    }

    /// The host's language when the Privacy Center ships it, else the device's
    /// when it does, else English. An unsupported code (a device set to `fr`)
    /// must never reach the servers as `language=fr`.
    static func resolveLanguage(_ explicit: String?, preferred: [String] = Locale.preferredLanguages) -> String {
        let supported = Set(PrivacyCenterLanguages.all.map(\.code))
        func match(_ code: String) -> String? {
            if supported.contains(code) { return code }
            let base = String(code.split(separator: "-").first ?? Substring(code))
            return supported.contains(base) ? base : nil
        }
        if let explicit = explicit?.trimmingCharacters(in: .whitespaces), !explicit.isEmpty {
            return match(explicit) ?? "en"
        }
        for code in preferred {
            if let found = match(code) { return found }
        }
        return "en"
    }

    /// The `language` sent to the servers: none for English, as React's
    /// `getLangParam` leaves English on the untranslated default.
    public var langParam: String? {
        language == "en" ? nil : language
    }

    public var displayOrgName: String {
        if !settings.branding.inheritIdentity, let name = settings.branding.displayName.pcNonEmpty { return name }
        if let brand = branding?.brandName.pcNonEmpty { return brand }
        return cachedOrgName ?? ""
    }

    /// The logo the centre shows: the settings' own once they stop inheriting
    /// the workspace identity, which also drops the inherited icon.
    public var logoUrl: String? {
        settings.branding.inheritIdentity ? branding?.logoUrl.pcNonEmpty : settings.branding.logoUrl
    }

    public var iconUrl: String? {
        settings.branding.inheritIdentity ? branding?.iconUrl.pcNonEmpty : nil
    }

    private var cachedOrgName: String?

    public func navigate(to page: InternalPage) {
        // A section switched off in the settings can't be navigated to.
        guard isPageAllowed(page) else { return }
        isNotificationsOpen = false
        currentPage = page
        if page != .caseDetails { selectedCase = nil }
    }

    public func openCase(_ caseRequest: CaseRequest) {
        isNotificationsOpen = false
        selectedCase = caseRequest
        currentPage = .caseDetails
    }

    public func openNotifications() {
        guard isSectionEnabled(.notifications) else { return }
        isNotificationsOpen = true
    }

    public func setThemeMode(_ mode: PrivacyCenterThemeMode) {
        themeMode = mode
        applyTheme()
    }

    public func toggleTheme() {
        setThemeMode(themeMode == .light ? .dark : .light)
    }

    func applyTheme() {
        theme = PrivacyCenterTheme.from(mode: themeMode, branding: branding?.theme)
            .applying(settings.branding, workspaceFont: branding?.theme?.fontFamily)
    }

    public func setLanguage(_ code: String) {
        guard code != language else { return }
        language = code
        PCStrings.currentLanguage = code
        // Notify subscribed views/VMs they should refetch with the new locale.
        NotificationCenter.default.post(name: .privacyCenterLanguageChanged, object: nil)
        loadSettings()
    }

    /// A language the visitor picked from the switcher; it wins over the
    /// published default while it stays enabled.
    public func chooseLanguage(_ code: String) {
        languageChoice = code
        setLanguage(code)
    }

    public func reportError(_ error: Error) {
        if isSilentPrivacyCenterError(error) { return }
        _ = onError(error)
    }

    public func showToast(_ text: String, kind: PCToastMessage.Kind) {
        let message = PCToastMessage(text: text, kind: kind)
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            if self?.toast?.id == message.id { self?.toast = nil }
        }
    }

    /// The host's close control: always dismisses.
    public func handleBackOrSignout() {
        onDismiss?()
    }

    /// React `usePrivacyCenterExitAction`: `back` leaves, `signout` drops the
    /// session first. Only offered when the host passed `onBack`.
    public func performExitAction() {
        guard let onBack else { return }
        if onBack == .signout {
            signOut()
            events.signedOut()
        }
        onDismiss?()
    }

    public func signOut() {
        pickedOrgUserId = nil
        selectedCase = nil
        stopInactivityTimer()
        Task { await tokenStore.clearSession() }
    }

    func markSessionExpired() {
        isSessionExpired = true
        stopInactivityTimer()
        events.sessionEnded(.sessionExpired)
    }

    /// New tokens from the host (a re-render with rotated props). React's
    /// AuthProvider re-syncs its state from props; a new refresh token after
    /// the session expired brings the Privacy Center back.
    public func syncHostTokens(accessToken: String, refreshToken: String) async {
        guard !isSandboxSession else { return }
        await tokenStore.syncFromHost(accessToken: accessToken, refreshToken: refreshToken)
        let previousOrganisation = organisationUuid
        if let payload = JWTDecoder.decode(accessToken) {
            organisationUuid = payload.organisationUuid
            workspaceUuid = payload.workspaceUuid
            currentOrgUserId = PCProfileGate.orgUserId(fromToken: accessToken)
            rememberOrganisationName(fromToken: accessToken)
        }
        let gainedSession = !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasSession
        if gainedSession {
            hasSession = true
            events.sessionStarted()
            // A centre that opened before the host had a token is ready now.
            events.ready(signedIn: true)
        }
        let organisationChanged = organisationUuid != previousOrganisation
        if organisationChanged, let shown = publishedSettingsOrganisation, shown != organisationUuid {
            // Another organisation's settings never stay on show: back to the
            // defaults and the host's overrides until the new ones arrive.
            applyPublished(nil, organisation: nil)
        }
        if gainedSession || organisationChanged {
            loadSettings()
        }
        if organisationChanged {
            brandingTask = Task { [weak self] in await self?.loadBranding() }
        }
        let stillExpired = await tokenStore.isSessionExpired
        if isSessionExpired && !stillExpired {
            isSessionExpired = false
            events.sessionStarted()
            dataStatus = .checking
            restartInactivityTimerIfNeeded()
            await checkDataAvailability()
        }
        // A session that started or came back here is timed again.
        restartInactivityTimerIfNeeded()
    }

    func awaitBranding() async {
        await brandingTask?.value
    }

    func rememberOrganisationName(fromToken accessToken: String) {
        cachedOrgName = PCJwt.string("organisation_name", in: accessToken)
    }

    nonisolated static func reportSlugDeprecation(slug: String, log: BaseUrlDeprecationLog = .shared) {
        if !slug.isEmpty { log.report([.slug]) }
    }

    public func loadBranding() async {
        guard let organisation = organisationUuid.pcTrimmedNonEmpty else { return }
        guard branding == nil || brandingOrganisation != organisation else { return }
        if brandingOrganisation != organisation, branding != nil {
            branding = nil
            applyTheme()
        }
        brandingOrganisation = organisation
        cachedOrgName = PCJwt.string("organisation_name", in: await tokenStore.currentRawToken())
        do {
            let fetched = try await PrivacyCenterBrandingAPI.fetch(organisationUuid: organisation, userServerBaseUrl: userServerBaseUrl, urlSession: urlSession)
            guard organisationUuid.pcTrimmedNonEmpty == organisation else { return }
            branding = fetched
            applyTheme()
        } catch {
            // Branding is cosmetic: React logs and renders with the defaults.
        }
    }

    /// Runs the three signals (consents / cases / activity) in parallel and
    /// resolves `dataStatus`. Fail-open: a thrown error on a signal counts as
    /// "has data", so a transient/auth error never wrongly locks the user out.
    /// The empty state shows ONLY when all three are conclusively empty.
    public func checkDataAvailability() async {
        // Fail loud (deferred out of `init`) when a sandbox token was supplied with
        // an invalid config: surface the resolve error via `onError` and skip the
        // data check. The JWT/live path (no sandbox token) is unaffected.
        if let sandboxConfigError {
            reportError(sandboxConfigError)
            dataStatus = .empty
            return
        }
        if isSessionExpired { return }

        async let consentsEmpty = isConsentsEmpty()
        async let casesEmpty = isCasesEmpty()
        async let activitiesEmpty = isActivitiesEmpty()
        let c = await consentsEmpty
        let k = await casesEmpty
        let a = await activitiesEmpty
        dataStatus = (c && k && a) ? .empty : .hasData
    }

    private func isConsentsEmpty() async -> Bool {
        do {
            let v = try await api.getUserConsents(limit: 1, nominatedLimit: 1, language: langParam)
            return (v.statusSummary?.totalPurposes ?? 0) == 0
                && (v.direct?.isEmpty ?? true)
                && (v.nominated?.isEmpty ?? true)
                && (v.nominators?.isEmpty ?? true)
                && (v.data?.isEmpty ?? true)
                && (v.directProductGroups?.isEmpty ?? true)
                && (v.nominatedPurposes?.isEmpty ?? true)
        } catch {
            return false
        }
    }

    private func isCasesEmpty() async -> Bool {
        guard contact.pcNonEmpty != nil else { return true }
        do {
            let v = try await api.getCaseHistory(offset: 0, limit: 1, language: langParam)
            return v.data?.isEmpty ?? true
        } catch {
            return false
        }
    }

    private func isActivitiesEmpty() async -> Bool {
        do {
            let v = try await api.getActivities(limit: 1, language: langParam)
            return v.page.totalCount == 0
        } catch {
            return false
        }
    }
}
