import Foundation
import os

/// Where requests go, resolved from the `baseUrl` and `ledgerBaseUrl` an
/// integrator passes (`NoticeBaseUrl.resolve`).
struct NoticeEndpoints: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        /// `baseUrl` is the API host (`https://api.redacto.io`): the consent
        /// server and the ledger are the services under it.
        case host
        /// `baseUrl` is the consent server URL (`…/consent`), blank, or not an
        /// absolute URL: both values are used exactly as passed, as before.
        case legacy
    }

    let mode: Mode
    /// The consent server URL: `{host}/consent` in host mode.
    let baseUrl: String?
    /// The ledger URL: `{host}/consent-ledger` in host mode, else the
    /// `ledgerBaseUrl` passed.
    let ledgerBaseUrl: String?
    /// The API host, in host mode.
    let host: String?

    func consentServer() throws -> String {
        guard let server = NoticeBaseUrl.configured(baseUrl) else { throw NoticeBaseUrl.missingBaseUrl }
        return server
    }

    func read(specificUuid: String?, isSandbox: Bool) throws -> String {
        if let ledger = NoticeBaseUrl.configured(ledgerBaseUrl), NoticeBaseUrl.configured(specificUuid) == nil, !isSandbox {
            return ledger
        }
        return try consentServer()
    }

    func write() throws -> String {
        if let ledger = NoticeBaseUrl.configured(ledgerBaseUrl) { return ledger }
        return try consentServer()
    }

    /// Sandbox audio stays on the consent server only in legacy mode; under the
    /// API host it comes from the ledger, as a JWT session's does.
    func audio(isSandbox: Bool) throws -> String {
        isSandbox && mode == .legacy ? try consentServer() : try write()
    }
}

enum NoticeBaseUrl {
    static let consentPath = "/consent"
    static let ledgerPath = "/consent-ledger"
    static let userServicePath = "/user/api/0"

