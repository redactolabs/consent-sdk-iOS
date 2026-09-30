import Foundation

public struct Activity: Codable, Sendable, Identifiable, Equatable {
    public let backendId: String?
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

    // Prefer the backend's stable per-activity id (source event/case uuid); fall
    // back to the composite only for older payloads that don't carry one. The
    // composite is not unique for two consent events sharing a timestamp, so
    // ForEach would mis-render tied-timestamp rows without the backend id.
    public var id: String {
        if let backendId, !backendId.isEmpty { return backendId }
        return activityType + ":" + timestamp + ":" + (caseId ?? "")
    }

    enum CodingKeys: String, CodingKey {
        case backendId = "id"
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

    public init(
        backendId: String? = nil,
        activityType: String,
        activityTypeDisplay: String? = nil,
        timestamp: String,
        title: String,
        titleDisplay: String? = nil,
        description: String = "",
        descriptionDisplay: String? = nil,
        caseId: String? = nil,
        status: String? = nil,
        statusDisplay: String? = nil
    ) {
        self.backendId = backendId
        self.activityType = activityType
        self.activityTypeDisplay = activityTypeDisplay
        self.timestamp = timestamp
        self.title = title
        self.titleDisplay = titleDisplay
        self.description = description
        self.descriptionDisplay = descriptionDisplay
        self.caseId = caseId
        self.status = status
        self.statusDisplay = statusDisplay
    }

    /// One activity missing a title or timestamp must not blank the timeline.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backendId = c.optional(String.self, forKey: .backendId)
        activityType = c.lenient(String.self, forKey: .activityType)
        activityTypeDisplay = c.optional(String.self, forKey: .activityTypeDisplay)
        timestamp = c.lenient(String.self, forKey: .timestamp)
        title = c.lenient(String.self, forKey: .title)
        titleDisplay = c.optional(String.self, forKey: .titleDisplay)
        description = c.lenient(String.self, forKey: .description)
        descriptionDisplay = c.optional(String.self, forKey: .descriptionDisplay)
        caseId = c.optional(String.self, forKey: .caseId)
        status = c.optional(String.self, forKey: .status)
        statusDisplay = c.optional(String.self, forKey: .statusDisplay)
    }

    /// `title_display || title`, as the timeline shows it.
    public var displayTitle: String { titleDisplay.pcNonEmpty ?? title }
    public var displayDescription: String { descriptionDisplay.pcNonEmpty ?? description }
    /// `activity_type_display || formatActivityType(activity_type)`.
    public var displayType: String {
        if let display = activityTypeDisplay.pcNonEmpty { return display }
        return activityType
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

public struct ActivityDetail: Codable, Sendable, Equatable {
    public let data: [Activity]?
    public let pagination: Pagination?

    public var items: [Activity] { data ?? [] }
    public var page: Pagination { pagination ?? Pagination(totalCount: 0, offset: 0, limit: 15) }
}
