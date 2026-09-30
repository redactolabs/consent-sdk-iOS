import Foundation

public struct ManageConsentRequest: Sendable, Equatable {
    public let purposeUuid: String
    public let contact: String
    public let action: ConsentAction
    public let productUuid: String?
    public let noticeUuid: String?
    public let dataElements: [ConsentDataElement]
    public let dataElementUuids: [String]?
    public let nominatorContact: String?
    public let nominatorUuid: String?
    public let language: String?

    public init(
        purposeUuid: String,
        contact: String,
        action: ConsentAction,
        productUuid: String? = nil,
        noticeUuid: String? = nil,
        dataElements: [ConsentDataElement] = [],
        dataElementUuids: [String]? = nil,
        nominatorContact: String? = nil,
        nominatorUuid: String? = nil,
        language: String? = nil
    ) {
        self.purposeUuid = purposeUuid
        self.contact = contact
        self.action = action
        self.productUuid = productUuid.pcNonEmpty
        self.noticeUuid = noticeUuid.pcNonEmpty
        self.dataElements = dataElements
        self.dataElementUuids = dataElementUuids
        self.nominatorContact = nominatorContact.pcNonEmpty
        self.nominatorUuid = nominatorUuid.pcNonEmpty
        self.language = language.pcNonEmpty
    }
}

struct LegacyManageConsentBody: Encodable {
    let purpose_uuid: String
    let contact: String
    let nominator_contact: String?
    let data_element_uuids: [String]?
    let product_uuid: String?
    let language: String?
}

struct LegacyManageConsentResult: Decodable {
    let success: Bool?
}

struct LedgerDataElementSelection: Encodable, Equatable {
    let uuid: String
    let selected: Bool
}

struct LedgerPurposeSelection: Encodable {
    let purpose_uuid: String
    let product_uuid: String?
    let selected: Bool
    let data_elements: [LedgerDataElementSelection]
}

struct LedgerManageConsentBody: Encodable {
    let notice_uuid: String
    let product_uuid: String?
    let partial: Bool
    let declined: Bool
    let select_all_mandatory: Bool
    let self_declared_adult: Bool
    let purposes: [LedgerPurposeSelection]
    let language: String?
    let nominator_uuid: String?
}

public struct GroupPurposesDetail: Codable, Sendable, Equatable {
    public let purposes: [PurposeItem]
    public let pagination: Pagination?
}

extension String {
    /// CSS `text-transform: capitalize`: each word's first letter upper-cased,
    /// the rest left as written.
    var pcCapitalized: String {
        var result = ""
        var atWordStart = true
        for ch in self {
            result += atWordStart ? ch.uppercased() : String(ch)
            atWordStart = ch.isWhitespace
        }
        return result
    }
}

extension Optional where Wrapped == String {
    var pcNonEmpty: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}
