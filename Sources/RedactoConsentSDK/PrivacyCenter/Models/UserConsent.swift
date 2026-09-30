import Foundation

public struct ConsentDataElement: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let name: String
    public let enabled: Bool
    public let required: Bool
    public let selected: Bool

    public var id: String { uuid }
}

extension ConsentDataElement {
    enum CodingKeys: String, CodingKey {
        case uuid, name, enabled, required, selected
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        enabled = c.optional(Bool.self, forKey: .enabled) ?? true
        required = c.lenient(Bool.self, forKey: .required)
        selected = c.lenient(Bool.self, forKey: .selected)
    }
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

    /// `name || email || org_user_id`, the label every React surface shows.
    public var displayLabel: String {
        name.pcNonEmpty ?? email.pcNonEmpty ?? orgUserId
    }
}

extension NominatorInfo {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orgUserId = c.lenient(String.self, forKey: .orgUserId)
        name = c.optional(String.self, forKey: .name)
        uuid = c.lenient(String.self, forKey: .uuid)
        email = c.optional(String.self, forKey: .email)
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
    /// Admin-authored warning shown in the revoke confirmation UI for this purpose.
    /// When null/empty/absent, the localized `revokeConsentWarning` default is used.
    public let revokeWarningMessage: String?
    public let noticeUuid: String?
    /// The status as the server wrote it, for a value this SDK has no case for.
    public var statusText: String? = nil

    public var id: String { purposeUuid }

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case legacyUuid = "uuid"
        case name
        case description
        case status
        case givenDate = "given_date"
        case validTill = "valid_till"
        case method
        case dataElements = "data_elements"
        case linkReason = "link_reason"
        case revokeWarningMessage = "revoke_warning_message"
        case noticeUuid = "notice_uuid"
    }
}

extension PurposeItem {
    /// The legacy Python payload keys some purposes as `uuid`; React accepts
    /// either (groupHelpers.ts), and one malformed purpose must not blank the list.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        purposeUuid = c.optional(String.self, forKey: .purposeUuid).pcNonEmpty
            ?? c.lenient(String.self, forKey: .legacyUuid)
        name = c.lenient(String.self, forKey: .name)
        description = c.optional(String.self, forKey: .description)
        let rawStatus = c.optional(String.self, forKey: .status)
        status = c.optional(ConsentStatus.self, forKey: .status) ?? .unknown
        statusText = rawStatus
        givenDate = c.optional(String.self, forKey: .givenDate)
        validTill = c.optional(String.self, forKey: .validTill)
        method = c.lenient(String.self, forKey: .method)
        dataElements = c.lenient([ConsentDataElement].self, forKey: .dataElements)
        linkReason = c.optional(String.self, forKey: .linkReason)
        revokeWarningMessage = c.optional(String.self, forKey: .revokeWarningMessage)
        noticeUuid = c.optional(String.self, forKey: .noticeUuid)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(purposeUuid, forKey: .purposeUuid)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(givenDate, forKey: .givenDate)
        try c.encodeIfPresent(validTill, forKey: .validTill)
        try c.encode(method, forKey: .method)
        try c.encode(dataElements, forKey: .dataElements)
        try c.encodeIfPresent(linkReason, forKey: .linkReason)
        try c.encodeIfPresent(revokeWarningMessage, forKey: .revokeWarningMessage)
        try c.encodeIfPresent(noticeUuid, forKey: .noticeUuid)
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

extension ConsentGroup {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productUuid = c.lenient(String.self, forKey: .productUuid)
        productName = c.lenient(String.self, forKey: .productName)
        productDescription = c.optional(String.self, forKey: .productDescription)
        nominator = c.optional(NominatorInfo.self, forKey: .nominator)
        purposes = c.lenient([PurposeItem].self, forKey: .purposes)
        totalPurposes = c.optional(Int.self, forKey: .totalPurposes) ?? purposes.count
        activePurposes = c.lenient(Int.self, forKey: .activePurposes)
        hasMorePurposes = c.lenient(Bool.self, forKey: .hasMorePurposes)
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
    /// Admin-authored warning shown in the revoke confirmation UI for this purpose.
    /// When null/empty/absent, the localized `revokeConsentWarning` default is used.
    public let revokeWarningMessage: String?
    public let noticeUuid: String?
    /// The status as the server wrote it, for a value this SDK has no case for.
    public var statusText: String? = nil

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
        case revokeWarningMessage = "revoke_warning_message"
        case noticeUuid = "notice_uuid"
    }
}

