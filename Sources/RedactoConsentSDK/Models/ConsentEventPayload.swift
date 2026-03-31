import Foundation

public struct ConsentEventPayload: Encodable {
    public let noticeUuid: String
    public let purposes: [ConsentPurposePayload]
    public let selectAllMandatory: Bool
    public let source: String
    public let declined: Bool
    public let metaData: MetaData?
    public let guardianVerificationReference: String?
    public let selfDeclaredAdult: Bool?

    enum CodingKeys: String, CodingKey {
        case noticeUuid = "notice_uuid"
        case purposes
        case selectAllMandatory = "select_all_mandatory"
        case source, declined
        case metaData = "meta_data"
        case guardianVerificationReference = "guardian_verification_reference"
        case selfDeclaredAdult = "self_declared_adult"
    }
}

public struct ConsentPurposePayload: Encodable {
    public let purposeUuid: String
    public let selected: Bool
    public let dataElements: [ConsentDataElementPayload]?

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case selected
        case dataElements = "data_elements"
    }
}

public struct ConsentDataElementPayload: Encodable {
    public let uuid: String
    public let selected: Bool
}

public struct MetaData: Encodable {
    public let specificUuid: String

    enum CodingKeys: String, CodingKey {
        case specificUuid = "specific_uuid"
    }
}
