import Foundation

/// Encodes a base `Encodable` payload and then merges extra flat string fields
/// (the sandbox acting identity) into the same top-level JSON object. Used only
/// on sandbox POST/write paths so the server can resolve the acting test
/// identity from the body — the JWT/live payload is left byte-for-byte unchanged.
struct SandboxIdentityBody<Base: Encodable>: Encodable {
    let base: Base
    let identity: [String: String]

    private struct DynamicKey: CodingKey {
        let stringValue: String
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    func encode(to encoder: Encoder) throws {
        // Encode the base payload into the same container first, then overlay the
        // identity fields (order is irrelevant for JSON objects).
        try base.encode(to: encoder)
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in identity {
            try container.encode(value, forKey: DynamicKey(key))
        }
    }
}

/// High-level API functions for the Redacto Consent SDK.
/// Direct port of the React Native SDK's `api/index.ts`.
public enum ConsentAPI {

    // MARK: - Fetch Consent Content (Modal)

    public struct FetchConsentContentParams {
        public let noticeId: String
        public let accessToken: String
        public var baseUrl: String?
        public var ledgerBaseUrl: String?
        public var language: String
        public var specificUuid: String?
        public var validateAgainst: String
        public var includeFullyConsentedData: Bool
        /// Optional sandbox config. When present, the call authenticates with the
        /// `X-Consent-Token` header, takes org/workspace from the config, and adds
        /// the acting identity as a query item — bypassing the JWT path entirely.
        public var sandbox: SandboxConfig?

        public init(
            noticeId: String,
            accessToken: String,
            baseUrl: String? = nil,
            ledgerBaseUrl: String? = nil,
            language: String = "en",
            specificUuid: String? = nil,
            validateAgainst: String = "all",
            includeFullyConsentedData: Bool = false,
            sandbox: SandboxConfig? = nil
        ) {
            self.noticeId = noticeId
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.ledgerBaseUrl = ledgerBaseUrl
            self.language = language
            self.specificUuid = specificUuid
            self.validateAgainst = validateAgainst
            self.includeFullyConsentedData = includeFullyConsentedData
            self.sandbox = sandbox
        }
    }

    public static func fetchConsentContent(_ params: FetchConsentContentParams) async throws -> ConsentContent {
        // Sandbox mode is keyed off a non-empty token; the accessToken is optional then.
        guard !params.noticeId.isEmpty else {
            throw RedactoAPIError.invalidRequest("noticeId is required")
        }
        guard params.sandbox != nil || !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken or sandbox token is required")
        }

        let orgUuid: String
        let wsUuid: String
        if let sandbox = params.sandbox {
            orgUuid = sandbox.organisationUuid
            wsUuid = sandbox.workspaceUuid
        } else {
            guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
                throw RedactoAPIError.invalidToken
            }
            orgUuid = decodedToken.organisationUuid
            wsUuid = decodedToken.workspaceUuid
            guard !orgUuid.isEmpty, !wsUuid.isEmpty else {
                throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
            }
        }

        let apiBaseUrl = try NoticeBaseUrl.read(
            ledgerBaseUrl: params.ledgerBaseUrl,
            baseUrl: params.baseUrl,
            specificUuid: params.specificUuid,
            isSandbox: params.sandbox != nil
        )
        // Cache identity: in sandbox, key by org/workspace/identity so two sessions
        // sharing a subject but scoped to different orgs never collide.
        let cacheIdentity = params.sandbox.map {
            "sandbox:\($0.organisationUuid):\($0.workspaceUuid):\($0.contact)"
        } ?? params.accessToken
        let cacheKey = "\(cacheIdentity)-\(params.noticeId)-\(params.validateAgainst)-\(params.language)-\(params.specificUuid ?? "")-\(params.includeFullyConsentedData)"

        // Check cache for "all" validation without specific_uuid
        if params.validateAgainst == "all" && params.specificUuid == nil {
            if let cachedData = await APICache.shared.get(cacheKey) {
                if let content = try? JSONDecoder().decode(ConsentContent.self, from: cachedData) {
                    return content
                }
            }
        }

        var queryItems: [URLQueryItem] = []

