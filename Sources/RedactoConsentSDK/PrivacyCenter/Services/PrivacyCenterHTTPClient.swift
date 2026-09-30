import Foundation

enum PCHost: Sendable {
    case consent
    case ledger
}

public actor PrivacyCenterHTTPClient {
    let baseUrl: String
    let ledgerBaseUrl: String?
    let tokenStore: TokenStore
    let urlSession: URLSession

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    public init(baseUrl: String, ledgerBaseUrl: String? = nil, tokenStore: TokenStore, urlSession: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = ledgerBaseUrl
        self.tokenStore = tokenStore
        self.urlSession = urlSession
    }

    func absoluteUrl(_ path: String, host: PCHost) -> String {
        switch host {
        case .consent: return baseUrl + path
        case .ledger: return (ledgerBaseUrl ?? baseUrl) + path
        }
    }

    func get<T: Decodable>(_ path: String, host: PCHost = .consent, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let request = try await buildRequest(method: "GET", host: host, path: path, queryItems: queryItems, body: nil, contentType: nil)
        return try await sendDecoded(request, as: type, retried: false)
    }

    func postData(_ path: String, host: PCHost, queryItems: [URLQueryItem] = [], body: Data, headers: [String: String] = [:]) async throws -> Data {
        try await postDataResponse(path, host: host, queryItems: queryItems, body: body, headers: headers).0
    }

    func postDataResponse(_ path: String, host: PCHost, queryItems: [URLQueryItem] = [], body: Data, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        let request = try await buildRequest(method: "POST", host: host, path: path, queryItems: queryItems, body: body, contentType: "application/json", headers: headers)
        let (data, response) = try await sendResponse(request, retried: false)
        return (data, response)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], body: Body, as type: T.Type) async throws -> T {
        let data = try encoder.encode(body)
        let request = try await buildRequest(method: "POST", path: path, queryItems: queryItems, body: data, contentType: "application/json")
        return try await sendDecoded(request, as: type, retried: false)
    }

    func postEmpty<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let body: [String: String] = [:]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try await buildRequest(method: "POST", path: path, queryItems: queryItems, body: data, contentType: "application/json")
        return try await sendDecoded(request, as: type, retried: false)
    }

    /// A body-less write (notification read/acknowledge). React sends these
    /// with no payload; the servers answer `{ message }`.
    func send<T: Decodable>(_ method: String, _ path: String, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let request = try await buildRequest(method: method, path: path, queryItems: queryItems, body: nil, contentType: "application/json")
        return try await sendDecoded(request, as: type, retried: false)
    }

    func postNoResponse<Body: Encodable>(_ path: String, queryItems: [URLQueryItem] = [], body: Body) async throws {
        let data = try encoder.encode(body)
        let request = try await buildRequest(method: "POST", path: path, queryItems: queryItems, body: data, contentType: "application/json")
        _ = try await sendData(request, retried: false)
    }

    func uploadMultipart<T: Decodable>(_ path: String, fileData: Data, filename: String, mimeType: String, payload: Data, as type: T.Type) async throws -> T {
        let builder = MultipartFormBuilder()
        let body = builder.body(filename: filename, mimeType: mimeType, fileData: fileData, payload: payload)
        // Sandbox: every supplied identifier rides the upload URL as query items
        // (the server has no subject header and reads them from the query string,
        // same as GET reads); the JWT path sends no extra query items.
        let queryItems: [URLQueryItem] = await tokenStore.sandbox.map { $0.identityQueryItems } ?? []
        let request = try await buildRequest(method: "POST", path: path, queryItems: queryItems, body: body, contentType: builder.contentType)
        return try await sendDecoded(request, as: type, retried: false)
    }

    /// GET raw bytes (e.g. a PDF). Uses the same bearer + 401-refresh flow as the
    /// JSON helpers, but sets a custom `Accept` and returns the response body untouched.
    func downloadBinary(_ path: String, host: PCHost = .consent, queryItems: [URLQueryItem] = [], accept: String) async throws -> Data {
        let request = try await buildRequest(method: "GET", host: host, path: path, queryItems: queryItems, body: nil, contentType: nil, accept: accept)
        return try await sendData(request, retried: false)
    }

    private func buildRequest(method: String, host: PCHost = .consent, path: String, queryItems: [URLQueryItem], body: Data?, contentType: String?, accept: String = "application/json", headers: [String: String] = [:]) async throws -> URLRequest {
        let urlString = absoluteUrl(path, host: host)
        guard var components = URLComponents(string: urlString) else {
            throw PrivacyCenterAPIError.networkError("Invalid URL: \(urlString)")
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw PrivacyCenterAPIError.networkError("Invalid URL: \(urlString)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body { request.httpBody = body }
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.setValue(accept, forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let sandbox = await tokenStore.sandbox {
            // Sandbox: the single X-Consent-Token credential (raw, no Bearer). Its
            // presence marks the request as environment=test. There is no subject
            // header — the acting identity travels in the query/body.
            request.setValue(sandbox.token, forHTTPHeaderField: SandboxConfig.tokenHeader)
        } else {
            let token = try await tokenStore.rawToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func sendDecoded<T: Decodable>(_ request: URLRequest, as type: T.Type, retried: Bool) async throws -> T {
        let data = try await sendData(request, retried: retried)
        do {
            return try EnvelopeDecoder.decode(T.self, from: data, decoder: decoder)
        } catch {
            // Kept for `debugDescription` only; people see a generic message.
            let raw = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw PrivacyCenterAPIError.decodingError("\(error). Response: \(raw)")
        }
    }

    private func sendData(_ originalRequest: URLRequest, retried: Bool) async throws -> Data {
        try await sendResponse(originalRequest, retried: retried).0
    }

    private func sendResponse(_ originalRequest: URLRequest, retried: Bool) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: originalRequest, delegate: SameHostRedirect.shared)
            guard let http = response as? HTTPURLResponse else {
                throw PrivacyCenterAPIError.networkError("No HTTP response")
            }
            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 401:
                // Sandbox: the static token is never refreshed — a 401 fails
                // immediately, no retry loop.
                let isSandbox = await tokenStore.sandbox != nil
                if retried || isSandbox {
                    throw PrivacyCenterAPIError.unauthorized(extractMessage(from: data, status: http.statusCode))
                }
                _ = try await tokenStore.forceRefresh()
                var retryRequest = originalRequest
                let newToken = await tokenStore.currentRawToken()
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await sendResponse(retryRequest, retried: true)
            case 403:
                throw PrivacyCenterAPIError.forbidden(extractMessage(from: data, status: http.statusCode))
            case 404:
                throw PrivacyCenterAPIError.notFound(extractMessage(from: data, status: http.statusCode))
            case 422:
                throw PrivacyCenterAPIError.validationError(extractMessage(from: data, status: http.statusCode))
            default:
                throw PrivacyCenterAPIError.serverError(http.statusCode, extractMessage(from: data, status: http.statusCode))
            }
        } catch let err as PrivacyCenterAPIError {
            throw err
        } catch let err as PrivacyCenterSessionExpiredError {
            throw err
        } catch let err as PrivacyCenterRefreshBackoffError {
            throw err
        } catch {
            if isCancellationError(error) { throw error }
            throw PrivacyCenterAPIError.networkError(error.localizedDescription)
        }
    }

    static func extractMessage(from data: Data, status: Int) -> String? {
        guard case .api(_, _, let message) = APIErrorParser.error(status: status, data: data, fallback: "") else {
            return nil
        }
        return message.isEmpty ? nil : message
    }

    private func extractMessage(from data: Data, status: Int) -> String? {
        Self.extractMessage(from: data, status: status)
    }
}
