import Foundation

public actor TokenStore {
    private(set) var accessToken: String
    private(set) var refreshToken: String
    private(set) var organisationUuid: String?
    private(set) var workspaceUuid: String?
    private(set) var email: String?

    let baseUrl: String
    let onError: @Sendable (Error) -> Bool
    let updateTokens: (@Sendable (String, String?) -> Void)?
    /// When set, the store is in sandbox mode: it holds a static token that is
    /// never refreshed, and org/workspace come from the config, not a JWT.
    let sandbox: SandboxConfig?
    private let onSessionExpired: (@Sendable () -> Void)?

    private var refreshInFlight: Task<String, Error>?
    private var sessionGeneration = 0
    private let bufferSeconds: TimeInterval = 30
    private let urlSession: URLSession
    private let now: @Sendable () -> Date

    // OTP refresh circuit breaker (React lib/utils.ts, incident 2026-06-22).
    // A refresh token that failed terminally is remembered by value and never
    // presented again; a different value (the person signed in again) re-arms
    // it. Transient failures back off from 30s, doubling to 5 minutes.
    private var deadRefreshToken: String?
    private var transientFailureUntil: Date = .distantPast
    private var transientBackoff: TimeInterval = 0
    static let minBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 300
    private static let terminalStatuses: Set<Int> = [400, 401, 403, 422]

    public private(set) var isSessionExpired = false

    public init(
        baseUrl: String,
        accessToken: String,
        refreshToken: String,
        onError: @escaping @Sendable (Error) -> Bool,
        updateTokens: (@Sendable (String, String?) -> Void)? = nil,
        sandbox: SandboxConfig? = nil,
        urlSession: URLSession = .shared,
        onSessionExpired: (@Sendable () -> Void)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseUrl = baseUrl
        self.onError = onError
        self.updateTokens = updateTokens
        self.sandbox = sandbox
        self.urlSession = urlSession
        self.onSessionExpired = onSessionExpired
        self.now = now

        if let sandbox {
            // Sandbox: the credential is the static token; there is no refresh token
            // and org/workspace/contact come from the config, not a JWT.
            self.accessToken = sandbox.token
            self.refreshToken = ""
            self.organisationUuid = sandbox.organisationUuid
            self.workspaceUuid = sandbox.workspaceUuid
            self.email = sandbox.contact
        } else {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            if let payload = JWTDecoder.decode(accessToken) {
                self.organisationUuid = payload.organisationUuid
                self.workspaceUuid = payload.workspaceUuid
                self.email = PCJwt.contact(fromToken: accessToken) ?? payload.resolvedContact
            }
        }
    }

    /// Returns a `Bearer …` header value, refreshing the token first if it's near expiry.
    /// In sandbox mode there is no bearer/refresh — returns the static token verbatim.
    public func bearerHeader() async throws -> String {
        "Bearer \(try await rawToken())"
    }

    /// Returns the raw access token (no scheme prefix), refreshing first if it is
    /// missing or near expiry. In sandbox mode the static token is returned as-is.
    public func rawToken() async throws -> String {
        if sandbox != nil { return accessToken }
        if accessToken.isEmpty || isExpired(accessToken) {
            _ = try await ensureFresh()
        }
        return accessToken
    }

    public func currentBearer() -> String { "Bearer \(accessToken)" }
    public func currentRawToken() -> String { accessToken }
    public func currentRefreshToken() -> String { refreshToken }

    /// Force a token refresh. In sandbox mode this is a no-op that returns the
    /// static token — the sandbox token is never refreshed.
    public func forceRefresh() async throws -> String {
        if sandbox != nil { return accessToken }
        return try await ensureFresh()
    }

    public func currentOrgWorkspace() -> (org: String, ws: String)? {
        guard let org = organisationUuid, let ws = workspaceUuid else { return nil }
        return (org, ws)
    }

    public func currentEmail() -> String? { email }

    /// True while a refresh would be pointless: the refresh token in play
    /// already failed terminally, or a transient failure's backoff is open.
    public func isRefreshBlocked() -> Bool {
        if !refreshToken.isEmpty && refreshToken == deadRefreshToken { return true }
        return now() < transientFailureUntil
    }

    public func adopt(accessToken newAccessToken: String, refreshToken newRefreshToken: String, contact: String? = nil) {
        guard sandbox == nil else { return }
        sessionGeneration += 1
        refreshInFlight = nil
        accessToken = newAccessToken
        refreshToken = newRefreshToken
        let payload = JWTDecoder.decode(newAccessToken)
        if let payload {
            organisationUuid = payload.organisationUuid
            workspaceUuid = payload.workspaceUuid
        }
        email = contact ?? payload?.resolvedContact
        resetCircuit()
        isSessionExpired = false
        updateTokens?(newAccessToken, newRefreshToken)
    }

    /// The host handed in new tokens (React AuthContext re-syncs its props). A
    /// new refresh token means the person signed in again, so the expired state
    /// clears with it. The host already holds these, so it is not told of them.
    public func syncFromHost(accessToken newAccessToken: String, refreshToken newRefreshToken: String) {
        guard sandbox == nil else { return }
        var changed = false
        if !newAccessToken.isEmpty, newAccessToken != accessToken {
            accessToken = newAccessToken
            if let payload = JWTDecoder.decode(newAccessToken) {
                organisationUuid = payload.organisationUuid
                workspaceUuid = payload.workspaceUuid
                if let contact = PCJwt.contact(fromToken: newAccessToken) ?? payload.resolvedContact {
                    email = contact
                }
            }
            changed = true
        }
        if !newRefreshToken.isEmpty, newRefreshToken != refreshToken {
            refreshToken = newRefreshToken
            isSessionExpired = false
            changed = true
        }
        if changed {
            sessionGeneration += 1
            refreshInFlight = nil
        }
    }

    /// Sign out (React `signOutPrivacyCenter`): forget the session's tokens.
    /// The circuit breaker is deliberately kept, so a dead token the host still
    /// holds is not re-presented.
    public func clearSession() {
        guard sandbox == nil else { return }
        sessionGeneration += 1
        refreshInFlight = nil
        accessToken = ""
        refreshToken = ""
    }

    private func resetCircuit() {
        deadRefreshToken = nil
        transientFailureUntil = .distantPast
        transientBackoff = 0
    }

    private func ensureFresh() async throws -> String {
        if let dead = deadRefreshToken, refreshToken != dead {
            resetCircuit()
        }
        if !refreshToken.isEmpty && refreshToken == deadRefreshToken {
            throw PrivacyCenterSessionExpiredError()
        }
        if now() < transientFailureUntil {
            throw PrivacyCenterRefreshBackoffError()
        }
        if let inflight = refreshInFlight {
            return try await inflight.value
        }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw PrivacyCenterAPIError.refreshFailed("TokenStore deallocated") }
            return try await self.performRefresh()
        }
        refreshInFlight = task
        defer {
            if refreshInFlight == task {
                refreshInFlight = nil
            }
        }
        return try await task.value
    }

    private func expireSession(_ error: Error, deadToken: String?) -> Error {
        if let deadToken, !deadToken.isEmpty { deadRefreshToken = deadToken }
        _ = onError(error)
        if !isSessionExpired {
            isSessionExpired = true
            onSessionExpired?()
        }
        return PrivacyCenterSessionExpiredError()
    }

    private func noteTransientFailure(_ error: Error) -> Error {
        transientBackoff = min(max(transientBackoff * 2, Self.minBackoff), Self.maxBackoff)
        transientFailureUntil = now().addingTimeInterval(transientBackoff)
        _ = onError(error)
        return error
    }

    private func performRefresh() async throws -> String {
        guard let orgId = organisationUuid, let wsId = workspaceUuid else {
            throw expireSession(PrivacyCenterAPIError.missingOrgOrWorkspace, deadToken: nil)
        }
        let presented = refreshToken
        guard !presented.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw expireSession(PrivacyCenterAPIError.refreshFailed("No refresh token available"), deadToken: nil)
        }
        let path = "\(baseUrl)/public/organisations/\(orgId)/workspaces/\(wsId)/otp/refresh"
        guard let url = URL(string: path) else {
            throw noteTransientFailure(PrivacyCenterAPIError.networkError("Invalid refresh URL"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: String] = ["refresh_token": presented]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let generation = sessionGeneration

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            if generation != sessionGeneration { return "Bearer \(accessToken)" }
            if isCancellationError(error) { throw error }
            throw noteTransientFailure(PrivacyCenterAPIError.refreshFailed(error.localizedDescription))
        }
        guard generation == sessionGeneration else {
            return "Bearer \(accessToken)"
        }
        guard let http = response as? HTTPURLResponse else {
            throw noteTransientFailure(PrivacyCenterAPIError.networkError("No HTTP response"))
        }
        guard (200..<300).contains(http.statusCode) else {
            let error = PrivacyCenterAPIError.refreshFailed("HTTP \(http.statusCode)")
            if Self.terminalStatuses.contains(http.statusCode) {
                throw expireSession(error, deadToken: presented)
            }
            throw noteTransientFailure(error)
        }
        guard
            let parsed = try? EnvelopeDecoder.decode(OtpRefreshResponse.self, from: data),
            parsed.success != false,
            !parsed.accessToken.isEmpty
        else {
            throw expireSession(PrivacyCenterAPIError.refreshFailed("Refresh token expired or revoked"), deadToken: presented)
        }
        if isExpired(parsed.accessToken) {
            throw expireSession(PrivacyCenterAPIError.refreshFailed("New access token is already expired"), deadToken: presented)
        }
        accessToken = parsed.accessToken
        if let newRefresh = parsed.refreshToken, !newRefresh.isEmpty {
            refreshToken = newRefresh
        }
        if let payload = JWTDecoder.decode(parsed.accessToken) {
            organisationUuid = payload.organisationUuid
            workspaceUuid = payload.workspaceUuid
            if let resolved = PCJwt.contact(fromToken: parsed.accessToken) ?? payload.resolvedContact { email = resolved }
        }
        resetCircuit()
        isSessionExpired = false
        updateTokens?(accessToken, parsed.refreshToken)
        return "Bearer \(accessToken)"
    }

    private func isExpired(_ token: String) -> Bool {
        guard let payload = JWTDecoder.decode(token), let exp = payload.exp else { return false }
        let expiryDate = Date(timeIntervalSince1970: exp)
        return now().addingTimeInterval(bufferSeconds) >= expiryDate
    }
}

/// Reads the Privacy Center's own claims straight from the token, the way
/// React's `resolveContactFromJwt` / `decodeJwtToken` do.
enum PCJwt {
    static func claims(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// `contact || primary_email || user_data.primary_email || user_data.primary_mobile
    /// || user_data.org_user_id`: a mobile-only login still resolves to its phone.
    static func contact(fromToken token: String) -> String? {
        guard let claims = claims(token) else { return nil }
        let userData = claims["user_data"] as? [String: Any] ?? [:]
        for value in [claims["contact"], claims["primary_email"], userData["primary_email"], userData["primary_mobile"], userData["org_user_id"]] {
            if let text = value as? String, !text.trimmingCharacters(in: .whitespaces).isEmpty { return text }
        }
        return nil
    }

    static func string(_ key: String, in token: String) -> String? {
        guard let value = claims(token)?[key] as? String, !value.isEmpty else { return nil }
        return value
    }
}
