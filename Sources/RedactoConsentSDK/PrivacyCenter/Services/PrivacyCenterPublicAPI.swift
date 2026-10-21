import Foundation

/// The `detail` of `GET /public/organisations/{org}/privacy-center-settings/`.
struct PublicPrivacyCenterSettings: Equatable, Sendable {
    let settings: PCJSONValue
    let version: Int
    let publishedAt: String?
    let language: String
    /// Absent on servers that predate it.
    let brandContact: PCJSONValue?

    /// True once the console has published anything.
    var isPublished: Bool {
        publishedAt != nil || version > 0
    }
}

/// A failed OTP request: the server's `error_code` (or `code`) and status, so
/// each failure gets its own message.
struct PrivacyCenterSignInError: Error, Equatable {
    let status: Int?
    let code: String?
}

/// The tokens a verified one-time code issues.
struct PrivacyCenterSignInTokens: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
}

/// The Privacy Center's public, unauthenticated routes: the published
/// settings and the OTP sign-in.
enum PrivacyCenterPublicAPI {
    static func settingsUrl(baseUrl: String, organisationUuid: String, language: String) -> String {
        let base = baseUrl.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let org = organisationUuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? organisationUuid
        let lang = language.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? language
        return "\(base)/public/organisations/\(org)/privacy-center-settings/?lang=\(lang)"
    }

    /// The organisation's published settings in `language`. Nil on any failure
    /// (network, an error status, an unexpected body), so the caller keeps the
    /// built-in defaults; never throws. One request per organisation and
    /// language is shared for five minutes, and a failed one is forgotten so
    /// the next call retries.
    static func fetchSettings(
        baseUrl: String,
        organisationUuid: String,
        language: String,
        urlSession: URLSession = .shared
    ) async -> PublicPrivacyCenterSettings? {
        let url = settingsUrl(baseUrl: baseUrl, organisationUuid: organisationUuid, language: language)
        return await PrivacyCenterSettingsCache.shared.value(for: url) {
            await requestSettings(url, urlSession: urlSession)
        }
    }

    /// True while a fetch for this organisation and language is cached or in flight.
    static func hasCachedSettings(baseUrl: String, organisationUuid: String, language: String) async -> Bool {
        await PrivacyCenterSettingsCache.shared.has(settingsUrl(baseUrl: baseUrl, organisationUuid: organisationUuid, language: language))
    }

