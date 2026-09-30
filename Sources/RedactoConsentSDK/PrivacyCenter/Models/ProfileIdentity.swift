import Foundation

public struct IdentityCandidate: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let orgUserId: String?
    public let primaryEmail: String?
    public let primaryMobile: String?

    public var id: String { uuid }

    public init(uuid: String, orgUserId: String? = nil, primaryEmail: String? = nil, primaryMobile: String? = nil) {
        self.uuid = uuid
        self.orgUserId = orgUserId
        self.primaryEmail = primaryEmail
        self.primaryMobile = primaryMobile
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case orgUserId = "org_user_id"
        case primaryEmail = "primary_email"
        case primaryMobile = "primary_mobile"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        orgUserId = try container.decodeIfPresent(String.self, forKey: .orgUserId)
        primaryEmail = try container.decodeIfPresent(String.self, forKey: .primaryEmail)
        primaryMobile = try container.decodeIfPresent(String.self, forKey: .primaryMobile)
    }
}

public struct IdentityListResponse: Codable, Sendable, Equatable {
    public let identities: [IdentityCandidate]
}

public struct SelectPrincipalResponse: Codable, Sendable, Equatable {
    public let token: String
    public let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
    }
}

public enum ProfileGatePhase: Sendable, Equatable {
    case checking
    case picking
    case resolved
}

public struct ProfileRowLabels: Sendable, Equatable {
    public let primary: String
    public let secondary: [String]
}
