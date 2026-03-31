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
        default: return nil
        }
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
        return encoder
    }()

    /// Perform a GET request and decode the response.
    static func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RedactoAPIError.decodingError(error)
        }
    }

    /// Perform a GET request and return raw data (for caching).
    static func getRawData(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    /// Perform a POST request with an Encodable body.
    static func post<Body: Encodable>(
        url: URL,
        headers: [String: String] = [:],
        body: Body
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    /// Perform a POST request and decode the response.
    static func postWithResponse<Body: Encodable, T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        body: Body,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RedactoAPIError.decodingError(error)
        }
    }

    // MARK: - Private

    private static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedactoAPIError.networkError(
                NSError(domain: "RedactoAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }

        let statusCode = httpResponse.statusCode
        guard (200...299).contains(statusCode) else {
            switch statusCode {
            case 400:
                let message = parseErrorMessage(from: data) ?? "Invalid request data"
                throw RedactoAPIError.invalidRequest(message)
            case 401:
                throw RedactoAPIError.unauthorized
            case 403:
                throw RedactoAPIError.forbidden
            case 404:
                throw RedactoAPIError.notFound
            case 409:
                throw RedactoAPIError.alreadyConsented
            case 422:
                let message = parseErrorMessage(from: data) ?? "Validation error: Please check your input"
                throw RedactoAPIError.validationError(message)
            default:
                if statusCode >= 500 {
                    throw RedactoAPIError.serverError
                }
                let message = parseErrorMessage(from: data) ?? "Request failed with status \(statusCode)"
                throw RedactoAPIError.invalidRequest(message)
            }
        }
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let message: String?
            let detail: ErrorDetail?

            struct ErrorDetail: Decodable {
                let message: String?
            }
        }

        guard let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.detail?.message ?? errorResponse.message
    }
}
