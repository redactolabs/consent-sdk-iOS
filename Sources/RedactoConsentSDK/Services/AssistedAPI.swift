import Foundation

enum AssistedAPI {
    static func publicUrl(_ baseUrl: String?, _ organisationUuid: String, _ workspaceUuid: String, _ path: String) throws -> URL? {
        URL(string: NoticeBaseUrl.publicUrl(
            host: try NoticeBaseUrl.consentServer(baseUrl),
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid,
            path: path
        ))
    }

    static func fetchAssistedNotice(
        organisationUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        baseUrl: String?
    ) async throws -> ConsentContent {
        guard !organisationUuid.isEmpty, !workspaceUuid.isEmpty, !noticeUuid.isEmpty,
              let url = try publicUrl(baseUrl, organisationUuid, workspaceUuid, "/notices/get-notice/\(noticeUuid)") else {
            throw RedactoAPIError.invalidRequest("organisationUuid, workspaceUuid and noticeUuid are required")
        }
        return try await APIClient.get(
            url: url,
            headers: ["Accept": "application/json"],
            responseType: ConsentContent.self,
            fallbackMessage: APIErrorFallback.noticeRead
        )
    }

    static func createOtp(
        organisationUuid: String,
        workspaceUuid: String,
        to: String,
        channel: String,
        baseUrl: String?
    ) async throws -> CreateOtpDetail {
        guard !organisationUuid.isEmpty, !workspaceUuid.isEmpty, !to.isEmpty,
              let url = try publicUrl(baseUrl, organisationUuid, workspaceUuid, "/otp/create") else {
            throw RedactoAPIError.invalidRequest("organisationUuid, workspaceUuid and to are required")
        }
        let data = try await APIClient.postData(
            url: url,
            headers: ["Accept": "application/json"],
            body: try APIClient.encode(CreateOtpBody(to: to, channel: channel)),
            fallbackMessage: AssistedAPIFallback.otpSend
        )
        guard let detail = decodeDetail(CreateOtpDetail.self, from: data), !detail.uuid.isEmpty else {
            throw RedactoAPIError.invalidRequest(AssistedAPIFallback.otpSend)
        }
        return detail
    }

    static func verifyOtp(
        organisationUuid: String,
        workspaceUuid: String,
        uuid: String,
        otp: String,
        baseUrl: String?
    ) async throws -> VerifyOtpDetail {
        guard !organisationUuid.isEmpty, !workspaceUuid.isEmpty, !uuid.isEmpty, !otp.isEmpty,
              let url = try publicUrl(baseUrl, organisationUuid, workspaceUuid, "/otp/verify") else {
            throw RedactoAPIError.invalidRequest("organisationUuid, workspaceUuid, uuid and otp are required")
        }
        let (data, status) = try await APIClient.postForStatus(
            url: url,
            headers: ["Accept": "application/json"],
            body: try APIClient.encode(VerifyOtpBody(uuid: uuid, otp: otp, purpose: AssistedConfig.otpPurpose))
        )
        guard let status else {
            throw AssistedAPIError(status: nil, code: nil, message: AssistedAPIFallback.otpVerify, shouldRequestNew: false)
        }
        guard (200...299).contains(status) else {
            throw parseError(status: status, data: data, fallback: AssistedAPIFallback.otpVerify)
        }
        guard let detail = decodeDetail(VerifyOtpDetail.self, from: data) else {
            throw AssistedAPIError(status: status, code: nil, message: AssistedAPIFallback.otpVerify, shouldRequestNew: false)
        }
        return detail
    }

    static func submitAssistedConsent(
        accessToken: String,
        organisationUuid: String,
        workspaceUuid: String,
        baseUrl: String?,
        ledgerBaseUrl: String?,
        noticeUuid: String,
        purposes: [Purpose],
        language: String? = nil
    ) async throws {
        try await ConsentAPI.submitConsentEvent(.init(
            accessToken: accessToken,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            noticeUuid: noticeUuid,
            purposes: purposes,
            declined: false,
            language: language,
            orgUuid: organisationUuid,
            workspaceUuid: workspaceUuid
        ))
    }

    /// Per-element narration clips, from the public endpoint with no auth
    /// (React `fetchAssistedTTSAudioUrls`). `language` is the language NAME the
    /// notice keys it by ("Hindi", "English"), used as the path segment.
    static func fetchAssistedTTSAudioUrls(
        organisationUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        language: String,
        baseUrl: String?
    ) async throws -> TTSAudioUrlsResponse {
        let segment = language.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? language
        guard !organisationUuid.isEmpty, !workspaceUuid.isEmpty, !noticeUuid.isEmpty, !language.isEmpty,
              let url = try publicUrl(baseUrl, organisationUuid, workspaceUuid, "/notices/\(noticeUuid)/audio/\(segment)") else {
            throw RedactoAPIError.invalidRequest("organisationUuid, workspaceUuid, noticeUuid and language are required")
        }
        return try await APIClient.get(
            url: url,
            headers: ["Accept": "application/json"],
            responseType: TTSAudioUrlsResponse.self,
            fallbackMessage: APIErrorFallback.audio
        )
    }

    static func parseError(status: Int, data: Data, fallback: String) -> AssistedAPIError {
        let parsed = APIErrorParser.parse(status: status, data: data, fallback: fallback)
        return AssistedAPIError(
            status: status,
            code: parsed.code,
            message: parsed.message,
            shouldRequestNew: parsed.shouldRequestNew ?? false
        )
    }

    private static func decodeDetail<Detail: Decodable>(_ type: Detail.Type, from data: Data) -> Detail? {
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(AssistedEnvelope<Detail>.self, from: data), let detail = wrapped.detail {
            return detail
        }
        return try? decoder.decode(Detail.self, from: data)
    }
}