        if let specificUuid = params.specificUuid {
            queryItems.append(URLQueryItem(name: "specific_uuid", value: specificUuid))
        }
        queryItems.append(URLQueryItem(name: "validate_against", value: params.validateAgainst))
        if params.includeFullyConsentedData {
            queryItems.append(URLQueryItem(name: "include_fully_consented_data", value: "true"))
        }
        // Sandbox: every supplied identifier travels as query items; the
        // credential is the X-Consent-Token header.
        if let sandbox = params.sandbox {
            queryItems.append(contentsOf: sandbox.identityQueryItems)
        }
        let url = try NoticeBaseUrl.url(
            NoticeBaseUrl.publicUrl(
                host: apiBaseUrl,
                organisationUuid: orgUuid,
                workspaceUuid: wsUuid,
                path: "/notices/\(params.noticeId)"
            ),
            queryItems: queryItems
        )

        var headers: [String: String] = ["Accept-Language": params.language]
        if let sandbox = params.sandbox {
            headers.merge(sandbox.authHeaders) { _, new in new }
        } else {
            headers["Authorization"] = "Bearer \(params.accessToken)"
        }

        let data = try await APIClient.getRawData(
            url: url,
            headers: headers,
            fallbackMessage: APIErrorFallback.noticeRead
        )

        // Cache the response for "all" validation without specific_uuid
        if params.validateAgainst == "all" && params.specificUuid == nil {
            await APICache.shared.set(cacheKey, data: data)
        }

