import Foundation

/// Notification hub models (React lib/types.ts `Notification*`). Every field
/// reads leniently: a kind or category added server-side later renders with a
/// neutral icon instead of failing the whole list.
public enum PrivacyNotificationCategory: String, Codable, Sendable, CaseIterable {
    case consent, request, system
}

public struct PrivacyNotificationCTA: Codable, Sendable, Equatable, Hashable {
    public enum Style: String, Codable, Sendable {
        case primary, secondary, danger
    }

    public enum ActionType: String, Codable, Sendable {
        case link, acknowledge
    }

    public let label: String
    public let style: Style
    public let actionType: ActionType?
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case label, style, url
        case actionType = "action_type"
    }

    public init(label: String, style: Style = .secondary, actionType: ActionType?, url: String? = nil) {
        self.label = label
        self.style = style
        self.actionType = actionType
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = c.lenient(String.self, forKey: .label)
        style = c.optional(Style.self, forKey: .style) ?? .secondary
        actionType = c.optional(ActionType.self, forKey: .actionType)
        url = c.optional(String.self, forKey: .url)
    }
}

public struct PrivacyNotification: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let notificationType: String
    public let category: String?
    public let title: String
    public let description: String
    public var isRead: Bool
    public var isAcknowledged: Bool
    public let sourceType: String?
    public let sourceUuid: String?
    public let requestType: String?
    public let requestTypeDisplay: String?
    public let statusLabel: String?
    public let statusLabelDisplay: String?
    public let ctas: [PrivacyNotificationCTA]
    public let createdAt: String

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, category, title, description, ctas
        case notificationType = "notification_type"
        case isRead = "is_read"
        case isAcknowledged = "is_acknowledged"
        case sourceType = "source_type"
        case sourceUuid = "source_uuid"
        case requestType = "request_type"
        case requestTypeDisplay = "request_type_display"
        case statusLabel = "status_label"
        case statusLabelDisplay = "status_label_display"
        case createdAt = "created_at"
    }

    public init(
        uuid: String,
        notificationType: String,
        category: String? = nil,
        title: String,
        description: String = "",
        isRead: Bool = false,
        isAcknowledged: Bool = false,
        sourceType: String? = nil,
        sourceUuid: String? = nil,
        requestType: String? = nil,
        requestTypeDisplay: String? = nil,
        statusLabel: String? = nil,
        statusLabelDisplay: String? = nil,
        ctas: [PrivacyNotificationCTA] = [],
        createdAt: String = ""
    ) {
        self.uuid = uuid
        self.notificationType = notificationType
        self.category = category
        self.title = title
        self.description = description
        self.isRead = isRead
        self.isAcknowledged = isAcknowledged
        self.sourceType = sourceType
        self.sourceUuid = sourceUuid
        self.requestType = requestType
        self.requestTypeDisplay = requestTypeDisplay
        self.statusLabel = statusLabel
        self.statusLabelDisplay = statusLabelDisplay
        self.ctas = ctas
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        notificationType = c.lenient(String.self, forKey: .notificationType)
        category = c.optional(String.self, forKey: .category)
        title = c.lenient(String.self, forKey: .title)
        description = c.lenient(String.self, forKey: .description)
        isRead = c.lenient(Bool.self, forKey: .isRead)
        isAcknowledged = c.lenient(Bool.self, forKey: .isAcknowledged)
        sourceType = c.optional(String.self, forKey: .sourceType)
        sourceUuid = c.optional(String.self, forKey: .sourceUuid)
        requestType = c.optional(String.self, forKey: .requestType)
        requestTypeDisplay = c.optional(String.self, forKey: .requestTypeDisplay)
        statusLabel = c.optional(String.self, forKey: .statusLabel)
        statusLabelDisplay = c.optional(String.self, forKey: .statusLabelDisplay)
        ctas = c.lenient([PrivacyNotificationCTA].self, forKey: .ctas)
        createdAt = c.lenient(String.self, forKey: .createdAt)
    }

    /// `status_label_display || status_label`.
    public var displayStatusLabel: String? { statusLabelDisplay.pcNonEmpty ?? statusLabel.pcNonEmpty }

    public var hasAcknowledgeCTA: Bool { ctas.contains { $0.actionType == .acknowledge } }
}

public struct PrivacyNotificationSummary: Codable, Sendable, Equatable {
    public var total: Int
    public var unread: Int
    public var actionNeeded: Int
    public var acknowledged: Int

    enum CodingKeys: String, CodingKey {
        case total, unread, acknowledged
        case actionNeeded = "action_needed"
    }

    public init(total: Int = 0, unread: Int = 0, actionNeeded: Int = 0, acknowledged: Int = 0) {
        self.total = total
        self.unread = unread
        self.actionNeeded = actionNeeded
        self.acknowledged = acknowledged
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = c.lenient(Int.self, forKey: .total)
        unread = c.lenient(Int.self, forKey: .unread)
        actionNeeded = c.lenient(Int.self, forKey: .actionNeeded)
        acknowledged = c.lenient(Int.self, forKey: .acknowledged)
    }
}

public struct PrivacyNotificationList: Codable, Sendable, Equatable {
    public let data: [PrivacyNotification]
    public let total: Int
    public let skip: Int
    public let limit: Int
    public let summary: PrivacyNotificationSummary?

    enum CodingKeys: String, CodingKey {
        case data, total, skip, limit, summary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = c.lenient([PrivacyNotification].self, forKey: .data)
        total = c.optional(Int.self, forKey: .total) ?? data.count
        skip = c.lenient(Int.self, forKey: .skip)
        limit = c.lenient(Int.self, forKey: .limit)
        summary = c.optional(PrivacyNotificationSummary.self, forKey: .summary)
    }
}

public struct PrivacyNotificationUnreadCount: Codable, Sendable, Equatable {
    public let count: Int

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.lenient(Int.self, forKey: .count)
    }

    enum CodingKeys: String, CodingKey { case count }
}

public struct PrivacyNotificationAction: Codable, Sendable, Equatable {
    public let message: String?
}

/// Icon family for a notification kind (React `TYPE_TO_ICON_CATEGORY`); an
/// unknown kind reads as `system`.
public enum PrivacyNotificationIconCategory: String, Sendable {
    case guardian, consent, access, withdrawal, grievance, system

    public init(notificationType: String) {
        switch notificationType {
        case "guardian_verification_request": self = .guardian
        case "consent_expiry_warning", "consent_regrant_prompt": self = .consent
        case "new_consent_notice": self = .system
        case "consent_withdrawal_confirmation": self = .withdrawal
        case "data_request_status_update", "case_message": self = .access
        case "grievance_status_update": self = .grievance
        default: self = .system
        }
    }

    /// React `ICON_COLORS`.
    public var hex: String {
        switch self {
        case .guardian: return "#7c3aed"
        case .consent: return "#ea580c"
        case .access: return "#16a34a"
        case .withdrawal: return "#2563eb"
        case .grievance: return "#dc2626"
        case .system: return "#6b7280"
        }
    }

    public var systemImage: String {
        switch self {
        case .guardian: return "person"
        case .consent: return "clock"
        case .access: return "doc"
        case .withdrawal: return "checkmark.shield"
        case .grievance: return "exclamationmark.circle"
        case .system: return "gearshape"
        }
    }
}
