import Foundation

/// What was asked for in a case, as the Request Details tab shows it (React
/// `CaseRequestDetails`). The server sends empty collections as nulls.
public struct CaseRequestDetails: Codable, Sendable, Equatable {
    public let purposes: [RawPurposeWrapper]
    public let correctionData: [UpdateCorrectionDataItem]
    /// Raw grievance values (`consent_violation`, …); one this SDK has no case
    /// for still prints.
    public let grievanceTypes: [String]
    public let nominationData: NominationData?

    enum CodingKeys: String, CodingKey {
        case purposes
        case correctionData = "correction_data"
        case grievanceTypes = "grievance_types"
        case nominationData = "nomination_data"
    }

    private struct GrievanceEntry: Decodable {
        let grievance: String?
    }

    public init(
        purposes: [RawPurposeWrapper] = [],
        correctionData: [UpdateCorrectionDataItem] = [],
        grievanceTypes: [String] = [],
        nominationData: NominationData? = nil
    ) {
        self.purposes = purposes
        self.correctionData = correctionData
        self.grievanceTypes = grievanceTypes
        self.nominationData = nominationData
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        purposes = c.lenient([LenientElement<RawPurposeWrapper>].self, forKey: .purposes).compactMap(\.value)
        correctionData = c.lenient([UpdateCorrectionDataItem].self, forKey: .correctionData)
        grievanceTypes = c.lenient([GrievanceEntry].self, forKey: .grievanceTypes).compactMap { $0.grievance.pcNonEmpty }
        nominationData = c.optional(NominationData.self, forKey: .nominationData)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(purposes, forKey: .purposes)
        try c.encode(correctionData, forKey: .correctionData)
        try c.encode(grievanceTypes.map { ["grievance": $0] }, forKey: .grievanceTypes)
        try c.encodeIfPresent(nominationData, forKey: .nominationData)
    }
}

public struct CaseRequest: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let caseId: String
    public let rawStatus: String?
    public let statusDisplay: String?
    public let rawRequestType: String?
    public let requestTypeDisplay: String?
    public let rawDescription: String?
    public let descriptionDisplay: String?
    public let rawCreatedAt: String?
    public let completedAt: String?
    public let dueDate: String?
    public let name: String?
    public let contact: String?
    public let requestDetails: CaseRequestDetails?
    public let productUuid: String?
    public let productName: String?
    public let dataPrincipalUuid: String?
    public let requestorUuid: String?
    public let nominatorUuid: String?

    public var id: String { uuid }
    public var status: String { statusDisplay ?? rawStatus ?? "" }
    public var requestType: String { requestTypeDisplay ?? rawRequestType ?? "" }
    public var description: String { descriptionDisplay ?? rawDescription ?? "" }
    public var createdAt: String { rawCreatedAt ?? "" }

    public init(
        uuid: String,
        caseId: String,
        status: String? = nil,
        statusDisplay: String? = nil,
        requestType: String? = nil,
        requestTypeDisplay: String? = nil,
        description: String? = nil,
        descriptionDisplay: String? = nil,
        createdAt: String? = nil,
        completedAt: String? = nil,
        dueDate: String? = nil,
        name: String? = nil,
        contact: String? = nil,
        requestDetails: CaseRequestDetails? = nil,
        productUuid: String? = nil,
        productName: String? = nil,
        dataPrincipalUuid: String? = nil,
        requestorUuid: String? = nil,
        nominatorUuid: String? = nil
    ) {
        self.uuid = uuid
        self.caseId = caseId
        self.rawStatus = status
        self.statusDisplay = statusDisplay
        self.rawRequestType = requestType
        self.requestTypeDisplay = requestTypeDisplay
        self.rawDescription = description
        self.descriptionDisplay = descriptionDisplay
        self.rawCreatedAt = createdAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.name = name
        self.contact = contact
        self.requestDetails = requestDetails
        self.productUuid = productUuid
        self.productName = productName
        self.dataPrincipalUuid = dataPrincipalUuid
        self.requestorUuid = requestorUuid
        self.nominatorUuid = nominatorUuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case caseId = "case_id"
        case rawStatus = "status"
        case statusDisplay = "status_display"
        case rawRequestType = "request_type"
        case requestTypeDisplay = "request_type_display"
        case rawDescription = "description"
        case descriptionDisplay = "description_display"
        case rawCreatedAt = "created_at"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case name
        case contact
        case requestDetails = "request_details"
        case productUuid = "product_uuid"
        case productName = "product_name"
        case dataPrincipalUuid = "data_principal_uuid"
        case requestorUuid = "requestor_uuid"
        case nominatorUuid = "nominator_uuid"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        caseId = c.lenient(String.self, forKey: .caseId)
        rawStatus = c.optional(String.self, forKey: .rawStatus)
        statusDisplay = c.optional(String.self, forKey: .statusDisplay)
        rawRequestType = c.optional(String.self, forKey: .rawRequestType)
        requestTypeDisplay = c.optional(String.self, forKey: .requestTypeDisplay)
        rawDescription = c.optional(String.self, forKey: .rawDescription)
        descriptionDisplay = c.optional(String.self, forKey: .descriptionDisplay)
        rawCreatedAt = c.optional(String.self, forKey: .rawCreatedAt)
        completedAt = c.optional(String.self, forKey: .completedAt)
        dueDate = c.optional(String.self, forKey: .dueDate)
        name = c.optional(String.self, forKey: .name)
        contact = c.optional(String.self, forKey: .contact)
        requestDetails = c.optional(CaseRequestDetails.self, forKey: .requestDetails)
        productUuid = c.optional(String.self, forKey: .productUuid)
        productName = c.optional(String.self, forKey: .productName)
        dataPrincipalUuid = c.optional(String.self, forKey: .dataPrincipalUuid)
        requestorUuid = c.optional(String.self, forKey: .requestorUuid)
        nominatorUuid = c.optional(String.self, forKey: .nominatorUuid)
    }

    /// The raw status React branches on (tabs, badge colour, finalized check).
    public var statusKey: String { (rawStatus ?? statusDisplay ?? "").lowercased() }

    /// `status_display || formatCaseStatus(status)`.
    public var displayStatus: String {
        if let display = statusDisplay.pcNonEmpty { return display }
        return (rawStatus ?? "")
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// `request_type_display || request_type.replace('_', ' ')`, capitalised
    /// the way React's `textTransform: capitalize` draws the raw value.
    public var displayRequestType: String {
        if let display = requestTypeDisplay.pcNonEmpty { return display }
        return (rawRequestType ?? "").replacingOccurrences(of: "_", with: " ").pcCapitalized
    }

    /// Completed, rejected, declined and expired cases take no more messages.
    public var isFinalized: Bool {
        ["completed", "rejected", "declined", "expired"].contains((rawStatus ?? "").lowercased())
    }
}

public struct CaseHistoryDetail: Codable, Sendable, Equatable {
    public let data: [CaseRequest]?
    public let pagination: Pagination?

    public var items: [CaseRequest] { data ?? [] }
    public var page: Pagination { pagination ?? Pagination(totalCount: 0, offset: 0, limit: 10) }
}

public struct CreateCaseDetail: Codable, Sendable, Equatable {
    public let uuid: String?
    public let caseId: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case caseId = "case_id"
    }

    public init(uuid: String?, caseId: String) {
        self.uuid = uuid
        self.caseId = caseId
    }

    /// React `extractCaseId`: the case id, else the uuid.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.optional(String.self, forKey: .uuid)
        caseId = c.optional(String.self, forKey: .caseId).pcNonEmpty ?? uuid ?? ""
    }
}
