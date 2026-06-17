import Foundation

public struct ConsentDataElement: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let name: String
    public let enabled: Bool
    public let required: Bool
    public let selected: Bool

    public var id: String { uuid }
}

public struct NominatorInfo: Codable, Sendable, Equatable, Identifiable {
    public let orgUserId: String
    public let name: String?
    public let uuid: String
    public let email: String?

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case orgUserId = "org_user_id"
        case name, uuid, email
    }
}

public struct PurposeItem: Codable, Sendable, Identifiable, Equatable {
    public let purposeUuid: String
    public let name: String
    public let description: String?
    public let status: ConsentStatus
    public let givenDate: String?
    public let validTill: String?
    public let method: String
    public let dataElements: [ConsentDataElement]
    public let linkReason: String?

    public var id: String { purposeUuid }

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case name
        case description
        case status
        case givenDate = "given_date"
        case validTill = "valid_till"
        case method
        case dataElements = "data_elements"
        case linkReason = "link_reason"
    }
}

public struct ConsentGroup: Codable, Sendable, Identifiable, Equatable {
    public let productUuid: String
    public let productName: String
    public let productDescription: String?
    public let nominator: NominatorInfo?
    public let totalPurposes: Int
    public let activePurposes: Int
    public let purposes: [PurposeItem]
    public let hasMorePurposes: Bool

    public var id: String { productUuid }

    enum CodingKeys: String, CodingKey {
        case productUuid = "product_uuid"
        case productName = "product_name"
        case productDescription = "product_description"
        case nominator
        case totalPurposes = "total_purposes"
        case activePurposes = "active_purposes"
        case purposes
        case hasMorePurposes = "has_more_purposes"
    }
}

public struct UserConsent: Codable, Sendable, Identifiable, Equatable {
    public let purposeUuid: String?
    public let purpose: String
    public let purposeDescription: String
    public let status: ConsentStatus
    public let givenDate: String
    public let validTill: String?
    public let method: String
    public let dataElements: [ConsentDataElement]
    public let productUuid: String?
    public let productName: String?
    public let productDescription: String?
    public let nominatorInfo: NominatorInfo?

    public var id: String { (purposeUuid ?? "") + "::" + (productUuid ?? "") + "::" + (nominatorInfo?.uuid ?? "") }

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case purpose
        case purposeDescription = "purpose_description"
        case status
        case givenDate = "given_date"
        case validTill = "valid_till"
        case method
        case dataElements = "data_elements"
        case productUuid = "product_uuid"
        case productName = "product_name"
        case productDescription = "product_description"
        case nominatorInfo = "nominator_info"
    }
}

public struct ProductConsentHistoryGroup: Codable, Sendable, Identifiable, Equatable {
    public let productUuid: String
    public let productName: String
    public let productDescription: String?
    public let purposes: [UserConsent]
    public let totalPurposes: Int
    public let activePurposes: Int

    public var id: String { productUuid }

    enum CodingKeys: String, CodingKey {
        case productUuid = "product_uuid"
        case productName = "product_name"
        case productDescription = "product_description"
        case purposes
        case totalPurposes = "total_purposes"
        case activePurposes = "active_purposes"
    }
}

public struct NominatedPurposesGroup: Codable, Sendable, Identifiable, Equatable {
    public let nominatorInfo: NominatorInfo
    public let productGroups: [ProductConsentHistoryGroup]

    public var id: String { nominatorInfo.uuid }

    enum CodingKeys: String, CodingKey {
        case nominatorInfo = "nominator_info"
        case productGroups = "product_groups"
    }
}

public struct ConsentHistoryStatusSummary: Codable, Sendable, Equatable {
    public let totalPurposes: Int
    public let directPurposes: Int
    public let nominatedPurposes: Int
    public let nomineePurposes: Int?
    public let activePurposes: Int
    public let inactivePurposes: Int

    enum CodingKeys: String, CodingKey {
        case totalPurposes = "total_purposes"
        case directPurposes = "direct_purposes"
        case nominatedPurposes = "nominated_purposes"
        case nomineePurposes = "nominee_purposes"
        case activePurposes = "active_purposes"
        case inactivePurposes = "inactive_purposes"
    }
}

