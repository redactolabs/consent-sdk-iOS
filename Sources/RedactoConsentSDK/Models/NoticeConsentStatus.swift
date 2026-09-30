import Foundation

public struct NoticeConsentStatusParams {
    public let accessToken: String
    public let ledgerBaseUrl: String?
    public let organisationUuid: String
    public let workspaceUuid: String
    public let noticeUuid: String

    public init(
        accessToken: String,
        ledgerBaseUrl: String?,
        organisationUuid: String,
        workspaceUuid: String,
        noticeUuid: String
    ) {
        self.accessToken = accessToken
        self.ledgerBaseUrl = ledgerBaseUrl
        self.organisationUuid = organisationUuid
        self.workspaceUuid = workspaceUuid
        self.noticeUuid = noticeUuid
    }
}

public struct NoticeConsentStatus: Decodable, Equatable {
    public let consented: Bool
    public let allMandatoryActive: Bool
    public let purposes: [NoticeConsentStatusPurpose]
    public let byProduct: [NoticeConsentStatusProduct]?

    public var isFullyConsented: Bool {
        consented && allMandatoryActive
    }

    enum CodingKeys: String, CodingKey {
        case consented, purposes
        case allMandatoryActive = "all_mandatory_active"
        case byProduct = "by_product"
    }
}

public struct NoticeConsentStatusProduct: Decodable, Equatable {
    public let productUuid: String
    public let consented: Bool
    public let allMandatoryActive: Bool
    public let purposes: [NoticeConsentStatusPurpose]

    enum CodingKeys: String, CodingKey {
        case consented, purposes
        case productUuid = "product_uuid"
        case allMandatoryActive = "all_mandatory_active"
    }
}

public struct NoticeConsentStatusPurpose: Decodable, Equatable {
    public let uuid: String
    public let name: String
    public let selected: Bool
    public let status: String
    public let expiryDatetime: String?
    public let dataElements: [NoticeConsentStatusDataElement]

    enum CodingKeys: String, CodingKey {
        case uuid, name, selected, status
        case expiryDatetime = "expiry_datetime"
        case dataElements = "data_elements"
    }
}

public struct NoticeConsentStatusDataElement: Decodable, Equatable {
    public let uuid: String
    public let name: String
    public let selected: Bool
}

struct NoticeConsentStatusEnvelope: Decodable {
    let detail: NoticeConsentStatus
}
