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

    public let tokenStore: TokenStore
    public let api: PrivacyCenterAPI
    public let onError: @Sendable (Error) -> Bool
    public let slug: String
    public let onBack: OnBackBehavior?
    public let onDismiss: (() -> Void)?
    public let baseUrl: String

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
        urlSession: URLSession = .shared
    ) {
        self.baseUrl = baseUrl
        self.slug = slug
        self.themeMode = themeMode
        self.theme = PrivacyCenterTheme.from(mode: themeMode)
        self.currentPage = initialPage
        self.onBack = onBack
        self.onError = onError
        self.onDismiss = onDismiss
        let resolvedLanguage = language ?? Locale.current.language.languageCode?.identifier ?? "en"
        self.language = resolvedLanguage
        PCStrings.currentLanguage = resolvedLanguage

        let store = TokenStore(
            baseUrl: baseUrl,
            accessToken: accessToken,
            refreshToken: refreshToken,
            onError: onError,
            urlSession: urlSession
        )
        self.tokenStore = store
        self.api = PrivacyCenterAPI(baseUrl: baseUrl, tokenStore: store, urlSession: urlSession)

        if let payload = JWTDecoder.decode(accessToken) {
            self.organisationUuid = payload.organisationUuid
            self.workspaceUuid = payload.workspaceUuid
            self.contact = contact ?? payload.resolvedContact
        } else {
            self.contact = contact
        }
    }

    public func navigate(to page: InternalPage) {
        currentPage = page
        if page != .caseDetails { selectedCase = nil }
    }

    public func openCase(_ caseRequest: CaseRequest) {
        selectedCase = caseRequest
        currentPage = .caseDetails
    }

    public func setThemeMode(_ mode: PrivacyCenterThemeMode) {
        themeMode = mode
        theme = .from(mode: mode)
    }

    public func toggleTheme() {
        setThemeMode(themeMode == .light ? .dark : .light)
    }

    public func setLanguage(_ code: String) {
        guard code != language else { return }
        language = code
        PCStrings.currentLanguage = code
        // Notify subscribed views/VMs they should refetch with the new locale.
        NotificationCenter.default.post(name: .privacyCenterLanguageChanged, object: nil)
    }

    public func reportError(_ error: Error) {
        if isCancellationError(error) { return }
        _ = onError(error)
    }

    public func handleBackOrSignout() {
        onDismiss?()
    }

    /// Runs the three signals (consents / cases / activity) in parallel and
    /// resolves `dataStatus`. Fail-open: a thrown error on a signal counts as
    /// "has data", so a transient/auth error never wrongly locks the user out.
    /// The empty state shows ONLY when all three are conclusively empty.
    public func checkDataAvailability() async {
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
            let v = try await api.getUserConsents(limit: 1, nominatedLimit: 1, language: language)
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
        do {
            let v = try await api.getCaseHistory(limit: 1, language: language)
            return v.data?.isEmpty ?? true
        } catch {
            return false
        }
    }

    private func isActivitiesEmpty() async -> Bool {
        do {
            let v = try await api.getActivities(limit: 1, language: language)
            return v.page.totalCount == 0
        } catch {
            return false
        }
    }
}
