import Foundation

public struct FileUrlMap: Codable, Sendable, Equatable {
    public let url: String?
    public let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case url
        case downloadUrl = "download_url"
    }
}

public struct MessageDocument: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let fileName: String?
    public let contentType: String?
    public let fileSize: Int?
    public let fileUrl: FileUrlMap?

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case fileName = "file_name"
        case contentType = "content_type"
        case fileSize = "file_size"
        case fileUrl = "file_url"
    }
}

public struct DocumentRequestMetadata: Codable, Sendable, Equatable {
    public let title: String
    public let acceptedDocument: String
    public let documentRequestStatus: DocumentRequestStatus
    public let documentRequestUuid: String?
    public let rejectionReason: String

    enum CodingKeys: String, CodingKey {
        case title
        case acceptedDocument = "accepted_document"
        case documentRequestStatus = "document_request_status"
        case documentRequestUuid = "document_request_uuid"
        case rejectionReason = "rejection_reason"
    }
}

public struct CaseMessage: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let caseUuid: String
    public let senderRole: SenderRole
    public let triggeredByEmail: String
    public let createdAt: String
    public let body: String
    public let documentUuids: [String]
    public let documents: [MessageDocument]
    public let messageType: MessageType
    public let documentRequestMetadata: DocumentRequestMetadata?

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case caseUuid = "case_uuid"
        case senderRole = "sender_role"
        case triggeredByEmail = "triggered_by_email"
        case createdAt = "created_at"
        case body
        case documentUuids = "document_uuids"
        case documents
        case messageType = "message_type"
        case documentRequestMetadata = "document_request_metadata"
    }

    public init(
        uuid: String,
        caseUuid: String,
        senderRole: SenderRole,
        triggeredByEmail: String,
        createdAt: String,
        body: String,
        documentUuids: [String] = [],
        documents: [MessageDocument] = [],
        messageType: MessageType,
        documentRequestMetadata: DocumentRequestMetadata? = nil
    ) {
        self.uuid = uuid
        self.caseUuid = caseUuid
        self.senderRole = senderRole
        self.triggeredByEmail = triggeredByEmail
        self.createdAt = createdAt
        self.body = body
        self.documentUuids = documentUuids
        self.documents = documents
        self.messageType = messageType
        self.documentRequestMetadata = documentRequestMetadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        caseUuid = try container.decode(String.self, forKey: .caseUuid)
        senderRole = try container.decode(SenderRole.self, forKey: .senderRole)
        triggeredByEmail = try container.decode(String.self, forKey: .triggeredByEmail)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        body = try container.decode(String.self, forKey: .body)
        documents = try container.decodeIfPresent([MessageDocument].self, forKey: .documents) ?? []
        documentUuids = try container.decodeIfPresent([String].self, forKey: .documentUuids)
            ?? documents.map(\.uuid)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        documentRequestMetadata = try container.decodeIfPresent(
            DocumentRequestMetadata.self,
            forKey: .documentRequestMetadata
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(caseUuid, forKey: .caseUuid)
        try container.encode(senderRole, forKey: .senderRole)
        try container.encode(triggeredByEmail, forKey: .triggeredByEmail)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(body, forKey: .body)
        try container.encode(documentUuids, forKey: .documentUuids)
        try container.encode(documents, forKey: .documents)
        try container.encode(messageType, forKey: .messageType)
        try container.encodeIfPresent(documentRequestMetadata, forKey: .documentRequestMetadata)
    }
}

public struct UploadDocumentResponse: Codable, Sendable, Equatable {
    public let uuid: String
    public let suid: String?
    public let fileName: String
    public let fileType: String?
    public let contentType: String?
    public let fileSize: Int
    public let createdAt: String?
    public let isPublic: Bool?
    public let file: String?
    public let fileHash: String?
    public let status: String?
    public let allowAiProcessing: Bool?

    enum CodingKeys: String, CodingKey {
        case uuid, suid
        case fileName = "file_name"
        case fileType = "file_type"
        case contentType = "content_type"
        case fileSize = "file_size"
        case createdAt = "created_at"
        case isPublic = "is_public"
        case file
        case fileHash = "file_hash"
        case status
        case allowAiProcessing = "allow_ai_processing"
    }
}

public struct PendingUpload: Sendable, Equatable, Identifiable {
    public let uuid: String
    public let fileName: String
    public let fileSize: Int

    public var id: String { uuid }
}
