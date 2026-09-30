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
    @Published public private(set) var isSessionExpired = false
    /// Workspace branding: logo, brand name, colours, platform footer.
    @Published public private(set) var branding: OrgBrandingDetail?
    /// The notification hub page (React `notifications` page), shown over the
    /// current tab.
    @Published public var isNotificationsOpen = false
    /// Case list vs. request form on the Requests tab (React `pc_grievance_view`).
    @Published public var isRequestFormOpen = false
    @Published public var toast: PCToastMessage?
    var pickedOrgUserId: String?
    let isSandboxSession: Bool
    let appearance: AppearanceStyle

    public let tokenStore: TokenStore
    public let api: PrivacyCenterAPI
    public let onError: @Sendable (Error) -> Bool
    public let slug: String
    public let onBack: OnBackBehavior?
    public let onDismiss: (() -> Void)?
    public let baseUrl: String
    public let ledgerBaseUrl: String?
    /// A sandbox config that failed to resolve (a non-empty sandbox token was
    /// supplied with a missing org/workspace/identity). Surfaced through `onError`
    /// from the load path — never synchronously during view construction.
    private let sandboxConfigError: Error?
    private let urlSession: URLSession
    private var toastTask: Task<Void, Never>?

    public init(
        baseUrl: String,
        slug: String,
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
        onTokensRefreshed: (@Sendable (String, String?) -> Void)? = nil
    ) {
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = PrivacyCenterAPI.normalizedLedgerBaseUrl(ledgerBaseUrl)
        self.slug = slug
        self.themeMode = themeMode
        self.appearance = settings?.appearance ?? .classic
        self.theme = PrivacyCenterTheme.from(mode: themeMode, branding: nil, appearance: settings?.appearance ?? .classic)
        self.currentPage = initialPage
        self.onBack = onBack
        self.onError = onError
        self.onDismiss = onDismiss
        self.sandboxConfigError = sandboxConfigError
        self.urlSession = urlSession
        self.isSandboxSession = sandbox != nil || sandboxConfigError != nil
        self.currentOrgUserId = sandbox == nil ? PCProfileGate.orgUserId(fromToken: accessToken) : nil
        let resolvedLanguage = Self.resolveLanguage(language)
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
        if let brand = branding?.brandName.pcNonEmpty { return brand }
        return orgNameFromToken
    }

    private var orgNameFromToken: String {
        if let name = cachedOrgName { return name }
        return slug
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private var cachedOrgName: String?

    public func navigate(to page: InternalPage) {
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
        isNotificationsOpen = true
    }

    public func setThemeMode(_ mode: PrivacyCenterThemeMode) {
        themeMode = mode
        applyTheme()
    }

    public func toggleTheme() {
        setThemeMode(themeMode == .light ? .dark : .light)
    }

    private func applyTheme() {
        theme = .from(mode: themeMode, branding: branding?.theme, appearance: appearance)
    }

    public func setLanguage(_ code: String) {
        guard code != language else { return }
        language = code
        PCStrings.currentLanguage = code
        // Notify subscribed views/VMs they should refetch with the new locale.
        NotificationCenter.default.post(name: .privacyCenterLanguageChanged, object: nil)
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
        }
        onDismiss?()
    }

    public func signOut() {
        pickedOrgUserId = nil
        selectedCase = nil
        Task { await tokenStore.clearSession() }
    }

    func markSessionExpired() {
        isSessionExpired = true
    }

    /// New tokens from the host (a re-render with rotated props). React's
    /// AuthProvider re-syncs its state from props; a new refresh token after
    /// the session expired brings the Privacy Center back.
    public func syncHostTokens(accessToken: String, refreshToken: String) async {
        guard !isSandboxSession else { return }
        await tokenStore.syncFromHost(accessToken: accessToken, refreshToken: refreshToken)
        if let payload = JWTDecoder.decode(accessToken) {
            organisationUuid = payload.organisationUuid
            workspaceUuid = payload.workspaceUuid
            currentOrgUserId = PCProfileGate.orgUserId(fromToken: accessToken)
        }
        let stillExpired = await tokenStore.isSessionExpired
        if isSessionExpired && !stillExpired {
            isSessionExpired = false
            dataStatus = .checking
            await checkDataAvailability()
        }
    }

    public func loadBranding() async {
        guard !slug.isEmpty, branding == nil else { return }
        cachedOrgName = PCJwt.string("organisation_name", in: await tokenStore.currentRawToken())
        do {
            branding = try await PrivacyCenterBrandingAPI.fetch(slug: slug, consentBaseUrl: baseUrl, urlSession: urlSession)
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
