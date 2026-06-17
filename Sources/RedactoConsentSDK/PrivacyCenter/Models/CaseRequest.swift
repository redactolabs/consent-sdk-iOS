import Foundation

public struct CaseRequest: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let caseId: String
    public let rawStatus: String?
    public let statusDisplay: String?
    public let rawRequestType: String?
    public let requestTypeDisplay: String?
    public let rawDescription: String?
    public let descriptionDisplay: String?
    public let rawCreatedAt: String?
    public let completedAt: String?
    public let dueDate: String?
    public let name: String?
    public let contact: String?

    public var id: String { uuid }
    public var status: String { statusDisplay ?? rawStatus ?? "" }
    public var requestType: String { requestTypeDisplay ?? rawRequestType ?? "" }
    public var description: String { descriptionDisplay ?? rawDescription ?? "" }
    public var createdAt: String { rawCreatedAt ?? "" }

    public init(
        uuid: String,
        caseId: String,
        status: String? = nil,
        statusDisplay: String? = nil,
        requestType: String? = nil,
        requestTypeDisplay: String? = nil,
        description: String? = nil,
        descriptionDisplay: String? = nil,
        createdAt: String? = nil,
        completedAt: String? = nil,
        dueDate: String? = nil,
        name: String? = nil,
        contact: String? = nil
    ) {
        self.uuid = uuid
        self.caseId = caseId
        self.rawStatus = status
        self.statusDisplay = statusDisplay
        self.rawRequestType = requestType
        self.requestTypeDisplay = requestTypeDisplay
        self.rawDescription = description
        self.descriptionDisplay = descriptionDisplay
        self.rawCreatedAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.name = name
        self.contact = contact
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case caseId = "case_id"
        case rawStatus = "status"
        case statusDisplay = "status_display"
        case rawRequestType = "request_type"
        case requestTypeDisplay = "request_type_display"
        case rawDescription = "description"
        case descriptionDisplay = "description_display"
        case rawCreatedAt = "created_at"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case name
        case contact
    }
}

public struct CaseHistoryDetail: Codable, Sendable, Equatable {
    public let data: [CaseRequest]?
    public let pagination: Pagination?

    public var items: [CaseRequest] { data ?? [] }
    public var page: Pagination { pagination ?? Pagination(totalCount: 0, offset: 0, limit: 10) }
}

public struct CreateCaseDetail: Codable, Sendable, Equatable {
    public let uuid: String?
    public let caseId: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case caseId = "case_id"
    }
}
