import Foundation

public struct Activity: Codable, Sendable, Identifiable, Equatable {
    public let activityType: String
    public let activityTypeDisplay: String?
    public let timestamp: String
    public let title: String
    public let titleDisplay: String?
    public let description: String
    public let descriptionDisplay: String?
    public let caseId: String?
    public let status: String?
    public let statusDisplay: String?

    public var id: String { activityType + ":" + timestamp + ":" + (caseId ?? "") }

    enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case activityTypeDisplay = "activity_type_display"
        case timestamp, title
        case titleDisplay = "title_display"
        case description
        case descriptionDisplay = "description_display"
        case caseId = "case_id"
        case status
        case statusDisplay = "status_display"
    }
}

public struct ActivityDetail: Codable, Sendable, Equatable {
    public let data: [Activity]?
    public let pagination: Pagination?

    public var items: [Activity] { data ?? [] }
    public var page: Pagination { pagination ?? Pagination(totalCount: 0, offset: 0, limit: 15) }
}
