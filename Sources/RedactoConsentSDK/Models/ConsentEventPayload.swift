import Foundation

public struct ConsentEventPayload: Encodable {
    public let noticeUuid: String
    public let purposes: [ConsentPurposePayload]
    public let selectAllMandatory: Bool
    public let source: String
    public let declined: Bool
    /// BCP-47 code of the language the notice was shown in.
    public let language: String?
    public let metaData: MetaData?
    public let guardianVerificationReference: String?
    public let selfDeclaredAdult: Bool?

    enum CodingKeys: String, CodingKey {
        case noticeUuid = "notice_uuid"
        case purposes
        case selectAllMandatory = "select_all_mandatory"
        case source, declined, language
        case metaData = "meta_data"
        case guardianVerificationReference = "guardian_verification_reference"
        case selfDeclaredAdult = "self_declared_adult"
    }
}

public struct ConsentPurposePayload: Encodable {
    public let purposeUuid: String
    public let productUuid: String?
    public let selected: Bool
    public let dataElements: [ConsentDataElementPayload]?

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case productUuid = "product_uuid"
        case selected
        case dataElements = "data_elements"
    }

    init(
        purposeUuid: String,
        productUuid: String? = nil,
        selected: Bool,
        dataElements: [ConsentDataElementPayload]?
    ) {
        self.purposeUuid = purposeUuid
        self.productUuid = productUuid
        self.selected = selected
        self.dataElements = dataElements
    }
}

public struct ConsentDataElementPayload: Encodable {
    public let uuid: String
    public let selected: Bool
}

public struct MetaData: Encodable {
    /// Empty is left out of the payload.
    public let specificUuid: String
    public let minorAge: Int?

    enum CodingKeys: String, CodingKey {
        case specificUuid = "specific_uuid"
        case minorAge = "minor_age"
    }

    public init(specificUuid: String = "", minorAge: Int? = nil) {
        self.specificUuid = specificUuid
        self.minorAge = minorAge
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !specificUuid.isEmpty {
            try container.encode(specificUuid, forKey: .specificUuid)
        }
        try container.encodeIfPresent(minorAge, forKey: .minorAge)
    }
}
