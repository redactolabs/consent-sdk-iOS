import Foundation

/// The sandbox props as the host passed them; resolved on every change.
struct NoticeSandboxInputs: Equatable {
    var token: String?
    var email: String?
    var mobile: String?
    var ucic: String?
    var organisationUuid: String?
    var workspaceUuid: String?

    func resolve() -> (config: SandboxConfig?, error: Error?) {
        do {
            let config = try SandboxConfig.resolve(
                token: token,
                email: email,
                mobile: mobile,
                ucic: ucic,
                organisationUuid: organisationUuid,
                workspaceUuid: workspaceUuid
            )
            return (config, nil)
        } catch {
            return (nil, error)
        }
    }
}

/// What a modal notice is asking about: the props React re-reads the notice
/// on. A change to any of it is a new read.
struct NoticeIdentity: Equatable {
    var noticeId: String
    var accessToken: String
    var refreshToken: String
    var language: String
    var applicationId: String?
    var ledgerBaseUrl: String?
    var validateAgainst: String
    var includeFullyConsentedData: Bool
    var sandbox: NoticeSandboxInputs
}

extension ConsentNoticeViewModel {
    /// A host that changes the notice's props on a mounted view is asking
    /// about something else: read it again. A new token is a new principal,
    /// so everything the previous one saw or chose is dropped first; an accept
    /// the OTP step was holding for that token still submits what was chosen.
    @discardableResult
    func updateIdentity(_ identity: NoticeIdentity) -> Task<Void, Never>? {
        let tokenChanged = identity.accessToken != accessToken

        var heldAccept: PreparedAccept?
        if tokenChanged {
            accessToken = identity.accessToken
            if let mode = otpFlow.takeDeferredAccept(currentToken: identity.accessToken) {
                heldAccept = prepareAccept(mode: mode)
            }
        }

        noticeId = identity.noticeId
        refreshToken = identity.refreshToken
        initialLanguage = identity.language
        applicationId = identity.applicationId
        ledgerBaseUrl = identity.ledgerBaseUrl
        validateAgainst = identity.validateAgainst
        includeFullyConsentedData = identity.includeFullyConsentedData
        let resolved = identity.sandbox.resolve()
        sandbox = resolved.config
        sandboxConfigError = resolved.error
        cachedAppearance = NoticeAppearanceCache.read(noticeId: identity.noticeId)

        if tokenChanged {
            resetForNewPrincipal()
        }
        if let heldAccept {
            submit(heldAccept)
        }
        return fetchContent(clearingCache: tokenChanged)
    }

    /// Everything a previous principal saw, chose or started, as React clears
    /// it on an `accessToken` change.
    func resetForNewPrincipal() {
        content = nil
        categorizedPurposes = nil
        pendingConfirmAction = nil
        selectedPurposes = [:]
        selectedDataElements = [:]
        initialDataElementSelections = [:]
        recordedPurposeSelections = [:]
        collapsedPurposes = [:]
        collapsedProducts = [:]
        consentedProducts = [:]
        consentedPurposes = [:]
        hasAlreadyConsented = false
        isReconsentMode = false
        isReviewMode = false
        errorMessage = nil
        fetchErrorMessage = nil
        isLoading = true
        isSubmitting = false
        isSubmittingAccept = false

        showAgeVerification = false
        isMinorFlow = false
        selfDeclaredAdult = false
        showGuardianForm = false
        isSubmittingGuardian = false
        guardianFormData = GuardianFormData()
        guardianFormErrors = [:]

        guardianTask?.cancel()
        guardianTask = nil
        stopPolling()
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        showVerificationScreen = false
        verificationReference = nil
        verificationSessionToken = nil
        verificationError = nil
        verificationErrorCode = nil
        canRetryVerification = false
        isVerificationComplete = false
        isAutoTransitioning = false
        refreshTTS()
    }
}

/// The last appearance served per notice, so the next load draws its loading
/// state in the admin's style instead of flashing classic. Best effort.
enum NoticeAppearanceCache {
    static let keyPrefix = "redacto_notice_appearance:"
    static var store: UserDefaults = .standard

    static func read(noticeId: String) -> NoticeAppearance? {
        guard let data = store.data(forKey: keyPrefix + noticeId) else { return nil }
        return try? JSONDecoder().decode(NoticeAppearance.self, from: data)
    }

    static func write(noticeId: String, appearance: NoticeAppearance?) {
        let key = keyPrefix + noticeId
        guard let appearance, appearance != NoticeAppearance(),
              let data = try? JSONEncoder().encode(appearance) else {
            store.removeObject(forKey: key)
            return
        }
        store.set(data, forKey: key)
    }
}
