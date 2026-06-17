import Foundation

public actor PrivacyCenterHTTPClient {
    let baseUrl: String
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

    public init(baseUrl: String, tokenStore: TokenStore, urlSession: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.tokenStore = tokenStore
        self.urlSession = urlSession
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let request = try await buildRequest(method: "GET", path: path, queryItems: queryItems, body: nil, contentType: nil)
        return try await sendDecoded(request, as: type, retried: false)
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

    func postNoResponse<Body: Encodable>(_ path: String, queryItems: [URLQueryItem] = [], body: Body) async throws {
        let data = try encoder.encode(body)
        let request = try await buildRequest(method: "POST", path: path, queryItems: queryItems, body: data, contentType: "application/json")
        _ = try await sendData(request, retried: false)
    }

    func uploadMultipart<T: Decodable>(_ path: String, fileData: Data, filename: String, mimeType: String, as type: T.Type) async throws -> T {
        let builder = MultipartFormBuilder()
        let body = builder.body(filename: filename, mimeType: mimeType, fileData: fileData)
        let request = try await buildRequest(method: "POST", path: path, queryItems: [], body: body, contentType: builder.contentType)
        return try await sendDecoded(request, as: type, retried: false)
    }

    /// GET raw bytes (e.g. a PDF). Uses the same bearer + 401-refresh flow as the
    /// JSON helpers, but sets a custom `Accept` and returns the response body untouched.
    func downloadBinary(_ path: String, queryItems: [URLQueryItem] = [], accept: String) async throws -> Data {
        let request = try await buildRequest(method: "GET", path: path, queryItems: queryItems, body: nil, contentType: nil, accept: accept)
        return try await sendData(request, retried: false)
    }

    private func buildRequest(method: String, path: String, queryItems: [URLQueryItem], body: Data?, contentType: String?, accept: String = "application/json") async throws -> URLRequest {
        let urlString = baseUrl + path
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
        let token = try await tokenStore.rawToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func sendDecoded<T: Decodable>(_ request: URLRequest, as type: T.Type, retried: Bool) async throws -> T {
        let data = try await sendData(request, retried: retried)
        do {
            return try EnvelopeDecoder.decode(T.self, from: data, decoder: decoder)
        } catch {
            let raw = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw PrivacyCenterAPIError.decodingError("\(error). Response: \(raw)")
        }
    }

    private func sendData(_ originalRequest: URLRequest, retried: Bool) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: originalRequest)
            guard let http = response as? HTTPURLResponse else {
                throw PrivacyCenterAPIError.networkError("No HTTP response")
            }
            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                if retried {
                    throw PrivacyCenterAPIError.unauthorized(extractMessage(from: data))
                }
                _ = try await tokenStore.forceRefresh()
                var retryRequest = originalRequest
                let newToken = await tokenStore.currentRawToken()
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await sendData(retryRequest, retried: true)
            case 403:
                throw PrivacyCenterAPIError.forbidden(extractMessage(from: data))
            case 404:
                throw PrivacyCenterAPIError.notFound(extractMessage(from: data))
            case 422:
                throw PrivacyCenterAPIError.validationError(extractMessage(from: data))
            default:
                throw PrivacyCenterAPIError.serverError(http.statusCode, extractMessage(from: data))
            }
        } catch let err as PrivacyCenterAPIError {
            throw err
        } catch {
            throw PrivacyCenterAPIError.networkError(error.localizedDescription)
        }
    }

    private func extractMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = json["message"] as? String { return msg }
            if let msg = json["detail"] as? String { return msg }
            if let nested = json["detail"] as? [String: Any], let msg = nested["message"] as? String { return msg }
        }
        return String(data: data, encoding: .utf8)
    }
}
