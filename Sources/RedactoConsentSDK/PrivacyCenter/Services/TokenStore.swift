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

    private var refreshInFlight: Task<String, Error>?
    private let bufferSeconds: TimeInterval = 30
    private let urlSession: URLSession

    public init(
        baseUrl: String,
        accessToken: String,
        refreshToken: String,
        onError: @escaping @Sendable (Error) -> Bool,
        updateTokens: (@Sendable (String, String?) -> Void)? = nil,
        urlSession: URLSession = .shared
    ) {
        self.baseUrl = baseUrl
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.onError = onError
        self.updateTokens = updateTokens
        self.urlSession = urlSession

        if let payload = JWTDecoder.decode(accessToken) {
            self.organisationUuid = payload.organisationUuid
            self.workspaceUuid = payload.workspaceUuid
            self.email = payload.resolvedContact
        }
    }

    /// Returns a `Bearer …` header value, refreshing the token first if it's near expiry.
    public func bearerHeader() async throws -> String {
        if isExpired(accessToken) {
            _ = try await ensureFresh()
        }
        return "Bearer \(accessToken)"
    }

    /// Returns the raw access token (no scheme prefix), refreshing first if near expiry.
    public func rawToken() async throws -> String {
        if isExpired(accessToken) {
            _ = try await ensureFresh()
        }
        return accessToken
    }

    public func currentBearer() -> String { "Bearer \(accessToken)" }
    public func currentRawToken() -> String { accessToken }

    public func forceRefresh() async throws -> String {
        try await ensureFresh()
    }

    public func currentOrgWorkspace() -> (org: String, ws: String)? {
        guard let org = organisationUuid, let ws = workspaceUuid else { return nil }
        return (org, ws)
    }

    public func currentEmail() -> String? { email }

    private func ensureFresh() async throws -> String {
        if let inflight = refreshInFlight {
            return try await inflight.value
        }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw PrivacyCenterAPIError.refreshFailed("TokenStore deallocated") }
            return try await self.performRefresh()
        }
        refreshInFlight = task
        defer { refreshInFlight = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let orgId = organisationUuid, let wsId = workspaceUuid else {
            let err = PrivacyCenterAPIError.missingOrgOrWorkspace
            _ = onError(err)
            throw err
        }
        let path = "\(baseUrl)/public/organisations/\(orgId)/workspaces/\(wsId)/otp/refresh"
        guard let url = URL(string: path) else {
            let err = PrivacyCenterAPIError.networkError("Invalid refresh URL")
            _ = onError(err)
            throw err
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: String] = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                let err = PrivacyCenterAPIError.networkError("No HTTP response")
                _ = onError(err)
                throw err
            }
            guard (200..<300).contains(http.statusCode) else {
                let err = PrivacyCenterAPIError.refreshFailed("HTTP \(http.statusCode)")
                _ = onError(err)
                throw err
            }
            let parsed: OtpRefreshResponse
            do {
                parsed = try EnvelopeDecoder.decode(OtpRefreshResponse.self, from: data)
            } catch {
                let err = PrivacyCenterAPIError.decodingError(String(describing: error))
                _ = onError(err)
                throw err
            }
            self.accessToken = parsed.accessToken
            if let newRefresh = parsed.refreshToken {
                self.refreshToken = newRefresh
            }
            if let payload = JWTDecoder.decode(parsed.accessToken) {
                self.organisationUuid = payload.organisationUuid
                self.workspaceUuid = payload.workspaceUuid
                if let resolved = payload.resolvedContact { self.email = resolved }
            }
            updateTokens?(self.accessToken, parsed.refreshToken)
            return "Bearer \(self.accessToken)"
        } catch let err as PrivacyCenterAPIError {
            throw err
        } catch {
            let wrapped = PrivacyCenterAPIError.refreshFailed(error.localizedDescription)
            _ = onError(wrapped)
            throw wrapped
        }
    }

    private func isExpired(_ token: String) -> Bool {
        guard let payload = JWTDecoder.decode(token), let exp = payload.exp else { return false }
        let expiryDate = Date(timeIntervalSince1970: exp)
        return Date().addingTimeInterval(bufferSeconds) >= expiryDate
    }
}