        do {
            return try JSONDecoder().decode(ConsentContent.self, from: data)
        } catch {
            throw RedactoAPIError.decodingError(error)
        }
    }

    // MARK: - Fetch Consent Content (Inline - no auth required for fetch)

    public struct FetchInlineConsentContentParams {
        public let orgUuid: String
        public let workspaceUuid: String
        public let noticeUuid: String
        public var accessToken: String?
        public var baseUrl: String?
        public var ledgerBaseUrl: String?
        public var language: String
        public var specificUuid: String?

        public init(
            orgUuid: String,
            workspaceUuid: String,
            noticeUuid: String,
            accessToken: String? = nil,
            baseUrl: String? = nil,
            language: String = "en",
            specificUuid: String? = nil,
            ledgerBaseUrl: String? = nil
        ) {
            self.orgUuid = orgUuid
            self.workspaceUuid = workspaceUuid
            self.noticeUuid = noticeUuid
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.ledgerBaseUrl = ledgerBaseUrl
            self.language = language
            self.specificUuid = specificUuid
        }
    }

    public static func fetchInlineConsentContent(_ params: FetchInlineConsentContentParams) async throws -> ConsentContent {
        let accessToken = params.accessToken.flatMap { $0.isEmpty ? nil : $0 }
        // With a ledger configured the authenticated read goes there, as the
        // modal's does. The tokenless `get-notice` form exists only on the
        // consent server, and the ledger read takes no `specific_uuid`.
        let host = accessToken == nil
            ? try NoticeBaseUrl.consentServer(params.baseUrl)
            : try NoticeBaseUrl.read(
                ledgerBaseUrl: params.ledgerBaseUrl,
                baseUrl: params.baseUrl,
                specificUuid: params.specificUuid,
                isSandbox: false
            )
        let url = try NoticeBaseUrl.url(
            NoticeBaseUrl.publicUrl(
                host: host,
                organisationUuid: params.orgUuid,
                workspaceUuid: params.workspaceUuid,
                path: accessToken != nil ? "/notices/\(params.noticeUuid)" : "/notices/get-notice/\(params.noticeUuid)"
            ),
            queryItems: params.specificUuid.map { [URLQueryItem(name: "specific_uuid", value: $0)] } ?? []
        )

        var headers: [String: String] = [
            "Accept-Language": params.language,
        ]

        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }

        return try await APIClient.get(
            url: url,
            headers: headers,
            responseType: ConsentContent.self,
            fallbackMessage: APIErrorFallback.noticeRead
        )
    }

    // MARK: - Submit Consent Event

    public struct SubmitConsentEventParams {
        public let accessToken: String
        public var baseUrl: String?
        public var ledgerBaseUrl: String?
        public let noticeUuid: String
        public let purposes: [Purpose]
        public let declined: Bool
        /// BCP-47 code of the language the notice was shown in; see
        /// `NoticeLanguageCodes.toBcp47Code`. Empty is left out.
        public var language: String?
        public var metaData: MetaData?
        public var guardianVerificationReference: String?
        public var selfDeclaredAdult: Bool?

        // For inline component (uses org/ws directly)
        public var orgUuid: String?
        public var workspaceUuid: String?
        /// Optional sandbox config. When present, the call authenticates with the
        /// `X-Consent-Token` header, takes org/workspace from the config, and merges
        /// the acting identity into the JSON body — bypassing the JWT path entirely.
        public var sandbox: SandboxConfig?

        public init(
            accessToken: String,
            baseUrl: String? = nil,
            ledgerBaseUrl: String? = nil,
            noticeUuid: String,
            purposes: [Purpose],
            declined: Bool,
            language: String? = nil,
            metaData: MetaData? = nil,
            guardianVerificationReference: String? = nil,
            selfDeclaredAdult: Bool? = nil,
            orgUuid: String? = nil,
            workspaceUuid: String? = nil,
            sandbox: SandboxConfig? = nil
        ) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.ledgerBaseUrl = ledgerBaseUrl
            self.noticeUuid = noticeUuid
            self.purposes = purposes
            self.declined = declined
            self.language = language
            self.metaData = metaData
            self.guardianVerificationReference = guardianVerificationReference
            self.selfDeclaredAdult = selfDeclaredAdult
            self.orgUuid = orgUuid
            self.workspaceUuid = workspaceUuid
            self.sandbox = sandbox
        }
    }

    public static func submitConsentEvent(_ params: SubmitConsentEventParams) async throws {
        guard !params.noticeUuid.isEmpty else {
            throw RedactoAPIError.invalidRequest("noticeUuid and purposes array are required")
        }
        guard params.sandbox != nil || !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken or sandbox token is required")
        }

        let org: String
        let ws: String

        if let sandbox = params.sandbox {
            org = sandbox.organisationUuid
            ws = sandbox.workspaceUuid
        } else if let orgUuid = params.orgUuid, let workspaceUuid = params.workspaceUuid {
            org = orgUuid
            ws = workspaceUuid
        } else {
            guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
                throw RedactoAPIError.invalidToken
            }
            org = decodedToken.organisationUuid
            ws = decodedToken.workspaceUuid
            guard !org.isEmpty, !ws.isEmpty else {
                throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
            }
        }

        let apiBaseUrl = try NoticeBaseUrl.write(ledgerBaseUrl: params.ledgerBaseUrl, baseUrl: params.baseUrl)

        let validatedPurposes = params.purposes.map { purpose -> ConsentPurposePayload in
            let dataElements = purpose.dataElements
                .filter { $0.enabled }
                .map { element in
                    ConsentDataElementPayload(
                        uuid: element.uuid,
                        selected: element.required ? true : element.selected
                    )
                }

            return ConsentPurposePayload(
                purposeUuid: purpose.uuid,
                productUuid: purpose.productUuid.flatMap { $0.isEmpty ? nil : $0 },
                selected: purpose.selected,
                dataElements: dataElements.isEmpty ? nil : dataElements
            )
        }

        let payload = ConsentEventPayload(
            noticeUuid: params.noticeUuid,
            purposes: validatedPurposes,
            selectAllMandatory: false,
            source: "MOBILE",
            declined: params.declined,
            language: params.language.flatMap { $0.isEmpty ? nil : $0 },
            metaData: params.metaData,
            guardianVerificationReference: params.guardianVerificationReference,
            selfDeclaredAdult: params.selfDeclaredAdult
        )

        let url = try NoticeBaseUrl.url(
            NoticeBaseUrl.publicUrl(host: apiBaseUrl, organisationUuid: org, workspaceUuid: ws, path: "/submit-consent")
        )

        let body: Data
        let headers: [String: String]
        if let sandbox = params.sandbox {
            // Sandbox: merge every supplied identifier into the body, mirroring a
            // live JWT's `user_data` (the server has no subject header; it keys the
            // principal by precedence and namespaces this identity `test::`).
            body = try APIClient.encode(SandboxIdentityBody(base: payload, identity: sandbox.identityBodyFields))
            headers = sandbox.authHeaders
        } else {
            body = try APIClient.encode(payload)
            headers = ["Authorization": "Bearer \(params.accessToken)"]
        }
        try await APIClient.postIdempotent(
            url: url,
            headers: headers,
            body: body,
            fallbackMessage: APIErrorFallback.submitConsent
        )
        await APICache.shared.clear()
    }

    // MARK: - Submit Guardian Info

    public struct SubmitGuardianInfoParams {
        public let accessToken: String
        public var baseUrl: String?
        public let guardianName: String
        public let guardianContact: String
        public let guardianRelationship: String

        public init(
            accessToken: String,
            baseUrl: String? = nil,
            guardianName: String,
            guardianContact: String,
            guardianRelationship: String
        ) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.guardianName = guardianName
            self.guardianContact = guardianContact
            self.guardianRelationship = guardianRelationship
        }
    }

    public static func submitGuardianInfo(_ params: SubmitGuardianInfoParams) async throws {
        guard !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken is required")
        }
        guard !params.guardianName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("guardianName is required and cannot be empty")
        }
        guard !params.guardianContact.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("guardianContact is required and cannot be empty")
        }
        guard !params.guardianRelationship.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("guardianRelationship is required and cannot be empty")
        }

        guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
            throw RedactoAPIError.invalidToken
        }

        let org = decodedToken.organisationUuid
        let ws = decodedToken.workspaceUuid
        guard !org.isEmpty, !ws.isEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
        }

        let apiBaseUrl = try NoticeBaseUrl.consentServer(params.baseUrl)
        let payload = GuardianInfoPayload(
            guardianName: params.guardianName.trimmingCharacters(in: .whitespaces),
            guardianContact: params.guardianContact.trimmingCharacters(in: .whitespaces),
            guardianRelationship: params.guardianRelationship.trimmingCharacters(in: .whitespaces)
        )

        let url = try NoticeBaseUrl.url(
            NoticeBaseUrl.publicUrl(host: apiBaseUrl, organisationUuid: org, workspaceUuid: ws, path: "/guardian-info")
        )
        let headers = ["Authorization": "Bearer \(params.accessToken)"]

        try await APIClient.post(url: url, headers: headers, body: payload, fallbackMessage: APIErrorFallback.guardianInfo)
    }

    // MARK: - Fetch TTS Audio URLs

    public struct FetchTTSAudioUrlsParams {
        public let accessToken: String
        public var baseUrl: String?
        public var ledgerBaseUrl: String?
        public let noticeUuid: String
        public let language: String
        /// Optional sandbox config. When present, the call authenticates with the
        /// `X-Consent-Token` header, takes org/workspace from the config, and adds
        /// the acting identity as a query item — bypassing the JWT path entirely.
        public var sandbox: SandboxConfig?

        public init(accessToken: String, baseUrl: String? = nil, ledgerBaseUrl: String? = nil, noticeUuid: String, language: String, sandbox: SandboxConfig? = nil) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.ledgerBaseUrl = ledgerBaseUrl
            self.noticeUuid = noticeUuid
            self.language = language
            self.sandbox = sandbox
        }
    }

    public static func fetchTTSAudioUrls(_ params: FetchTTSAudioUrlsParams) async throws -> TTSAudioUrlsResponse {
        guard !params.noticeUuid.isEmpty, !params.language.isEmpty else {
            throw RedactoAPIError.invalidRequest("noticeUuid and language are required")
        }
        guard params.sandbox != nil || !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken or sandbox token is required")
        }

        let org: String
        let ws: String
        if let sandbox = params.sandbox {
            org = sandbox.organisationUuid
            ws = sandbox.workspaceUuid
        } else {
            guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
                throw RedactoAPIError.invalidToken
            }
            org = decodedToken.organisationUuid
            ws = decodedToken.workspaceUuid
            guard !org.isEmpty, !ws.isEmpty else {
                throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
            }
        }

        let apiBaseUrl = try NoticeBaseUrl.audio(
            ledgerBaseUrl: params.ledgerBaseUrl,
            baseUrl: params.baseUrl,
            isSandbox: params.sandbox != nil
        )
        let encodedLanguage = params.language.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? params.language
        var headers: [String: String] = ["Accept": "application/json"]
        if let sandbox = params.sandbox {
            // Sandbox: every supplied identifier travels as query items; the
            // credential is the X-Consent-Token header.
            headers.merge(sandbox.authHeaders) { _, new in new }
        } else {
            headers["Authorization"] = "Bearer \(params.accessToken)"
        }
        let url = try NoticeBaseUrl.url(
            NoticeBaseUrl.publicUrl(
                host: apiBaseUrl,
                organisationUuid: org,
                workspaceUuid: ws,
                path: "/notices/\(params.noticeUuid)/audio/\(encodedLanguage)"
            ),
            queryItems: params.sandbox?.identityQueryItems ?? []
        )

        return try await APIClient.get(
            url: url,
            headers: headers,
            responseType: TTSAudioUrlsResponse.self,
            fallbackMessage: APIErrorFallback.audio
        )
    }

    // MARK: - Guardian Verification

    public struct InitiateGuardianVerificationParams {
        public let accessToken: String
        public var baseUrl: String?
        public let guardianName: String
        public let guardianContact: String
        public let guardianRelationship: String
        public var frontendCallbackUrl: String?
        /// Sent as `metadata` when present; must be a valid JSON object.
        public var metadata: [String: Any]?

        public init(
            accessToken: String,
            baseUrl: String? = nil,
            guardianName: String,
            guardianContact: String,
            guardianRelationship: String,
            frontendCallbackUrl: String? = nil,
            metadata: [String: Any]? = nil
        ) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.guardianName = guardianName
            self.guardianContact = guardianContact
            self.guardianRelationship = guardianRelationship
            self.frontendCallbackUrl = frontendCallbackUrl
            self.metadata = metadata
        }
    }

    public struct InitiateGuardianVerificationResponse: Decodable {
        public let success: Bool?
        public let guardianInfoUuid: String?
        public let alreadyVerified: Bool?
        public let verificationReference: String?
        public let sessionToken: String?
        public let digilockerRedirectUrl: String?
        public let expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case success
            case guardianInfoUuid = "guardian_info_uuid"
            case alreadyVerified = "already_verified"
            case verificationReference = "verification_reference"
            case sessionToken = "session_token"
            case digilockerRedirectUrl = "digilocker_redirect_url"
            case expiresAt = "expires_at"
        }
    }

    public static func initiateGuardianVerification(_ params: InitiateGuardianVerificationParams) async throws -> InitiateGuardianVerificationResponse {
        guard !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken is required")
        }
        guard !params.guardianName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("Guardian name is required")
        }
        guard !params.guardianContact.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("Guardian contact is required")
        }
        guard !params.guardianRelationship.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RedactoAPIError.invalidRequest("Guardian relationship is required")
        }

        guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
            throw RedactoAPIError.invalidToken
        }

        let org = decodedToken.organisationUuid
        let ws = decodedToken.workspaceUuid
        guard !org.isEmpty, !ws.isEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
        }

        var payload: [String: Any] = [
            "guardian_name": params.guardianName.trimmingCharacters(in: .whitespaces),
            "guardian_contact": params.guardianContact.trimmingCharacters(in: .whitespaces),
            "guardian_relationship": params.guardianRelationship.trimmingCharacters(in: .whitespaces),
        ]
        if let callback = params.frontendCallbackUrl, !callback.isEmpty {
            payload["frontend_callback_url"] = callback
        }
        if let metadata = params.metadata {
            payload["metadata"] = metadata
        }
        // JSONSerialization raises an Objective-C exception, not a Swift error,
        // on a value it cannot encode.
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw RedactoAPIError.invalidRequest("metadata must be a valid JSON object")
        }

        let url = try NoticeBaseUrl.url(NoticeBaseUrl.publicUrl(
            host: try NoticeBaseUrl.consentServer(params.baseUrl),
            organisationUuid: org,
            workspaceUuid: ws,
            path: "/guardian/initiate-verification"
        ))
        let data = try await APIClient.postData(
            url: url,
            headers: ["Authorization": "Bearer \(params.accessToken)"],
            body: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            fallbackMessage: APIErrorFallback.guardianVerification
        )
        let detail = responseDetail(data)

        // Already verified: DigiLocker is skipped entirely.
        if detail["already_verified"] as? Bool == true {
            return InitiateGuardianVerificationResponse(
                success: true,
                guardianInfoUuid: detail["guardian_info_uuid"] as? String,
                alreadyVerified: true,
                verificationReference: detail["verification_reference"] as? String,
                sessionToken: nil,
                digilockerRedirectUrl: nil,
                expiresAt: nil
            )
        }

        guard let sessionToken = (detail["session_token"] as? String)?.nonEmpty,
              let redirectUrl = (detail["digilocker_redirect_url"] as? String)?.nonEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid response: missing session_token or digilocker_redirect_url")
        }
        return InitiateGuardianVerificationResponse(
            success: (detail["success"] as? Bool) ?? true,
            guardianInfoUuid: detail["guardian_info_uuid"] as? String,
            alreadyVerified: false,
            verificationReference: nil,
            sessionToken: sessionToken,
            digilockerRedirectUrl: redirectUrl,
            expiresAt: detail["expires_at"] as? String
        )
    }

    public struct VerifyGuardianStatusParams {
        public let accessToken: String
        public var baseUrl: String?
        public let sessionToken: String

        public init(accessToken: String, baseUrl: String? = nil, sessionToken: String) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.sessionToken = sessionToken
        }
    }

    public struct GuardianVerificationDetails: Decodable, Equatable {
        public let verifiedName: String?
        public let isGuardianAdult: Bool?
        public let verifiedAt: String?
        public let verificationReference: String?

        enum CodingKeys: String, CodingKey {
            case verifiedName = "verified_name"
            case isGuardianAdult = "is_guardian_adult"
            case verifiedAt = "verified_at"
            case verificationReference = "verification_reference"
        }
    }

    public struct VerifyGuardianStatusResponse: Decodable {
        public let status: String?
        public let guardianInfoUuid: String?
        public let verificationReference: String?
        public let error: String?
        public let errorCode: String?
        public let canRetry: Bool?
        public var guardianDetails: GuardianVerificationDetails?

        enum CodingKeys: String, CodingKey {
            case status
            case guardianInfoUuid = "guardian_info_uuid"
            case verificationReference = "verification_reference"
            case error
            case errorCode = "error_code"
            case canRetry = "can_retry"
            case guardianDetails = "guardian_details"
        }
    }

    public static func verifyGuardianStatus(_ params: VerifyGuardianStatusParams) async throws -> VerifyGuardianStatusResponse {
        guard !params.accessToken.isEmpty, !params.sessionToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken and sessionToken are required")
        }

        guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
            throw RedactoAPIError.invalidToken
        }

        let org = decodedToken.organisationUuid
        let ws = decodedToken.workspaceUuid
        guard !org.isEmpty, !ws.isEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
        }

        struct Payload: Encodable {
            let session_token: String
        }

        let url = try NoticeBaseUrl.url(NoticeBaseUrl.publicUrl(
            host: try NoticeBaseUrl.consentServer(params.baseUrl),
            organisationUuid: org,
            workspaceUuid: ws,
            path: "/guardian/verify-status"
        ))
        let data = try await APIClient.postData(
            url: url,
            headers: ["Authorization": "Bearer \(params.accessToken)"],
            body: try APIClient.encode(Payload(session_token: params.sessionToken)),
            fallbackMessage: APIErrorFallback.guardianStatus
        )
        let detail = responseDetail(data)
        let guardianDetails = (detail["guardian_details"] as? [String: Any]).flatMap { details in
            (try? JSONSerialization.data(withJSONObject: details))
                .flatMap { try? JSONDecoder().decode(GuardianVerificationDetails.self, from: $0) }
        }

        return VerifyGuardianStatusResponse(
            status: (detail["status"] as? String) ?? "in_progress",
            guardianInfoUuid: detail["guardian_info_uuid"] as? String,
            verificationReference: detail["verification_reference"] as? String,
            error: detail["error"] as? String,
            errorCode: detail["error_code"] as? String,
            canRetry: (detail["can_retry"] as? Bool) ?? true,
            guardianDetails: guardianDetails
        )
    }

    /// The response's `detail` object when it is wrapped (`{ code, status,
    /// detail: {...} }`), else the body itself.
    static func responseDetail(_ data: Data) -> [String: Any] {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (body["detail"] as? [String: Any]) ?? body
    }

    public static func fetchNoticeConsentStatus(_ params: NoticeConsentStatusParams) async -> NoticeConsentStatus? {
        guard let ledger = NoticeBaseUrl.configured(params.ledgerBaseUrl),
              !params.accessToken.isEmpty,
              !params.organisationUuid.isEmpty,
              !params.workspaceUuid.isEmpty,
              !params.noticeUuid.isEmpty,
              let url = URL(string: NoticeBaseUrl.publicUrl(
                  host: ledger,
                  organisationUuid: params.organisationUuid,
                  workspaceUuid: params.workspaceUuid,
                  path: "/notices/\(params.noticeUuid)/check-consent"
              )) else {
            return nil
        }
        guard let data = try? await APIClient.postData(
            url: url,
            headers: ["Authorization": "Bearer \(params.accessToken)"],
            body: Data("{}".utf8)
        ) else {
            return nil
        }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(NoticeConsentStatusEnvelope.self, from: data) {
            return envelope.detail
        }
        return try? decoder.decode(NoticeConsentStatus.self, from: data)
    }

    // MARK: - Clear Cache

    public static func clearCache() async {
        await APICache.shared.clear()
    }
}
