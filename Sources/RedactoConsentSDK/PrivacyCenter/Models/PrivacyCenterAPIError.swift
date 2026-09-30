import Foundation

/// True for errors that come from a cancelled task and should not be surfaced to the user.
public func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    let desc = String(describing: error).lowercased()
    return desc.contains("cancelled") || desc.contains("canceled")
}

public enum PrivacyCenterAPIError: LocalizedError, Sendable, CustomDebugStringConvertible {
    case unauthorized(String?)
    case forbidden(String?)
    case notFound(String?)
    case validationError(String?)
    case serverError(Int, String?)
    case networkError(String)
    case decodingError(String)
    case invalidToken(String)
    case missingOrgOrWorkspace
    case refreshFailed(String?)
    case consentOperationFailed(String)
    case uploadFailed(String?)

    /// What a person can read. Parser and token internals stay in
    /// `debugDescription`, which is what `onError` hosts log.
    public var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg ?? PCStrings.sessionExpiredDescription
        case .forbidden(let msg), .notFound(let msg), .validationError(let msg): return msg ?? PCStrings.someThingWentWrong
        case .serverError(_, let msg): return msg ?? PCStrings.someThingWentWrong
        case .networkError(let msg): return msg
        case .decodingError, .invalidToken: return PCStrings.someThingWentWrong
        case .missingOrgOrWorkspace: return PCStrings.missingOrgOrWorkspace
        case .refreshFailed(let msg): return msg ?? PCStrings.sessionExpiredDescription
        case .consentOperationFailed(let msg): return msg
        case .uploadFailed(let msg): return msg ?? PCStrings.uploadFailedGeneric
        }
    }

    public var debugDescription: String {
        switch self {
        case .unauthorized(let msg): return "unauthorized: \(msg ?? "-")"
        case .forbidden(let msg): return "forbidden: \(msg ?? "-")"
        case .notFound(let msg): return "notFound: \(msg ?? "-")"
        case .validationError(let msg): return "validationError: \(msg ?? "-")"
        case .serverError(let code, let msg): return "serverError(\(code)): \(msg ?? "-")"
        case .networkError(let msg): return "networkError: \(msg)"
        case .decodingError(let msg): return "decodingError: \(msg)"
        case .invalidToken(let msg): return "invalidToken: \(msg)"
        case .missingOrgOrWorkspace: return "missingOrgOrWorkspace"
        case .refreshFailed(let msg): return "refreshFailed: \(msg ?? "-")"
        case .consentOperationFailed(let msg): return "consentOperationFailed: \(msg)"
        case .uploadFailed(let msg): return "uploadFailed: \(msg ?? "-")"
        }
    }

    public var httpStatus: Int? {
        switch self {
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .validationError: return 422
        case .serverError(let code, _): return code
        default: return nil
        }
    }
}

/// The refresh token is dead (expired, revoked, already used) and the person
/// has to sign in again. Every request after this fails with it without
/// touching the network, and `onError` has already been told once.
public struct PrivacyCenterSessionExpiredError: LocalizedError, Sendable, Equatable {
    public init() {}
    public var errorDescription: String? { PCStrings.sessionExpiredDescription }
}

/// A refresh failed transiently (network, 5xx) and the next attempt is held
/// back until the backoff window closes, so pollers cannot hammer `/otp/refresh`.
public struct PrivacyCenterRefreshBackoffError: LocalizedError, Sendable, Equatable {
    public init() {}
    public var errorDescription: String? { PCStrings.someThingWentWrong }
}

/// A server error code the consent manager turns into its own message
/// (React `ConsentApiError`, api/actions.ts).
public enum ConsentApiErrorCode: String, Sendable {
    case nominatorNotFound = "NOMINATOR_NOT_FOUND"
    case nomineeMustSpecifyNominator = "NOMINEE_MUST_SPECIFY_NOMINATOR"

    static func from(_ error: Error) -> ConsentApiErrorCode? {
        let text: String
        if let api = error as? PrivacyCenterAPIError {
            text = api.debugDescription
        } else {
            text = String(describing: error)
        }
        if text.contains("nominator_not_found") { return .nominatorNotFound }
        if text.contains("nominee_must_specify_nominator") { return .nomineeMustSpecifyNominator }
        return nil
    }
}

func isSilentPrivacyCenterError(_ error: Error) -> Bool {
    isCancellationError(error) || error is PrivacyCenterSessionExpiredError || error is PrivacyCenterRefreshBackoffError
}
