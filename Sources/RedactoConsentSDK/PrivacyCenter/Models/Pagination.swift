import Foundation

public struct Pagination: Codable, Sendable, Equatable {
    public let totalCount: Int
    public let offset: Int
    public let limit: Int

    public init(totalCount: Int, offset: Int, limit: Int) {
        self.totalCount = totalCount
        self.offset = offset
        self.limit = limit
    }

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case offset, limit
    }
}
