import Foundation

enum NoticeBaseUrl {
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

    /// There is no built-in host: every request goes where the integrator said,
    /// so a production app can never silently reach a non-production server.
    static func consentServer(_ baseUrl: String?) throws -> String {
        guard let host = configured(baseUrl) else { throw missingBaseUrl }
        return host
    }

    static func read(ledgerBaseUrl: String?, baseUrl: String?, specificUuid: String?, isSandbox: Bool) throws -> String {
        if let ledger = configured(ledgerBaseUrl), configured(specificUuid) == nil, !isSandbox {
            return ledger
        }
        return try consentServer(baseUrl)
    }

    static func write(ledgerBaseUrl: String?, baseUrl: String?) throws -> String {
        if let ledger = configured(ledgerBaseUrl) { return ledger }
        return try consentServer(baseUrl)
    }

    static func audio(ledgerBaseUrl: String?, baseUrl: String?, isSandbox: Bool) throws -> String {
        isSandbox ? try consentServer(baseUrl) : try write(ledgerBaseUrl: ledgerBaseUrl, baseUrl: baseUrl)
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