    private static func requestSettings(_ url: String, urlSession: URLSession) async -> PublicPrivacyCenterSettings? {
        guard let requestUrl = URL(string: url) else { return nil }
        var request = URLRequest(url: requestUrl)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await urlSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                // 404: a consent server without settings yet; the defaults apply.
                #if DEBUG
                if status != 404 {
                    print("[RedactoPrivacyCenter] privacy center settings fetch failed with status \(status)")
                }
                #endif
                return nil
            }
            return parseSettings(data)
        } catch {
            #if DEBUG
            print("[RedactoPrivacyCenter] privacy center settings fetch failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// A settings body, bare or in the `{code, status, detail}` envelope.
    static func parseSettings(_ data: Data) -> PublicPrivacyCenterSettings? {
        guard let body = unwrap(data), let settings = body["settings"], settings.objectValue != nil else { return nil }
        return PublicPrivacyCenterSettings(
            settings: settings,
            version: body["version"]?.numberValue.flatMap { Int(exactly: $0.rounded(.towardZero)) } ?? 0,
            publishedAt: body["published_at"]?.stringValue,
            language: body["language"]?.stringValue ?? "en",
            brandContact: body["brand_contact"]
        )
    }

    // MARK: - OTP sign-in

    /// Sends a one-time code to an email, or to an E.164 number by SMS, and
    /// returns its id.
    static func createOtp(
        baseUrl: String,
        organisationUuid: String,
        workspaceUuid: String,
        to contact: String,
        channel: PrivacyCenterSignInContact.Channel,
        urlSession: URLSession = .shared
    ) async throws -> String {
        let body = try await post(
            "\(otpBase(baseUrl, organisationUuid, workspaceUuid))/otp/create",
            body: ["to": contact, "channel": channel.rawValue],
            urlSession: urlSession
        )
        guard let uuid = body["uuid"]?.stringValue, !uuid.isEmpty, body["success"]?.boolValue != false else {
            throw PrivacyCenterSignInError(status: nil, code: nil)
        }
        return uuid
    }

    /// Verifies a code for sign-in. `purpose: "login"` mints the auth-scoped
    /// token the Privacy Center's routes accept.
    static func verifyOtp(
        baseUrl: String,
        organisationUuid: String,
        workspaceUuid: String,
        otpId: String,
        code: String,
        urlSession: URLSession = .shared
    ) async throws -> PrivacyCenterSignInTokens {
        let body = try await post(
            "\(otpBase(baseUrl, organisationUuid, workspaceUuid))/otp/verify",
            body: ["uuid": otpId, "otp": code, "purpose": "login"],
            urlSession: urlSession
        )
        let access = body["access_token"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            ?? body["token"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        guard let access, body["success"]?.boolValue != false else {
            throw PrivacyCenterSignInError(status: nil, code: nil)
        }
        return PrivacyCenterSignInTokens(accessToken: access, refreshToken: body["refresh_token"]?.stringValue)
    }

    private static func otpBase(_ baseUrl: String, _ organisationUuid: String, _ workspaceUuid: String) -> String {
        let base = baseUrl.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        return "\(base)/public/organisations/\(organisationUuid)/workspaces/\(workspaceUuid)"
    }

    private static func post(_ url: String, body: [String: String], urlSession: URLSession) async throws -> [String: PCJSONValue] {
        guard let requestUrl = URL(string: url) else { throw PrivacyCenterSignInError(status: nil, code: nil) }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (data, response) = try await urlSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let root = (try? JSONDecoder().decode(PCJSONValue.self, from: data))?.objectValue
            let code = root?["code"]?.stringValue ?? root?["error_code"]?.stringValue
            throw PrivacyCenterSignInError(status: status, code: code)
        }
        return unwrap(data) ?? [:]
    }

    /// A JSON object body, unwrapped from the `{code, status, detail}`
    /// envelope when it has one.
    static func unwrap(_ data: Data) -> [String: PCJSONValue]? {
        guard let root = (try? JSONDecoder().decode(PCJSONValue.self, from: data))?.objectValue else { return nil }
        if root["code"] != nil, root["status"] != nil, let detail = root["detail"]?.objectValue {
            return detail
        }
        return root
    }
}

/// One shared request per URL for the cache lifetime. Only a request's own
/// failure evicts it, never a newer one cached after it expired.
actor PrivacyCenterSettingsCache {
    static let shared = PrivacyCenterSettingsCache()

    private struct Entry {
        let id: UUID
        let task: Task<PublicPrivacyCenterSettings?, Never>
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    var now: @Sendable () -> Date = { Date() }

    func value(
        for url: String,
        fetch: @escaping @Sendable () async -> PublicPrivacyCenterSettings?
    ) async -> PublicPrivacyCenterSettings? {
        if let entry = freshEntry(url) {
            return await entry.task.value
        }
        let id = UUID()
        let task = Task { await fetch() }
        entries[url] = Entry(id: id, task: task, expiresAt: now().addingTimeInterval(PrivacyCenterSettingsLimits.cacheLifetime))
        let result = await task.value
        if result == nil, entries[url]?.id == id {
            entries[url] = nil
        }
        return result
    }

    func has(_ url: String) -> Bool {
        freshEntry(url) != nil
    }

    func clear() {
        entries = [:]
    }

    func setClock(_ clock: @escaping @Sendable () -> Date) {
        now = clock
    }

    private func freshEntry(_ url: String) -> Entry? {
        guard let entry = entries[url] else { return nil }
        if now() >= entry.expiresAt {
            entries[url] = nil
            return nil
        }
        return entry
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return allowed
    }()
}