extension UserConsent {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        purposeUuid = c.optional(String.self, forKey: .purposeUuid)
        purpose = c.lenient(String.self, forKey: .purpose)
        purposeDescription = c.lenient(String.self, forKey: .purposeDescription)
        status = c.optional(ConsentStatus.self, forKey: .status) ?? .unknown
        statusText = c.optional(String.self, forKey: .status)
        givenDate = c.lenient(String.self, forKey: .givenDate)
        validTill = c.optional(String.self, forKey: .validTill)
        method = c.lenient(String.self, forKey: .method)
        dataElements = c.lenient([ConsentDataElement].self, forKey: .dataElements)
        productUuid = c.optional(String.self, forKey: .productUuid)
        productName = c.optional(String.self, forKey: .productName)
        productDescription = c.optional(String.self, forKey: .productDescription)
        nominatorInfo = c.optional(NominatorInfo.self, forKey: .nominatorInfo)
        revokeWarningMessage = c.optional(String.self, forKey: .revokeWarningMessage)
        noticeUuid = c.optional(String.self, forKey: .noticeUuid)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(purposeUuid, forKey: .purposeUuid)
        try c.encode(purpose, forKey: .purpose)
        try c.encode(purposeDescription, forKey: .purposeDescription)
        try c.encode(status, forKey: .status)
        try c.encode(givenDate, forKey: .givenDate)
        try c.encodeIfPresent(validTill, forKey: .validTill)
        try c.encode(method, forKey: .method)
        try c.encode(dataElements, forKey: .dataElements)
        try c.encodeIfPresent(productUuid, forKey: .productUuid)
        try c.encodeIfPresent(productName, forKey: .productName)
        try c.encodeIfPresent(productDescription, forKey: .productDescription)
        try c.encodeIfPresent(nominatorInfo, forKey: .nominatorInfo)
        try c.encodeIfPresent(revokeWarningMessage, forKey: .revokeWarningMessage)
        try c.encodeIfPresent(noticeUuid, forKey: .noticeUuid)
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

extension ProductConsentHistoryGroup {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productUuid = c.lenient(String.self, forKey: .productUuid)
        productName = c.lenient(String.self, forKey: .productName)
        productDescription = c.optional(String.self, forKey: .productDescription)
        purposes = c.lenient([UserConsent].self, forKey: .purposes)
        totalPurposes = c.optional(Int.self, forKey: .totalPurposes) ?? purposes.count
        activePurposes = c.lenient(Int.self, forKey: .activePurposes)
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

extension ConsentHistoryStatusSummary {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalPurposes = c.lenient(Int.self, forKey: .totalPurposes)
        directPurposes = c.lenient(Int.self, forKey: .directPurposes)
        nominatedPurposes = c.lenient(Int.self, forKey: .nominatedPurposes)
        nomineePurposes = c.optional(Int.self, forKey: .nomineePurposes)
        activePurposes = c.lenient(Int.self, forKey: .activePurposes)
        inactivePurposes = c.lenient(Int.self, forKey: .inactivePurposes)
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

extension UserConsentDetail {
    /// Each block reads on its own, so an unexpected `user_status` or a
    /// malformed legacy group never costs the person their consent list.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = c.optional([UserConsent].self, forKey: .data)
        productPurposeGroups = c.optional([ProductConsentHistoryGroup].self, forKey: .productPurposeGroups)
        pagination = c.optional(Pagination.self, forKey: .pagination)
        directProductGroups = c.optional([ProductConsentHistoryGroup].self, forKey: .directProductGroups)
        userStatus = c.optional(UserStatus.self, forKey: .userStatus)
        nominatedPurposes = c.optional([NominatedPurposesGroup].self, forKey: .nominatedPurposes)
        nominators = c.optional([NominatorInfo].self, forKey: .nominators)
        statusSummary = c.optional(ConsentHistoryStatusSummary.self, forKey: .statusSummary)
        direct = c.optional([ConsentGroup].self, forKey: .direct)
        nominated = c.optional([ConsentGroup].self, forKey: .nominated)
        directPagination = c.optional(Pagination.self, forKey: .directPagination)
        nominatedPagination = c.optional(Pagination.self, forKey: .nominatedPagination)
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
                            nominatorInfo: entry.nominatorInfo,
                            revokeWarningMessage: purpose.revokeWarningMessage,
                            noticeUuid: purpose.noticeUuid,
                            statusText: purpose.statusText
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
                userConsent(
                    from: purpose,
                    productUuid: group.productUuid,
                    productName: group.productName,
                    productDescription: group.productDescription,
                    nominator: group.nominator
                )
            },
            totalPurposes: group.totalPurposes,
            activePurposes: group.activePurposes
        )
    }

    public static func userConsent(
        from purpose: PurposeItem,
        productUuid: String,
        productName: String,
        productDescription: String?,
        nominator: NominatorInfo?
    ) -> UserConsent {
        UserConsent(
            purposeUuid: purpose.purposeUuid,
            purpose: purpose.name,
            purposeDescription: purpose.description ?? "",
            status: purpose.status,
            givenDate: purpose.givenDate ?? "",
            validTill: purpose.validTill,
            method: purpose.method,
            dataElements: purpose.dataElements,
            productUuid: productUuid,
            productName: productName,
            productDescription: productDescription,
            nominatorInfo: nominator,
            revokeWarningMessage: purpose.revokeWarningMessage,
            noticeUuid: purpose.noticeUuid,
            statusText: purpose.statusText
        )
    }
}
