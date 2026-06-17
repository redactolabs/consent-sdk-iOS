import Foundation

public struct RedactoJwtUserData: Codable, Sendable {
    public let primaryEmail: String?
    public let email: String?
    public let contact: String?

    enum CodingKeys: String, CodingKey {
        case primaryEmail = "primary_email"
        case email
        case contact
    }
}

public struct RedactoJwtPayload: Codable {
    public let organisationUuid: String
    public let workspaceUuid: String
    public let userUuid: String?
    public let exp: TimeInterval?
    public let iat: TimeInterval?
    public let email: String?
    public let contact: String?
    public let primaryEmail: String?
    public let organisationName: String?
    public let sub: String?
    public let userData: RedactoJwtUserData?

    enum CodingKeys: String, CodingKey {
        case organisationUuid = "organisation_uuid"
        case workspaceUuid = "workspace_uuid"
        case userUuid = "user_uuid"
        case exp, iat
        case email
        case contact
        case primaryEmail = "primary_email"
        case organisationName = "organisation_name"
        case sub
        case userData = "user_data"
    }

    /// First non-empty contact identifier in priority order.
    public var resolvedContact: String? {
        for value in [
            contact,
            primaryEmail,
            email,
            userUuid,
            sub,
            userData?.primaryEmail,
            userData?.email,
            userData?.contact,
        ] {
            if let value, !value.isEmpty { return value }
        }
        return nil
    }
}
