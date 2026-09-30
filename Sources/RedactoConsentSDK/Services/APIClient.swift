import Foundation

/// Errors returned by the Redacto Consent API.
public enum RedactoAPIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case alreadyConsented
    case invalidRequest(String)
    case validationError(String)
    case serverError
    case networkError(Error)
    case decodingError(Error)
    case invalidToken
    case api(status: Int, code: String?, message: String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized: Invalid or expired token"
        case .forbidden:
            return "Forbidden: Access denied"
        case .notFound:
            return "Notice not found"
        case .alreadyConsented:
            return "User has already provided consent"
        case .invalidRequest(let message):
            return message
        case .validationError(let message):
            return message
        case .serverError:
            return "Server error: Please try again later"
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidToken:
            return "Invalid access token"
        case .api(_, _, let message):
            return message
        }
    }

    public var statusCode: Int? {
        switch self {
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .alreadyConsented: return 409
        case .serverError: return 500
        case .invalidRequest: return 400
        case .validationError: return 422
        case .api(let status, _, _): return status
        default: return nil
        }
    }

    public var errorCode: String? {
        if case .api(_, let code, _) = self {
            return code
        }
        return nil
    }
}

/// Low-level URLSession wrapper for API requests.
enum APIClient {
    private static let session = URLSession.shared
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static func encode<Body: Encodable>(_ body: Body) throws -> Data {
        try encoder.encode(body)
    }

    /// Perform a GET request and decode the response.
    static func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        fallbackMessage: String = APIErrorFallback.request
    ) async throws -> T {
        let request = makeRequest(url: url, method: "GET", headers: headers, body: nil)
        let data = try await send(request, fallbackMessage: fallbackMessage)
        return try decode(T.self, from: data)
    }

    /// Perform a GET request and return raw data (for caching).
    static func getRawData(
        url: URL,
        headers: [String: String] = [:],
        fallbackMessage: String = APIErrorFallback.request
    ) async throws -> Data {
        let request = makeRequest(url: url, method: "GET", headers: headers, body: nil)
        return try await send(request, fallbackMessage: fallbackMessage)
    }

    /// Perform a POST request with an Encodable body.
    static func post<Body: Encodable>(
        url: URL,
        headers: [String: String] = [:],
        body: Body,
        fallbackMessage: String = APIErrorFallback.request
    ) async throws {
        let request = makeRequest(url: url, method: "POST", headers: headers, body: try encoder.encode(body))
        _ = try await send(request, fallbackMessage: fallbackMessage)
    }

    /// Perform a POST request and decode the response.
    static func postWithResponse<Body: Encodable, T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        body: Body,
        responseType: T.Type,
        fallbackMessage: String = APIErrorFallback.request
    ) async throws -> T {
        let request = makeRequest(url: url, method: "POST", headers: headers, body: try encoder.encode(body))
        let data = try await send(request, fallbackMessage: fallbackMessage)
        return try decode(T.self, from: data)
    }

    static func postData(
        url: URL,
        headers: [String: String] = [:],
        body: Data,
        fallbackMessage: String = APIErrorFallback.request
    ) async throws -> Data {
        let request = makeRequest(url: url, method: "POST", headers: headers, body: body)
        return try await send(request, fallbackMessage: fallbackMessage)
    }

    static func postForStatus(
        url: URL,
        headers: [String: String] = [:],
        body: Data
    ) async throws -> (data: Data, status: Int?) {
        let request = makeRequest(url: url, method: "POST", headers: headers, body: body)
        let (data, response) = try await session.data(for: request, delegate: SameHostRedirect.shared)
        return (data, (response as? HTTPURLResponse)?.statusCode)
    }

    static func postIdempotent(
        url: URL,
        headers: [String: String] = [:],
        body: Data,
        fallbackMessage: String,
        keys: IdempotencyKeys = .shared
    ) async throws {
        let request = makeRequest(url: url, method: "POST", headers: headers, body: body)
        let (data, response) = try await keys.withKey(url: url.absoluteString, body: body) { keyHeaders in
            var keyed = request
            for (key, value) in keyHeaders {
                keyed.setValue(value, forHTTPHeaderField: key)
            }
            return try await session.data(for: keyed, delegate: SameHostRedirect.shared)
        }
        try validateResponse(response, data: data, fallbackMessage: fallbackMessage)
    }

    // MARK: - Private

    private static func makeRequest(url: URL, method: String, headers: [String: String], body: Data?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }

    private static func send(_ request: URLRequest, fallbackMessage: String) async throws -> Data {
        let (data, response) = try await session.data(for: request, delegate: SameHostRedirect.shared)
        try validateResponse(response, data: data, fallbackMessage: fallbackMessage)
        return data
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RedactoAPIError.decodingError(error)
        }
    }

    private static func validateResponse(_ response: URLResponse, data: Data, fallbackMessage: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedactoAPIError.networkError(
                NSError(domain: "RedactoAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIErrorParser.error(status: httpResponse.statusCode, data: data, fallback: fallbackMessage)
        }
    }
}
