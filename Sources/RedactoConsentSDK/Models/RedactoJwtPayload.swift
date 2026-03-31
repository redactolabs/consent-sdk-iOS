import Foundation

public struct RedactoJwtPayload: Codable {
    public let organisationUuid: String
    public let workspaceUuid: String
    public let userUuid: String?
    public let exp: TimeInterval?
    public let iat: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case organisationUuid = "organisation_uuid"
        case workspaceUuid = "workspace_uuid"
        case userUuid = "user_uuid"
        case exp, iat
    }
}
