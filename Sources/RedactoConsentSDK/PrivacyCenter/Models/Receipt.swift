import Foundation

public struct Receipt: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let eventType: String
    public let eventTypeDisplay: String?
    public let productName: String?
    public let productNameDisplay: String?
    public let createdAt: String

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case receiptUuid = "receipt_uuid"
        case id
        case eventType = "event_type"
        case eventTypeDisplay = "event_type_display"
        case productName = "product_name"
        case productNameDisplay = "product_name_display"
        case createdAt = "created_at"
    }

    public init(
        uuid: String,
        eventType: String,
        eventTypeDisplay: String? = nil,
        productName: String? = nil,
        productNameDisplay: String? = nil,
        createdAt: String
    ) {
        self.uuid = uuid
        self.eventType = eventType
        self.eventTypeDisplay = eventTypeDisplay
        self.productName = productName
        self.productNameDisplay = productNameDisplay
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
            ?? (try container.decodeIfPresent(String.self, forKey: .receiptUuid))
            ?? (try container.decodeIfPresent(String.self, forKey: .id))
            ?? ""
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType) ?? ""
        eventTypeDisplay = try container.decodeIfPresent(String.self, forKey: .eventTypeDisplay)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productNameDisplay = try container.decodeIfPresent(String.self, forKey: .productNameDisplay)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(eventTypeDisplay, forKey: .eventTypeDisplay)
        try container.encodeIfPresent(productName, forKey: .productName)
        try container.encodeIfPresent(productNameDisplay, forKey: .productNameDisplay)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct ReceiptDetail: Codable, Sendable, Equatable {
    public let data: [Receipt]?
    public let pagination: Pagination?

    public var items: [Receipt] { data ?? [] }
    public var page: Pagination { pagination ?? Pagination(totalCount: 0, offset: 0, limit: 10) }

    // The receipts list payload may arrive as {data,pagination} | {items} | a bare array.
    // Decode defensively so the screen works regardless of the exact envelope shape.
    private enum CodingKeys: String, CodingKey {
        case data, items, receipts, results, pagination, meta
        case totalCount = "total_count"
        case total, count, skip, limit
    }

    public init(data: [Receipt]?, pagination: Pagination?) {
        self.data = data
        self.pagination = pagination
    }

    public init(from decoder: Decoder) throws {
        // Bare array form: [ {…}, {…} ]
        if let array = try? decoder.singleValueContainer().decode([Receipt].self) {
            self.data = array
            self.pagination = Pagination(totalCount: array.count, offset: 0, limit: array.count)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = (try? container.decode([Receipt].self, forKey: .data))
            ?? (try? container.decode([Receipt].self, forKey: .items))
            ?? (try? container.decode([Receipt].self, forKey: .receipts))
            ?? (try? container.decode([Receipt].self, forKey: .results))
            ?? []
        self.data = rows

        if let pagination = (try? container.decode(Pagination.self, forKey: .pagination))
            ?? (try? container.decode(Pagination.self, forKey: .meta)) {
            self.pagination = pagination
        } else {
            let total = (try? container.decode(Int.self, forKey: .totalCount))
                ?? (try? container.decode(Int.self, forKey: .total))
                ?? (try? container.decode(Int.self, forKey: .count))
                ?? rows.count
            let offset = (try? container.decode(Int.self, forKey: .skip)) ?? 0
            let limit = (try? container.decode(Int.self, forKey: .limit)) ?? max(rows.count, 10)
            self.pagination = Pagination(totalCount: total, offset: offset, limit: limit)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(pagination, forKey: .pagination)
    }
}