    /// A host the integrator set: trimmed, blank as unset, and without a
    /// trailing `/`, so appending a path never doubles the slash.
    static func configured(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    static let missingBaseUrl = RedactoAPIError.invalidRequest("baseUrl is required")

    /// An absolute http(s) URL: scheme and authority, then an optional path.
    private static let absoluteHttpUrl = #"^https?://(?:\[[0-9a-f:.]+\]|[^\s/?#@:\[\]]+)(?::\d+)?(?:/[^\s?#]*)?$"#

    static func isAbsoluteHttpUrl(_ value: String) -> Bool {
        // Matched lowercased: the iOS 17 runtime applies neither
        // `.caseInsensitive` nor an inline `(?i)` here, so `HTTPS://` would not
        // match. The value the SDK uses is not changed.
        value.lowercased().range(of: absoluteHttpUrl, options: .regularExpression) != nil
    }

    /// `value` trimmed and without trailing `/`.
    private static func trimmed(_ value: String?) -> String {
        var trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    /// The path of an absolute http(s) URL (`""` when it has none), or `nil`
    /// for anything else.
    private static func path(ofAbsoluteUrl url: String) -> Substring? {
        guard isAbsoluteHttpUrl(url), let scheme = url.range(of: "://") else { return nil }
        let authorityAndPath = url[scheme.upperBound...]
        return authorityAndPath.firstIndex(of: "/").map { authorityAndPath[$0...] } ?? ""
    }

    /// `baseUrl` trimmed, and its path when it names the API host: an absolute
    /// http(s) URL whose path does not end in `/consent`.
    private static func apiHost(_ baseUrl: String?) -> (url: String, path: Substring)? {
        let url = trimmed(baseUrl)
        guard let path = path(ofAbsoluteUrl: url), !path.hasSuffix(consentPath) else { return nil }
        return (url, path)
    }

    /// Host mode when `baseUrl` is an absolute http(s) URL whose path does not
    /// end in `/consent`; a trailing `/consent-ledger` is dropped to get the
    /// host, and the ledger is always the one under it. Anything else is legacy
    /// mode, where both values pass through untouched. Pass it the values as
    /// the integrator gave them, never its own output, which would read as
    /// legacy mode.
    static func resolve(baseUrl: String?, ledgerBaseUrl: String?) -> NoticeEndpoints {
        guard let given = apiHost(baseUrl) else {
            return NoticeEndpoints(mode: .legacy, baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl, host: nil)
        }
        let host = given.path.hasSuffix(ledgerPath) ? String(given.url.dropLast(ledgerPath.count)) : given.url
        return NoticeEndpoints(mode: .host, baseUrl: host + consentPath, ledgerBaseUrl: host + ledgerPath, host: host)
    }

    /// The forms of these values that are deprecated, in a fixed order.
    static func deprecations(baseUrl: String?, ledgerBaseUrl: String?) -> [BaseUrlDeprecation] {
        var found: [BaseUrlDeprecation] = []
        if path(ofAbsoluteUrl: trimmed(baseUrl))?.hasSuffix(consentPath) == true {
            found.append(.consentServerUrl)
        }
        if configured(ledgerBaseUrl) != nil {
            found.append(apiHost(baseUrl) == nil ? .ledgerBaseUrl : .ledgerIgnored)
        }
        return found
    }

    /// `resolve`, reporting any deprecated form once per process.
    static func endpoints(
        baseUrl: String?,
        ledgerBaseUrl: String?,
        log: BaseUrlDeprecationLog = .shared
    ) -> NoticeEndpoints {
        log.report(deprecations(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl))
        return resolve(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl)
    }

    /// The consent server for a `baseUrl` that is never nil: as passed in
    /// legacy mode.
    static func consentServerUrl(_ baseUrl: String) -> String {
        endpoints(baseUrl: baseUrl, ledgerBaseUrl: nil).baseUrl ?? baseUrl
    }

    /// There is no built-in host: every request goes where the integrator said,
    /// so a production app can never silently reach a non-production server.
    static func consentServer(_ baseUrl: String?) throws -> String {
        try endpoints(baseUrl: baseUrl, ledgerBaseUrl: nil).consentServer()
    }

    static func read(ledgerBaseUrl: String?, baseUrl: String?, specificUuid: String?, isSandbox: Bool) throws -> String {
        try endpoints(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl).read(specificUuid: specificUuid, isSandbox: isSandbox)
    }

    static func write(ledgerBaseUrl: String?, baseUrl: String?) throws -> String {
        try endpoints(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl).write()
    }

    static func audio(ledgerBaseUrl: String?, baseUrl: String?, isSandbox: Bool) throws -> String {
        try endpoints(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl).audio(isSandbox: isSandbox)
    }

    static func publicUrl(host: String, organisationUuid: String, workspaceUuid: String, path: String) -> String {
        let root = host.hasSuffix("/") ? String(host.dropLast()) : host
        return "\(root)/public/organisations/\(organisationUuid)/workspaces/\(workspaceUuid)\(path)"
    }

    /// `string` as a request URL, with `queryItems` when there are any. Throws
    /// rather than trapping when a host or id makes it unparseable.
    static func url(_ string: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: string) else {
            throw RedactoAPIError.invalidRequest("Invalid request URL: \(string)")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw RedactoAPIError.invalidRequest("Invalid request URL: \(string)")
        }
        return url
    }
}

/// A `baseUrl` or `ledgerBaseUrl` form that is deprecated or has no effect.
enum BaseUrlDeprecation: CaseIterable, Sendable {
    /// `baseUrl` is the consent server URL (`…/consent`).
    case consentServerUrl
    /// `ledgerBaseUrl` is set and read, as `baseUrl` is not the API host.
    case ledgerBaseUrl
    /// `ledgerBaseUrl` is set alongside the API host, which ignores it.
    case ledgerIgnored
    /// `slug` is passed to the Privacy Center, which ignores it.
    case slug

    var message: String {
        switch self {
        case .slug:
            return "[Redacto] slug is deprecated and ignored. The Privacy Center reads the organisation from the access token, or from organisationUuid and workspaceUuid. Remove slug."
        case .consentServerUrl:
            return "[Redacto] baseUrl is the consent server URL (ending in /consent), which is deprecated. Pass the API host instead; the SDK reaches the consent server and the ledger under it."
        case .ledgerBaseUrl:
            return "[Redacto] ledgerBaseUrl is deprecated. Pass the Redacto API host as baseUrl instead; the SDK then reaches the consent server and the ledger under it."
        case .ledgerIgnored:
            return "[Redacto] ledgerBaseUrl is ignored because baseUrl is the API host; the SDK reaches the ledger under that host. Remove ledgerBaseUrl."
        }
    }
}

/// Logs each `BaseUrlDeprecation` once per process, so a view that re-renders
/// does not repeat it. Never throws.
final class BaseUrlDeprecationLog: @unchecked Sendable {
    static let shared = BaseUrlDeprecationLog()

    private static let logger = Logger(subsystem: "io.redacto.RedactoConsentSDK", category: "baseUrl")

    static let unifiedLog: @Sendable (String) -> Void = { message in
        logger.warning("\(message, privacy: .public)")
    }

    private let lock = NSLock()
    private var reported: Set<BaseUrlDeprecation> = []
    private let sink: @Sendable (String) -> Void

    init(sink: @escaping @Sendable (String) -> Void = BaseUrlDeprecationLog.unifiedLog) {
        self.sink = sink
    }

    func report(_ deprecations: [BaseUrlDeprecation]) {
        for deprecation in deprecations {
            lock.lock()
            let isNew = reported.insert(deprecation).inserted
            lock.unlock()
            if isNew {
                sink(deprecation.message)
            }
        }
    }
}
