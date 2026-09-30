import Foundation

public struct NoticeProduct: Codable, Equatable {
    public let uuid: String
    public let name: String
    public let description: String?
    public let mandatory: Bool?

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, mandatory
    }

    public init(uuid: String, name: String, description: String? = nil, mandatory: Bool? = nil) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.mandatory = mandatory
    }
}

public struct ProductPolicyLink: Equatable {
    public let uuid: String
    public let name: String
    public let url: String
}

struct NoticePurposeRow {
    let purpose: ActiveConfigPurpose
    let productUuid: String?
}

struct ProductPurposeGroup {
    let product: NoticeProduct
    let purposes: [ActiveConfigPurpose]
}

typealias RecordedLookup = (_ purposeUuid: String, _ productUuid: String?) -> PurposeSelection?

enum ConfirmReason: Equatable {
    case ok
    case nothingChosen
    case nothingEngaged
    case productIncomplete
    case requiredOutstanding
}

struct ConfirmVerdict: Equatable {
    let ok: Bool
    let reason: ConfirmReason
    let blocking: [String]

    init(ok: Bool, reason: ConfirmReason, blocking: [String] = []) {
        self.ok = ok
        self.reason = reason
        self.blocking = blocking
    }
}

struct SettledProducts: Equatable {
    let consentedProducts: [String: Bool]
    let consentedPurposes: [String: Bool]
}

struct ProductSectionSummary: Equatable {
    let purposeCount: Int
    let requiredOnly: Bool
    let allSelected: Bool
    let someSelected: Bool

    var mixed: Bool { someSelected && !allSelected }
}