public enum UserStatus: String, Codable, Sendable {
    case active = "ACTIVE"
    case transferred = "TRANSFERRED"
}

public struct UserConsentDetail: Codable, Sendable, Equatable {
    public let data: [UserConsent]?
    public let productPurposeGroups: [ProductConsentHistoryGroup]?
    public let pagination: Pagination?
    public let directProductGroups: [ProductConsentHistoryGroup]?
    public let userStatus: UserStatus?
    public let nominatedPurposes: [NominatedPurposesGroup]?
    public let nominators: [NominatorInfo]?
    public let statusSummary: ConsentHistoryStatusSummary?
    public let direct: [ConsentGroup]?
    public let nominated: [ConsentGroup]?
    public let directPagination: Pagination?
    public let nominatedPagination: Pagination?

    public var page: Pagination {
        directPagination ?? nominatedPagination ?? pagination ?? Pagination(totalCount: 0, offset: 0, limit: 10)
    }

    enum CodingKeys: String, CodingKey {
        case data
        case productPurposeGroups = "product_purpose_groups"
        case pagination
        case directProductGroups = "direct_product_groups"
        case userStatus = "user_status"
        case nominatedPurposes = "nominated_purposes"
        case nominators
        case statusSummary = "status_summary"
        case direct
        case nominated
        case directPagination = "direct_pagination"
        case nominatedPagination = "nominated_pagination"
    }
}

public enum ConsentManagerNormalization {
    public static func directGroups(from detail: UserConsentDetail?) -> [ProductConsentHistoryGroup] {
        guard let detail else { return [] }
        if let direct = detail.direct, !direct.isEmpty {
            return direct.map(consentGroupToProductGroup)
        }
        return detail.directProductGroups ?? detail.productPurposeGroups ?? []
    }

    public static func nominatedGroups(from detail: UserConsentDetail?) -> [ProductConsentHistoryGroup] {
        guard let detail else { return [] }
        if let nominated = detail.nominated, !nominated.isEmpty {
            return nominated.map(consentGroupToProductGroup)
        }
        guard let nominatedPurposes = detail.nominatedPurposes else { return [] }
        return nominatedPurposes.flatMap { entry in
            entry.productGroups.map { group in
                ProductConsentHistoryGroup(
                    productUuid: group.productUuid,
                    productName: group.productName,
                    productDescription: group.productDescription,
                    purposes: group.purposes.map { purpose in
                        UserConsent(
                            purposeUuid: purpose.purposeUuid,
                            purpose: purpose.purpose,
                            purposeDescription: purpose.purposeDescription,
                            status: purpose.status,
                            givenDate: purpose.givenDate,
                            validTill: purpose.validTill,
                            method: purpose.method,
                            dataElements: purpose.dataElements,
                            productUuid: purpose.productUuid,
                            productName: purpose.productName,
                            productDescription: purpose.productDescription,
                            nominatorInfo: entry.nominatorInfo
                        )
                    },
                    totalPurposes: group.totalPurposes,
                    activePurposes: group.activePurposes
                )
            }
        }
    }

    private static func consentGroupToProductGroup(_ group: ConsentGroup) -> ProductConsentHistoryGroup {
        ProductConsentHistoryGroup(
            productUuid: group.productUuid,
            productName: group.productName,
            productDescription: group.productDescription,
            purposes: group.purposes.map { purpose in
                UserConsent(
                    purposeUuid: purpose.purposeUuid,
                    purpose: purpose.name,
                    purposeDescription: purpose.description ?? "",
                    status: purpose.status,
                    givenDate: purpose.givenDate ?? "",
                    validTill: purpose.validTill,
                    method: purpose.method,
                    dataElements: purpose.dataElements,
                    productUuid: group.productUuid,
                    productName: group.productName,
                    productDescription: group.productDescription,
                    nominatorInfo: group.nominator
                )
            },
            totalPurposes: group.totalPurposes,
            activePurposes: group.activePurposes
        )
    }
}
