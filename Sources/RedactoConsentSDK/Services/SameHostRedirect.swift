import Foundation

/// URLSession drops `Authorization` when it follows a redirect, where a browser
/// keeps it for a same-origin one. The consent server redirects some paths to
/// their trailing-slash form (`/notifications` → `/notifications/`), so without
/// this the retried request arrives with no credential and fails 401.
final class SameHostRedirect: NSObject, URLSessionTaskDelegate {
    static let shared = SameHostRedirect()
    private static let carriedHeaders = ["Authorization", SandboxConfig.tokenHeader]

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.carryingCredentials(from: task.originalRequest, to: request))
    }

    static func carryingCredentials(from original: URLRequest?, to redirected: URLRequest) -> URLRequest {
        guard let original,
              original.url?.host == redirected.url?.host,
              original.url?.scheme == redirected.url?.scheme,
              original.url?.port == redirected.url?.port else { return redirected }
        var next = redirected
        for header in carriedHeaders where next.value(forHTTPHeaderField: header) == nil {
            if let value = original.value(forHTTPHeaderField: header) {
                next.setValue(value, forHTTPHeaderField: header)
            }
        }
        return next
    }
}
