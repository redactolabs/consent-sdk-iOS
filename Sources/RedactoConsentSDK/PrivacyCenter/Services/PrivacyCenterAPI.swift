import Foundation

public actor PrivacyCenterAPI {
    let baseUrl: String
    let ledgerBaseUrl: String?
    let tokenStore: TokenStore
    let http: PrivacyCenterHTTPClient

    public init(baseUrl: String, ledgerBaseUrl: String? = nil, tokenStore: TokenStore, urlSession: URLSession = .shared) {
        let ledger = Self.normalizedLedgerBaseUrl(ledgerBaseUrl)
        self.baseUrl = baseUrl
        self.ledgerBaseUrl = ledger
        self.tokenStore = tokenStore
        self.http = PrivacyCenterHTTPClient(baseUrl: baseUrl, ledgerBaseUrl: ledger, tokenStore: tokenStore, urlSession: urlSession)
    }

    static func normalizedLedgerBaseUrl(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private var usesLedger: Bool { ledgerBaseUrl != nil }

    private func dsarPath(_ suffix: String) async throws -> String {
        guard let pair = await tokenStore.currentOrgWorkspace() else {
            throw PrivacyCenterAPIError.missingOrgOrWorkspace
        }
        return "/organisations/\(pair.org)/workspaces/\(pair.ws)/dsar/privacy-center" + suffix
    }

    private func ledgerPath(_ suffix: String) async throws -> String {
        guard let pair = await tokenStore.currentOrgWorkspace() else {
            throw PrivacyCenterAPIError.missingOrgOrWorkspace
        }
        return "/public/organisations/\(pair.org)/workspaces/\(pair.ws)" + suffix
    }

    private func consentsRoute(_ suffix: String) async throws -> (path: String, host: PCHost) {
        if usesLedger {
            return (try await ledgerPath(suffix), .ledger)
        }
        return (try await dsarPath(suffix), .consent)
    }

    /// The active sandbox config, or nil in JWT mode.
    private func sandbox() async -> SandboxConfig? {
        await tokenStore.sandbox
    }

    /// Every supplied sandbox identifier (`org_user_id` / `primary_email` /
    /// `primary_mobile`) as query items to append to a GET/query read, or an empty
    /// array in JWT mode. The server resolves the acting test principal from these
    /// query params on reads (there is no subject header) and keeps the rest as
    /// the display-only sandbox contact. The credential is the `X-Consent-Token`
    /// header set in the HTTP client.
    private func sandboxQueryItems() async -> [URLQueryItem] {
        guard let sandbox = await sandbox() else { return [] }
        return sandbox.identityQueryItems
    }

    // MARK: - Form data
    public func getFormData(contact: String, language: String? = nil) async throws -> PrivacyFormData {
        let path = try await dsarPath("/form/data")
        var query: [URLQueryItem] = []
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        // The body is just `{ contact }`; in sandbox `contact` is the sandbox
        // contact (seeded on the store). The credential is the X-Consent-Token
        // header. Mirrors React `getFormData` (`{ contact }`, no identity fields).
        let body: [String: String] = ["contact": contact]
        return try await http.post(path, queryItems: query, body: body, as: PrivacyFormData.self)
    }

    // MARK: - Create case (DSR submit)
    public func createCase(_ payload: UserDataRequest, language: String? = nil) async throws -> CreateCaseDetail {
        let path = try await dsarPath("/case")
        var query: [URLQueryItem] = []
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        // Sandbox: overlay only `contact = sandbox.contact` onto the payload (the
        // server classifies it as email/phone/UCIC). Mirrors React
        // `createCaseRequest` (`{ ...payload, contact: sandboxContact() }`).
        if let sandbox = await sandbox() {
            let body = SandboxIdentityBody(base: payload, identity: ["contact": sandbox.contact])
            return try await http.post(path, queryItems: query, body: body, as: CreateCaseDetail.self)
        }
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
        let route = try await consentsRoute("/user-consents")
        var query: [URLQueryItem] = []
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let nominatedOffset { query.append(URLQueryItem(name: "nominated_offset", value: String(nominatedOffset))) }
        if let nominatedLimit { query.append(URLQueryItem(name: "nominated_limit", value: String(nominatedLimit))) }
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        if let status, !status.isEmpty { query.append(URLQueryItem(name: "status", value: status)) }
        if let productUuid, !productUuid.isEmpty { query.append(URLQueryItem(name: "product_uuid", value: productUuid)) }
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        query.append(contentsOf: await sandboxQueryItems())
        return try await http.get(route.path, host: route.host, queryItems: query, as: UserConsentDetail.self)
    }

    public func getGroupPurposes(
        productUuid: String,
        offset: Int? = nil,
        limit: Int? = nil,
        status: String? = nil,
        search: String? = nil,
        language: String? = nil,
        nominatorUuid: String? = nil
    ) async throws -> GroupPurposesDetail {
        let route = try await consentsRoute("/user-consents/\(productUuid)/purposes")
        var query: [URLQueryItem] = []
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let status, !status.isEmpty { query.append(URLQueryItem(name: "status", value: status)) }
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        if let language, !language.isEmpty { query.append(URLQueryItem(name: "language", value: language)) }
        if let nominatorUuid, !nominatorUuid.isEmpty { query.append(URLQueryItem(name: "nominator_uuid", value: nominatorUuid)) }
        query.append(contentsOf: await sandboxQueryItems())
        return try await http.get(route.path, host: route.host, queryItems: query, as: GroupPurposesDetail.self)
    }

    public func listIdentities() async throws -> IdentityListResponse {
        let path = try await dsarPath("/identities")
        return try await http.get(path, as: IdentityListResponse.self)
    }

    public func selectPrincipal(uuid: String) async throws -> SelectPrincipalResponse {
        let path = try await dsarPath("/identities/select")
        let body: [String: String] = ["uuid": uuid]
        return try await http.post(path, body: body, as: SelectPrincipalResponse.self)
    }

    // MARK: - Manage consent
    public func manageConsent(
        purposeId: String,
        contact: String,
        action: ConsentAction,
        nominatorContact: String? = nil,
        dataElementUuids: [String]? = nil,
        productUuid: String? = nil,
        noticeUuid: String? = nil,
        dataElements: [ConsentDataElement] = [],
        language: String? = nil,
        nominatorUuid: String? = nil
    ) async throws {
        try await manageConsent(ManageConsentRequest(
            purposeUuid: purposeId,
            contact: contact,
            action: action,
            productUuid: productUuid,
            noticeUuid: noticeUuid,
            dataElements: dataElements,
            dataElementUuids: dataElementUuids,
            nominatorContact: nominatorContact,
            nominatorUuid: nominatorUuid,
            language: language
        ))
    }

    public func manageConsent(_ request: ManageConsentRequest) async throws {
        if usesLedger {
            try await manageConsentOnLedger(request)
        } else {
            try await manageConsentOnConsentServer(request)
        }
    }

    private func manageConsentOnConsentServer(_ request: ManageConsentRequest) async throws {
        let path = try await dsarPath("/manage-consent")
        let query = [URLQueryItem(name: "status", value: request.action.rawValue)]
        let elementUuids = request.dataElementUuids.flatMap { $0.isEmpty ? nil : $0 }
        // The body carries only `{ purpose_uuid, contact, ... }`; in sandbox
        // `contact` is the sandbox contact (seeded on the store) and the credential
        // is the X-Consent-Token header. Mirrors React `manageConsent` (legacy
        // non-ledger path): no sandbox body treatment.
        let body = LegacyManageConsentBody(
            purpose_uuid: request.purposeUuid,
            contact: request.contact,
            nominator_contact: request.nominatorContact,
            data_element_uuids: elementUuids,
            product_uuid: request.productUuid,
            language: request.language
        )
        let data = try await http.postData(path, host: .consent, queryItems: query, body: try JSONEncoder().encode(body))
        if let result = try? EnvelopeDecoder.decode(LegacyManageConsentResult.self, from: data), result.success == false {
            throw PrivacyCenterAPIError.consentOperationFailed(Self.manageFailureMessage(request.action))
        }
    }

    private func manageConsentOnLedger(_ request: ManageConsentRequest) async throws {
        guard let noticeUuid = request.noticeUuid, let ledgerBaseUrl else {
            throw PrivacyCenterAPIError.consentOperationFailed(Self.manageFailureMessage(request.action))
        }
        let path = try await ledgerPath("/submit-consent")
        let selection = LedgerPurposeSelection(
            purpose_uuid: request.purposeUuid,
            product_uuid: request.productUuid,
            selected: request.action != .revoke,
            data_elements: Self.ledgerDataElements(for: request)
        )
        let envelope = LedgerManageConsentBody(
            notice_uuid: noticeUuid,
            product_uuid: request.productUuid,
            partial: true,
            declined: false,
            select_all_mandatory: false,
            self_declared_adult: false,
            purposes: [selection],
            language: request.language,
            nominator_uuid: request.nominatorUuid
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body: Data
        if let sandbox = await sandbox() {
            body = try encoder.encode(SandboxIdentityBody(base: envelope, identity: sandbox.identityBodyFields))
        } else {
            body = try encoder.encode(envelope)
        }
        let url = ledgerBaseUrl + path
        let client = http
        _ = try await IdempotencyKeys.shared.withKey(url: url, body: body) { headers in
            try await client.postDataResponse(path, host: .ledger, body: body, headers: headers)
        }
    }

    static func ledgerDataElements(for request: ManageConsentRequest) -> [LedgerDataElementSelection] {
        request.dataElements.map { element in
            let selected: Bool
            switch request.action {
            case .revoke:
                selected = false
            case .regrant:
                selected = request.dataElementUuids.map { $0.contains(element.uuid) } ?? element.selected
            case .renew:
                selected = element.selected
            }
            return LedgerDataElementSelection(uuid: element.uuid, selected: selected)
        }
    }

    static func manageFailureMessage(_ action: ConsentAction) -> String {
        switch action {
        case .revoke: return PCStrings.unableToRevokeConsent
        case .regrant: return PCStrings.unableToRegrantConsent
        case .renew: return PCStrings.unableToRenewConsent
        }
    }

    // MARK: - Activities
    public func getActivities(offset: Int = 0, limit: Int = 15, language: String? = nil) async throws -> ActivityDetail {
        let path = try await dsarPath("/activities")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        query.append(contentsOf: await sandboxQueryItems())
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
        let route = try await consentsRoute("/receipts")
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
        query.append(contentsOf: await sandboxQueryItems())
        return try await http.get(route.path, host: route.host, queryItems: query, as: ReceiptDetail.self)
    }

    public func getReceiptPdf(receiptUuid: String) async throws -> Data {
        let route = try await consentsRoute(usesLedger ? "/receipts/\(receiptUuid)/download" : "/receipts/\(receiptUuid)/pdf")
        // Sandbox: the acting identity travels as query items (like the list);
        // the backend resolves the data principal to authorise the read.
        return try await http.downloadBinary(
            route.path, host: route.host, queryItems: await sandboxQueryItems(), accept: "application/pdf"
        )
    }

    // MARK: - Case history
    /// React reads the whole list (no offset/limit) and filters and pages it on
    /// the device; pass both to page on the server instead.
    public func getCaseHistory(offset: Int? = nil, limit: Int? = nil, language: String? = nil) async throws -> CaseHistoryDetail {
        let path = try await dsarPath("/cases")
        var query: [URLQueryItem] = []
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let language { query.append(URLQueryItem(name: "language", value: language)) }
        query.append(contentsOf: await sandboxQueryItems())
        return try await http.get(path, queryItems: query, as: CaseHistoryDetail.self)
    }

    // MARK: - Case messages
    public func getCaseMessages(caseUuid: String) async throws -> [CaseMessage] {
        let path = try await dsarPath("/cases/\(caseUuid)/messages")
        // Sandbox: the acting identity travels as a query item on this read.
        return try await http.get(path, queryItems: await sandboxQueryItems(), as: [CaseMessage].self)
    }

    public func sendCaseMessage(caseUuid: String, body: String, documentUuids: [String] = []) async throws -> CaseMessage {
        let path = try await dsarPath("/cases/\(caseUuid)/messages")
        struct SendPayload: Encodable {
            let body: String
            let document_uuids: [String]
        }
        let payload = SendPayload(body: body, document_uuids: documentUuids)
        // Sandbox: the acting identity travels as a URL query item (like the GET),
        // not in the body. Mirrors React `sendCaseMessage`
        // (`/messages${sandboxIdentitySuffix()}`). The body is just the message
        // content + document uuids.
        return try await http.post(path, queryItems: await sandboxQueryItems(), body: payload, as: CaseMessage.self)
    }

    public func uploadCaseDocument(caseUuid: String, fileData: Data, filename: String, mimeType: String) async throws -> UploadDocumentResponse {
        let path = try await dsarPath("/cases/\(caseUuid)/upload-document")
        // Mirrors React `uploadCaseDocument`: the case endpoint takes no fields,
        // but rejects a request with no `payload` part at all.
        let payload = Data(#"{"metadata":null}"#.utf8)
        return try await http.uploadMultipart(path, fileData: fileData, filename: filename, mimeType: mimeType, payload: payload, as: UploadDocumentResponse.self)
    }

    /// - Parameter principalUuid: the form session's `uuid` (`PrivacyFormData.uuid`),
    ///   which the document is filed under, as React's DSR form files it.
    public func uploadDocument(fileData: Data, filename: String, mimeType: String, principalUuid: String = "") async throws -> UploadDocumentResponse {
        guard let pair = await tokenStore.currentOrgWorkspace() else {
            throw PrivacyCenterAPIError.missingOrgOrWorkspace
        }
        let path = try await dsarPath("/upload-document")
        let payload = try JSONSerialization.data(withJSONObject: Self.uploadDocumentPayload(
            organisationUuid: pair.org,
            principalUuid: principalUuid,
            documentUuid: UUID().uuidString.lowercased(),
            isPublic: true,
            identity: await sandbox()?.identityBodyFields ?? [:]
        ))
        return try await http.uploadMultipart(path, fileData: fileData, filename: filename, mimeType: mimeType, payload: payload, as: UploadDocumentResponse.self)
    }

    /// The JSON part of a DSR document upload. The endpoint answers
    /// `422 Field required` without `organization_uuid`, `uuid`, `is_public` and
    /// `allow_ai_processing`. In sandbox the acting identity rides along, since
    /// the static token carries none.
    static func uploadDocumentPayload(
        organisationUuid: String,
        principalUuid: String,
        documentUuid: String,
        isPublic: Bool,
        identity: [String: String]
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "organization_uuid": organisationUuid,
            "space": "privacy/\(principalUuid)",
            "uuid": documentUuid,
            "is_public": isPublic,
            "allow_ai_processing": true,
            "metadata": [
                "group_by": "privacy",
                "case_uuid": principalUuid,
                "product": "privacy_center",
            ],
        ]
        for (key, value) in identity {
            payload[key] = value
        }
        return payload
    }

    public func submitDocumentForRequest(caseUuid: String, requestEventUuid: String, documentUuid: String, body: String) async throws -> CaseMessage {
        let path = try await dsarPath("/cases/\(caseUuid)/document-requests/\(requestEventUuid)/submit")
        struct SubmitPayload: Encodable {
            let document_uuid: String
            let body: String
        }
        // Sandbox: the acting identity travels as a URL query item (like the
        // sibling case writes); without it the backend rejects this write with
        // 400 "Sandbox request requires a user identifier". The credential is the
        // X-Consent-Token header.
        return try await http.post(path, queryItems: await sandboxQueryItems(), body: SubmitPayload(document_uuid: documentUuid, body: body), as: CaseMessage.self)
    }

    /// A case document's metadata and download URL (React `getCaseDocument`).
    public func getCaseDocument(caseUuid: String, documentUuid: String) async throws -> MessageDocument {
        let path = try await dsarPath("/cases/\(caseUuid)/documents/\(documentUuid)")
        return try await http.get(path, queryItems: await sandboxQueryItems(), as: MessageDocument.self)
    }

    // MARK: - Notification hub

    public func getNotifications(
        category: PrivacyNotificationCategory? = nil,
        notificationType: String? = nil,
        isRead: Bool? = nil,
        skip: Int? = nil,
        limit: Int? = nil,
        includeSummary: Bool = false,
        language: String? = nil
    ) async throws -> PrivacyNotificationList {
        let path = try await dsarPath("/notifications/")
        var query: [URLQueryItem] = []
        if let category { query.append(URLQueryItem(name: "category", value: category.rawValue)) }
        if let notificationType, !notificationType.isEmpty { query.append(URLQueryItem(name: "notification_type", value: notificationType)) }
        if let isRead { query.append(URLQueryItem(name: "is_read", value: isRead ? "true" : "false")) }
        if let skip { query.append(URLQueryItem(name: "skip", value: String(skip))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if includeSummary { query.append(URLQueryItem(name: "include_summary", value: "true")) }
        if let language, !language.isEmpty { query.append(URLQueryItem(name: "language", value: language)) }
        query.append(contentsOf: await sandboxQueryItems())
        return try await http.get(path, queryItems: query, as: PrivacyNotificationList.self)
    }

    public func getNotificationSummary() async throws -> PrivacyNotificationSummary {
        let path = try await dsarPath("/notifications/summary")
        return try await http.get(path, queryItems: await sandboxQueryItems(), as: PrivacyNotificationSummary.self)
    }

    public func getUnreadNotificationCount() async throws -> PrivacyNotificationUnreadCount {
        let path = try await dsarPath("/notifications/unread-count")
        return try await http.get(path, queryItems: await sandboxQueryItems(), as: PrivacyNotificationUnreadCount.self)
    }

    public func markNotificationRead(uuid: String) async throws {
        let path = try await dsarPath("/notifications/\(uuid)/read")
        _ = try await http.send("PATCH", path, queryItems: await sandboxQueryItems(), as: PrivacyNotificationAction.self)
    }

    public func markAllNotificationsRead() async throws {
        let path = try await dsarPath("/notifications/mark-all-read")
        _ = try await http.send("POST", path, queryItems: await sandboxQueryItems(), as: PrivacyNotificationAction.self)
    }

    public func acknowledgeNotification(uuid: String) async throws {
        let path = try await dsarPath("/notifications/\(uuid)/acknowledge")
        _ = try await http.send("POST", path, queryItems: await sandboxQueryItems(), as: PrivacyNotificationAction.self)
    }
}

/// Public workspace branding, served by the user server rather than the
/// consent server (React api/orgBranding.ts). No auth.
enum PrivacyCenterBrandingAPI {
    static func userServerBaseUrl(for consentBaseUrl: String) -> String {
        consentBaseUrl.contains(".io") ? "https://api.redacto.io/user/api/0" : "https://api.redacto.tech/user/api/0"
    }

    static func fetch(slug: String, consentBaseUrl: String, urlSession: URLSession = .shared) async throws -> OrgBrandingDetail {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        guard let url = URL(string: "\(userServerBaseUrl(for: consentBaseUrl))/public/org-branding/by-slug/\(encoded)") else {
            throw PrivacyCenterAPIError.networkError("Invalid branding URL")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PrivacyCenterAPIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
        return try EnvelopeDecoder.decode(OrgBrandingDetail.self, from: data)
    }
}
