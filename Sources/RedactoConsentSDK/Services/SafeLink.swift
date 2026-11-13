import Foundation

/// The links the SDK renders or hands to the system are web pages, plus the
/// mail and phone links it builds itself. A notice config or an API response
/// naming any other scheme (a custom app scheme, javascript:, file:) gets no
/// link at all, so a tenant's config cannot steer the host app into another app.
enum SafeLink {
    private static let webSchemes: Set<String> = ["http", "https"]
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    /// `string` as a URL when it is an absolute http(s) URL with a host.
    static func web(_ string: String?) -> URL? {
        guard let components = parsed(string),
              let scheme = components.scheme?.lowercased(),
              webSchemes.contains(scheme),
              !(components.host ?? "").isEmpty else { return nil }
        return components.url
    }

    /// True for an http:// URL to a host other than loopback: a request there
    /// would carry its bearer and refresh tokens in cleartext.
    static func isPlaintextRemote(_ string: String) -> Bool {
        guard let components = parsed(string), components.scheme?.lowercased() == "http" else { return false }
        return !loopbackHosts.contains((components.host ?? "").lowercased())
    }

    private static func parsed(_ string: String?) -> URLComponents? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return URLComponents(string: trimmed)
    }
}
