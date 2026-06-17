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

public enum PrivacyCenterAPIError: LocalizedError, Sendable {
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

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg ?? "Unauthorized"
        case .forbidden(let msg): return msg ?? "Forbidden"
        case .notFound(let msg): return msg ?? "Not Found"
        case .validationError(let msg): return msg ?? "Validation error"
        case .serverError(let code, let msg): return msg ?? "Server error (\(code))"
        case .networkError(let msg): return msg
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .invalidToken(let msg): return "Invalid token: \(msg)"
        case .missingOrgOrWorkspace: return "Missing organization or workspace UUID in token"
        case .refreshFailed(let msg): return msg ?? "Token refresh failed"
        case .consentOperationFailed(let msg): return msg
        case .uploadFailed(let msg): return msg ?? "Upload failed"
        }
    }
}
