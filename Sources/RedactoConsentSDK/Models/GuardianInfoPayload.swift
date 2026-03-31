import Foundation

public struct GuardianInfoPayload: Encodable {
    public let guardianName: String
    public let guardianContact: String
    public let guardianRelationship: String

    enum CodingKeys: String, CodingKey {
        case guardianName = "guardian_name"
        case guardianContact = "guardian_contact"
        case guardianRelationship = "guardian_relationship"
    }
}
