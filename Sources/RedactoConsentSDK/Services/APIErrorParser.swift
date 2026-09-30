import Foundation

/// Reads a non-2xx body the way the React SDK's `shared/api-errors.ts` does.
///
/// Message, in order: the body's `message`, then the one inside `detail`; when
/// the body parsed but carried neither, a status hint; else the endpoint's
/// fallback. A server string is used as sent, empty included, as `??` does on
/// the web.
enum APIErrorParser {
    struct Parsed {
        let status: Int
        let code: String?
        let message: String
        /// The server's `should_request_new`, when it sent one: the code is dead
        /// and a fresh one is needed (an expired OTP, not a wrong one).
        let shouldRequestNew: Bool?

        var error: RedactoAPIError {
            .api(status: status, code: code, message: message)
        }
    }

    static func parse(status: Int, data: Data, fallback: String) -> Parsed {
        let body = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let object = body as? [String: Any]
        let fromDetail = extract(fromDetail: object?["detail"])
        let serverMessage = (object?["message"] as? String) ?? fromDetail.message
        let message = serverMessage
            ?? (body != nil ? statusFallback(status) : nil)
            ?? fallback
        let code = (object?["error_code"] as? String) ?? fromDetail.code
        return Parsed(
            status: status,
            code: code,
            message: message,
            shouldRequestNew: object?["should_request_new"] as? Bool
        )
    }

    static func error(status: Int, data: Data, fallback: String) -> RedactoAPIError {
        parse(status: status, data: data, fallback: fallback).error
    }

    static func statusFallback(_ status: Int) -> String? {
        if status == 401 {
            return APIStatusFallback.unauthorized
        }
        if status == 403 {
            return APIStatusFallback.forbidden
        }
        if status >= 500 {
            return APIStatusFallback.serverFailure
        }
        return nil
    }

    /// `detail` arrives as our `{message, error_code}`, Ninja's auto-401
    /// `{detail: "..."}`, a bare string, or Ninja's auto-422 array (no single
    /// message, so nothing is taken from it).
    private static func extract(fromDetail detail: Any?) -> (message: String?, code: String?) {
        if let text = detail as? String {
            return (text, nil)
        }
        if let object = detail as? [String: Any] {
            return ((object["message"] as? String) ?? (object["detail"] as? String), object["error_code"] as? String)
        }
        return (nil, nil)
    }
}
