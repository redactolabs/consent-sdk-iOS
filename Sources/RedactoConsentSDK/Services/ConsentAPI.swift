import Foundation

/// High-level API functions for the Redacto Consent SDK.
/// Direct port of the React Native SDK's `api/index.ts`.
public enum ConsentAPI {

    // MARK: - Fetch Consent Content (Modal)

    public struct FetchConsentContentParams {
        public let noticeId: String
        public let accessToken: String
        public var baseUrl: String?
        public var language: String
        public var specificUuid: String?
        public var validateAgainst: String
        public var includeFullyConsentedData: Bool

        public init(
            noticeId: String,
            accessToken: String,
            baseUrl: String? = nil,
            language: String = "en",
            specificUuid: String? = nil,
            validateAgainst: String = "all",
            includeFullyConsentedData: Bool = false
        ) {
            self.noticeId = noticeId
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.language = language
            self.specificUuid = specificUuid
            self.validateAgainst = validateAgainst
            self.includeFullyConsentedData = includeFullyConsentedData
        }
    }

    public static func fetchConsentContent(_ params: FetchConsentContentParams) async throws -> ConsentContent {
        guard !params.noticeId.isEmpty, !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("noticeId and accessToken are required")
        }

        guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
            throw RedactoAPIError.invalidToken
        }

        let orgUuid = decodedToken.organisationUuid
        let wsUuid = decodedToken.workspaceUuid
        guard !orgUuid.isEmpty, !wsUuid.isEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
        }

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL
        let cacheKey = "\(params.accessToken)-\(params.noticeId)-\(params.validateAgainst)-\(params.language)-\(params.specificUuid ?? "")-\(params.includeFullyConsentedData)"

        // Check cache for "all" validation without specific_uuid
        if params.validateAgainst == "all" && params.specificUuid == nil {
            if let cachedData = await APICache.shared.get(cacheKey) {
                if let content = try? JSONDecoder().decode(ConsentContent.self, from: cachedData) {
                    return content
                }
            }
        }

        var urlComponents = URLComponents(string: "\(apiBaseUrl)/public/organisations/\(orgUuid)/workspaces/\(wsUuid)/notices/\(params.noticeId)")!
        var queryItems: [URLQueryItem] = []

        if let specificUuid = params.specificUuid {
            queryItems.append(URLQueryItem(name: "specific_uuid", value: specificUuid))
        }
        queryItems.append(URLQueryItem(name: "validate_against", value: params.validateAgainst))
        if params.includeFullyConsentedData {
            queryItems.append(URLQueryItem(name: "include_fully_consented_data", value: "true"))
        }
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        let headers: [String: String] = [
            "Authorization": "Bearer \(params.accessToken)",
            "Accept-Language": params.language,
        ]

        let data = try await APIClient.getRawData(url: urlComponents.url!, headers: headers)

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
        public var baseUrl: String?
        public var language: String
        public var specificUuid: String?

        public init(
            orgUuid: String,
            workspaceUuid: String,
            noticeUuid: String,
            baseUrl: String? = nil,
            language: String = "en",
            specificUuid: String? = nil
        ) {
            self.orgUuid = orgUuid
            self.workspaceUuid = workspaceUuid
            self.noticeUuid = noticeUuid
            self.baseUrl = baseUrl
            self.language = language
            self.specificUuid = specificUuid
        }
    }

    public static func fetchInlineConsentContent(_ params: FetchInlineConsentContentParams) async throws -> ConsentContent {
        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL

        var urlComponents = URLComponents(string: "\(apiBaseUrl)/public/organisations/\(params.orgUuid)/workspaces/\(params.workspaceUuid)/notices/get-notice/\(params.noticeUuid)")!

        if let specificUuid = params.specificUuid {
            urlComponents.queryItems = [URLQueryItem(name: "specific_uuid", value: specificUuid)]
        }

        let headers: [String: String] = [
            "Accept-Language": params.language,
        ]

        return try await APIClient.get(url: urlComponents.url!, headers: headers, responseType: ConsentContent.self)
    }

    // MARK: - Submit Consent Event

    public struct SubmitConsentEventParams {
        public let accessToken: String
        public var baseUrl: String?
        public let noticeUuid: String
        public let purposes: [Purpose]
        public let declined: Bool
        public var metaData: MetaData?
        public var guardianVerificationReference: String?
        public var selfDeclaredAdult: Bool?

        // For inline component (uses org/ws directly)
        public var orgUuid: String?
        public var workspaceUuid: String?

        public init(
            accessToken: String,
            baseUrl: String? = nil,
            noticeUuid: String,
            purposes: [Purpose],
            declined: Bool,
            metaData: MetaData? = nil,
            guardianVerificationReference: String? = nil,
            selfDeclaredAdult: Bool? = nil,
            orgUuid: String? = nil,
            workspaceUuid: String? = nil
        ) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.noticeUuid = noticeUuid
            self.purposes = purposes
            self.declined = declined
            self.metaData = metaData
            self.guardianVerificationReference = guardianVerificationReference
            self.selfDeclaredAdult = selfDeclaredAdult
            self.orgUuid = orgUuid
            self.workspaceUuid = workspaceUuid
        }
    }

    public static func submitConsentEvent(_ params: SubmitConsentEventParams) async throws {
        guard !params.noticeUuid.isEmpty, !params.accessToken.isEmpty else {
            throw RedactoAPIError.invalidRequest("noticeUuid, accessToken, and purposes array are required")
        }

        let org: String
        let ws: String

        if let orgUuid = params.orgUuid, let workspaceUuid = params.workspaceUuid {
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

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL

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
            metaData: params.metaData,
            guardianVerificationReference: params.guardianVerificationReference,
            selfDeclaredAdult: params.selfDeclaredAdult
        )

        let url = URL(string: "\(apiBaseUrl)/public/organisations/\(org)/workspaces/\(ws)/submit-consent")!
        let headers = ["Authorization": "Bearer \(params.accessToken)"]

        try await APIClient.post(url: url, headers: headers, body: payload)
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

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL
        let payload = GuardianInfoPayload(
            guardianName: params.guardianName.trimmingCharacters(in: .whitespaces),
            guardianContact: params.guardianContact.trimmingCharacters(in: .whitespaces),
            guardianRelationship: params.guardianRelationship.trimmingCharacters(in: .whitespaces)
        )

        let url = URL(string: "\(apiBaseUrl)/public/organisations/\(org)/workspaces/\(ws)/guardian-info")!
        let headers = ["Authorization": "Bearer \(params.accessToken)"]

        try await APIClient.post(url: url, headers: headers, body: payload)
    }

    // MARK: - Fetch TTS Audio URLs

    public struct FetchTTSAudioUrlsParams {
        public let accessToken: String
        public var baseUrl: String?
        public let noticeUuid: String
        public let language: String

        public init(accessToken: String, baseUrl: String? = nil, noticeUuid: String, language: String) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.noticeUuid = noticeUuid
            self.language = language
        }
    }

    public static func fetchTTSAudioUrls(_ params: FetchTTSAudioUrlsParams) async throws -> TTSAudioUrlsResponse {
        guard !params.accessToken.isEmpty, !params.noticeUuid.isEmpty, !params.language.isEmpty else {
            throw RedactoAPIError.invalidRequest("accessToken, noticeUuid, and language are required")
        }

        guard let decodedToken = JWTDecoder.decode(params.accessToken) else {
            throw RedactoAPIError.invalidToken
        }

        let org = decodedToken.organisationUuid
        let ws = decodedToken.workspaceUuid
        guard !org.isEmpty, !ws.isEmpty else {
            throw RedactoAPIError.invalidRequest("Invalid token: missing organization or workspace UUID")
        }

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL
        let encodedLanguage = params.language.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? params.language
        let url = URL(string: "\(apiBaseUrl)/public/organisations/\(org)/workspaces/\(ws)/notices/\(params.noticeUuid)/audio/\(encodedLanguage)")!

        let headers: [String: String] = [
            "Authorization": "Bearer \(params.accessToken)",
            "Accept": "application/json",
        ]

        return try await APIClient.get(url: url, headers: headers, responseType: TTSAudioUrlsResponse.self)
    }

    // MARK: - Guardian Verification

    public struct InitiateGuardianVerificationParams {
        public let accessToken: String
        public var baseUrl: String?
        public let guardianName: String
        public let guardianContact: String
        public let guardianRelationship: String
        public var frontendCallbackUrl: String?

        public init(accessToken: String, baseUrl: String? = nil, guardianName: String, guardianContact: String, guardianRelationship: String, frontendCallbackUrl: String? = nil) {
            self.accessToken = accessToken
            self.baseUrl = baseUrl
            self.guardianName = guardianName
            self.guardianContact = guardianContact
            self.guardianRelationship = guardianRelationship
            self.frontendCallbackUrl = frontendCallbackUrl
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

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL

        struct Payload: Encodable {
            let guardian_name: String
            let guardian_contact: String
            let guardian_relationship: String
            let frontend_callback_url: String?
        }

        let payload = Payload(
            guardian_name: params.guardianName.trimmingCharacters(in: .whitespaces),
            guardian_contact: params.guardianContact.trimmingCharacters(in: .whitespaces),
            guardian_relationship: params.guardianRelationship.trimmingCharacters(in: .whitespaces),
            frontend_callback_url: params.frontendCallbackUrl
        )

        let url = URL(string: "\(apiBaseUrl)/public/organisations/\(org)/workspaces/\(ws)/guardian/initiate-verification")!
        let headers = ["Authorization": "Bearer \(params.accessToken)"]

        // Response may be wrapped in { code, status, detail: {...} }
        struct WrappedResponse: Decodable {
            let detail: InitiateGuardianVerificationResponse?
        }

        let wrapped = try await APIClient.postWithResponse(
            url: url,
            headers: headers,
            body: payload,
            responseType: WrappedResponse.self
        )

        if let detail = wrapped.detail {
            return detail
        }

        // Try direct decode
        return try await APIClient.postWithResponse(
            url: url,
            headers: headers,
            body: payload,
            responseType: InitiateGuardianVerificationResponse.self
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

    public struct VerifyGuardianStatusResponse: Decodable {
        public let status: String?
        public let guardianInfoUuid: String?
        public let verificationReference: String?
        public let error: String?
        public let errorCode: String?
        public let canRetry: Bool?

        enum CodingKeys: String, CodingKey {
            case status
            case guardianInfoUuid = "guardian_info_uuid"
            case verificationReference = "verification_reference"
            case error
            case errorCode = "error_code"
            case canRetry = "can_retry"
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

        let apiBaseUrl = params.baseUrl ?? RedactoConstants.defaultConsentAPIBaseURL

        struct Payload: Encodable {
            let session_token: String
        }

        let url = URL(string: "\(apiBaseUrl)/public/organisations/\(org)/workspaces/\(ws)/guardian/verify-status")!
        let headers = ["Authorization": "Bearer \(params.accessToken)"]

        struct WrappedResponse: Decodable {
            let detail: VerifyGuardianStatusResponse?
        }

        let wrapped = try await APIClient.postWithResponse(
            url: url,
            headers: headers,
            body: Payload(session_token: params.sessionToken),
            responseType: WrappedResponse.self
        )

        if let detail = wrapped.detail {
            return detail
        }

        return try await APIClient.postWithResponse(
            url: url,
            headers: headers,
            body: Payload(session_token: params.sessionToken),
            responseType: VerifyGuardianStatusResponse.self
        )
    }

    // MARK: - Clear Cache

    public static func clearCache() async {
        await APICache.shared.clear()
    }
}
