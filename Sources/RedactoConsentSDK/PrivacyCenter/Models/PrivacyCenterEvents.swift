import Foundation

/// Passed to `onReady` once the first screen is on show.
public struct PrivacyCenterReadyEvent: Equatable, Sendable {
    /// False when the built-in sign-in screen is what the visitor sees.
    public let signedIn: Bool

    public init(signedIn: Bool) {
        self.signedIn = signedIn
    }
}

/// Passed to `onConsentChange` after a consent was changed successfully.
public struct PrivacyCenterConsentChange: Equatable, Sendable {
    /// `revoke` withdraws consent; `regrant` and `renew` give it again.
    public let action: ConsentAction
    public let purposeUuid: String
    public let productUuid: String?
    /// The data elements the change covered; empty when it covered the whole purpose.
    public let dataElementUuids: [String]
    /// Set when the visitor acted on behalf of someone who nominated them.
    public let nominatorUuid: String?

    public init(action: ConsentAction, purposeUuid: String, productUuid: String?, dataElementUuids: [String], nominatorUuid: String?) {
        self.action = action
        self.purposeUuid = purposeUuid
        self.productUuid = productUuid
        self.dataElementUuids = dataElementUuids
        self.nominatorUuid = nominatorUuid
    }
}

/// Passed to `onRequestSubmit` after a data request (case) was created.
public struct PrivacyCenterRequestSubmission: Equatable, Sendable {
    /// The human-readable case id shown to the visitor.
    public let caseId: String
    public let caseUuid: String
    public let requestType: PrivacyCenterRequestTypeKey
    /// The product the request is about; nil for nomination and grievance.
    public let productUuid: String?

    public init(caseId: String, caseUuid: String, requestType: PrivacyCenterRequestTypeKey, productUuid: String?) {
        self.caseId = caseId
        self.caseUuid = caseUuid
        self.requestType = requestType
        self.productUuid = productUuid
    }
}

/// Why the visitor was signed out: they chose to, they were idle for the
/// configured session timeout, or their session could no longer be refreshed.
public enum PrivacyCenterSignOutReason: String, Equatable, Sendable {
    case user
    case timeout
    case sessionExpired = "session-expired"
}

public struct PrivacyCenterSignOutEvent: Equatable, Sendable {
    public let reason: PrivacyCenterSignOutReason

    public init(reason: PrivacyCenterSignOutReason) {
        self.reason = reason
    }
}

/// The host's lifecycle callbacks (React `onReady`, `onConsentChange`,
/// `onRequestSubmit`, `onSignOut`).
public struct PrivacyCenterEventHandlers {
    public var onReady: ((PrivacyCenterReadyEvent) -> Void)?
    public var onConsentChange: ((PrivacyCenterConsentChange) -> Void)?
    public var onRequestSubmit: ((PrivacyCenterRequestSubmission) -> Void)?
    public var onSignOut: ((PrivacyCenterSignOutEvent) -> Void)?

    public init(
        onReady: ((PrivacyCenterReadyEvent) -> Void)? = nil,
        onConsentChange: ((PrivacyCenterConsentChange) -> Void)? = nil,
        onRequestSubmit: ((PrivacyCenterRequestSubmission) -> Void)? = nil,
        onSignOut: ((PrivacyCenterSignOutEvent) -> Void)? = nil
    ) {
        self.onReady = onReady
        self.onConsentChange = onConsentChange
        self.onRequestSubmit = onRequestSubmit
        self.onSignOut = onSignOut
    }
}

/// Hands the host's callbacks to the parts of the Privacy Center that know when
/// each moment happens. Always calls the latest handlers the host passed:
/// `RedactoPrivacyCenter` swaps them in on every render. `onReady` fires once,
/// and a session end is reported once however many paths notice it.
@MainActor
final class PrivacyCenterEvents {
    var handlers: PrivacyCenterEventHandlers
    private var readyFired = false
    private var sessionEnded = false

    init(handlers: PrivacyCenterEventHandlers = PrivacyCenterEventHandlers()) {
        self.handlers = handlers
    }

    func ready(signedIn: Bool) {
        guard !readyFired else { return }
        readyFired = true
        handlers.onReady?(PrivacyCenterReadyEvent(signedIn: signedIn))
    }

    func consentChanged(_ change: PrivacyCenterConsentChange) {
        handlers.onConsentChange?(change)
    }

    func requestSubmitted(_ submission: PrivacyCenterRequestSubmission) {
        handlers.onRequestSubmit?(submission)
    }

    /// The visitor chose to sign out; reported every time.
    func signedOut() {
        handlers.onSignOut?(PrivacyCenterSignOutEvent(reason: .user))
    }

    /// The session ended on its own (inactivity, or a dead refresh token).
    func sessionEnded(_ reason: PrivacyCenterSignOutReason) {
        guard !sessionEnded else { return }
        sessionEnded = true
        handlers.onSignOut?(PrivacyCenterSignOutEvent(reason: reason))
    }

    /// A new session began (signed in again, or the host handed new tokens).
    func sessionStarted() {
        sessionEnded = false
    }
}
