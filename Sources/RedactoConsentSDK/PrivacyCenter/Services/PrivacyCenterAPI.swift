import Foundation

public actor PrivacyCenterAPI {
    let baseUrl: String
    let tokenStore: TokenStore
    let http: PrivacyCenterHTTPClient

    public init(baseUrl: String, tokenStore: TokenStore, urlSession: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.tokenStore = tokenStore
        self.http = PrivacyCenterHTTPClient(baseUrl: baseUrl, tokenStore: tokenStore, urlSession: urlSession)
    }

    private func dsarPath(_ suffix: String) async throws -> String {
        guard let pair = await tokenStore.currentOrgWorkspace() else {
            throw PrivacyCenterAPIError.missingOrgOrWorkspace
        }
        return "/organisations/\(pair.org)/workspaces/\(pair.ws)/dsar/privacy-center" + suffix
    }

    // MARK: - Form data
    public func getFormData(contact: String, language: String? = nil) async throws -> PrivacyFormData {
        let path = try await dsarPath("/form/data")
        var query: [URLQueryItem] = []
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        let body: [String: String] = ["contact": contact]
        return try await http.post(path, queryItems: query, body: body, as: PrivacyFormData.self)
    }

    // MARK: - Create case (DSR submit)
    public func createCase(_ payload: UserDataRequest, language: String? = nil) async throws -> CreateCaseDetail {
        let path = try await dsarPath("/case")
        var query: [URLQueryItem] = []
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        return try await http.post(path, queryItems: query, body: payload, as: CreateCaseDetail.self)
    }

    // MARK: - User consents
    public func getUserConsents(
        offset: Int? = nil,
        limit: Int? = nil,
        nominatedOffset: Int? = nil,
        nominatedLimit: Int? = nil,
        search: String? = nil,
        status: String? = nil,
        productUuid: String? = nil,
        language: String? = nil
    ) async throws -> UserConsentDetail {
        let path = try await dsarPath("/user-consents")
        var query: [URLQueryItem] = []
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let nominatedOffset { query.append(URLQueryItem(name: "nominated_offset", value: String(nominatedOffset))) }
        if let nominatedLimit { query.append(URLQueryItem(name: "nominated_limit", value: String(nominatedLimit))) }
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        if let status, !status.isEmpty { query.append(URLQueryItem(name: "status", value: status)) }
        if let productUuid, !productUuid.isEmpty { query.append(URLQueryItem(name: "product_uuid", value: productUuid)) }
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        return try await http.get(path, queryItems: query, as: UserConsentDetail.self)
    }

    // MARK: - Manage consent
    public func manageConsent(
        purposeId: String,
        contact: String,
        action: ConsentAction,
        nominatorContact: String? = nil,
        dataElementUuids: [String]? = nil
    ) async throws {
        let path = try await dsarPath("/manage-consent")
        let query = [URLQueryItem(name: "status", value: action.rawValue)]
        struct ManagePayload: Encodable {
            let purpose_uuid: String
            let contact: String
            let nominator_contact: String?
            let data_element_uuids: [String]?
        }
        let payload = ManagePayload(
            purpose_uuid: purposeId,
            contact: contact,
            nominator_contact: nominatorContact,
            data_element_uuids: dataElementUuids
        )
        try await http.postNoResponse(path, queryItems: query, body: payload)
    }

    // MARK: - Activities
    public func getActivities(offset: Int = 0, limit: Int = 15, language: String? = nil) async throws -> ActivityDetail {
        let path = try await dsarPath("/activities")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        return try await http.get(path, queryItems: query, as: ActivityDetail.self)
    }

    // MARK: - Receipts
    public func getReceipts(
        skip: Int = 0,
        limit: Int = 10,
        eventType: String? = nil,
        status: String? = nil,
        createdAfter: String? = nil,
        createdBefore: String? = nil,
        noticeUuid: String? = nil,
        language: String? = nil
    ) async throws -> ReceiptDetail {
        let path = try await dsarPath("/receipts")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let eventType, !eventType.isEmpty { query.append(URLQueryItem(name: "event_type", value: eventType)) }
        if let status, !status.isEmpty { query.append(URLQueryItem(name: "status", value: status)) }
        if let createdAfter, !createdAfter.isEmpty { query.append(URLQueryItem(name: "created_after", value: createdAfter)) }
        if let createdBefore, !createdBefore.isEmpty { query.append(URLQueryItem(name: "created_before", value: createdBefore)) }
        if let noticeUuid, !noticeUuid.isEmpty { query.append(URLQueryItem(name: "notice_uuid", value: noticeUuid)) }
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        return try await http.get(path, queryItems: query, as: ReceiptDetail.self)
    }

    public func getReceiptPdf(receiptUuid: String) async throws -> Data {
        let path = try await dsarPath("/receipts/\(receiptUuid)/pdf")
        return try await http.downloadBinary(path, accept: "application/pdf")
    }

    // MARK: - Case history
    public func getCaseHistory(offset: Int = 0, limit: Int = 10, language: String? = nil) async throws -> CaseHistoryDetail {
        let path = try await dsarPath("/cases")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        return try await http.get(path, queryItems: query, as: CaseHistoryDetail.self)
    }

    // MARK: - Case messages
    public func getCaseMessages(caseUuid: String) async throws -> [CaseMessage] {
        let path = try await dsarPath("/cases/\(caseUuid)/messages")
        return try await http.get(path, as: [CaseMessage].self)
    }

    public func sendCaseMessage(caseUuid: String, body: String, documentUuids: [String] = []) async throws -> CaseMessage {
        let path = try await dsarPath("/cases/\(caseUuid)/messages")
        struct SendPayload: Encodable {
            let body: String
            let document_uuids: [String]
        }
        return try await http.post(path, body: SendPayload(body: body, document_uuids: documentUuids), as: CaseMessage.self)
    }

    public func uploadCaseDocument(caseUuid: String, fileData: Data, filename: String, mimeType: String) async throws -> UploadDocumentResponse {
        let path = try await dsarPath("/cases/\(caseUuid)/upload-document")
        return try await http.uploadMultipart(path, fileData: fileData, filename: filename, mimeType: mimeType, as: UploadDocumentResponse.self)
    }

    public func uploadDocument(fileData: Data, filename: String, mimeType: String) async throws -> UploadDocumentResponse {
        let path = try await dsarPath("/upload-document")
        return try await http.uploadMultipart(path, fileData: fileData, filename: filename, mimeType: mimeType, as: UploadDocumentResponse.self)
    }

    public func submitDocumentForRequest(caseUuid: String, requestEventUuid: String, documentUuid: String, body: String) async throws -> CaseMessage {
        let path = try await dsarPath("/cases/\(caseUuid)/document-requests/\(requestEventUuid)/submit")
        struct SubmitPayload: Encodable {
            let document_uuid: String
            let body: String
        }
        return try await http.post(path, body: SubmitPayload(document_uuid: documentUuid, body: body), as: CaseMessage.self)
    }
}
