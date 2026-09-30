import Foundation

public struct PrivacyDataElement: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let name: String
    public let description: String
    public let enabled: Bool
    public let required: Bool
    public let givenConsent: Bool
    public let selected: Bool

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, enabled, required, selected
        case givenConsent = "given_consent"
    }

    public init(uuid: String, name: String, description: String = "", enabled: Bool = true, required: Bool = false, givenConsent: Bool = false, selected: Bool = false) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.enabled = enabled
        self.required = required
        self.givenConsent = givenConsent
        self.selected = selected
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        description = c.lenient(String.self, forKey: .description)
        enabled = c.optional(Bool.self, forKey: .enabled) ?? true
        required = c.lenient(Bool.self, forKey: .required)
        givenConsent = c.lenient(Bool.self, forKey: .givenConsent)
        selected = c.lenient(Bool.self, forKey: .selected)
    }
}

public struct PrivacyPurpose: Codable, Sendable, Identifiable, Equatable {
    public let uuid: String
    public let name: String
    public let description: String
    public let industries: String
    public let selected: Bool
    public let givenConsent: Bool
    public let dataElements: [PrivacyDataElement]
    public let status: String?
    public let validity: Int?
    public let purposeUuid: String?
    public let enabled: Bool?

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, industries, selected
        case givenConsent = "given_consent"
        case dataElements = "data_elements"
        case status, validity
        case purposeUuid = "purpose_uuid"
        case enabled
    }

    public init(
        uuid: String,
        name: String,
        description: String = "",
        industries: String = "",
        selected: Bool = false,
        givenConsent: Bool = false,
        dataElements: [PrivacyDataElement] = [],
        status: String? = nil,
        validity: Int? = nil,
        purposeUuid: String? = nil,
        enabled: Bool? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.industries = industries
        self.selected = selected
        self.givenConsent = givenConsent
        self.dataElements = dataElements
        self.status = status
        self.validity = validity
        self.purposeUuid = purposeUuid
        self.enabled = enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        purposeUuid = c.optional(String.self, forKey: .purposeUuid)
        uuid = c.optional(String.self, forKey: .uuid).pcNonEmpty ?? purposeUuid ?? ""
        name = c.lenient(String.self, forKey: .name)
        description = c.lenient(String.self, forKey: .description)
        industries = c.lenient(String.self, forKey: .industries)
        selected = c.lenient(Bool.self, forKey: .selected)
        givenConsent = c.lenient(Bool.self, forKey: .givenConsent)
        dataElements = c.lenient([PrivacyDataElement].self, forKey: .dataElements)
        status = c.optional(String.self, forKey: .status)
        validity = c.optional(Int.self, forKey: .validity)
        enabled = c.optional(Bool.self, forKey: .enabled)
    }
}

public struct RawPurposeWrapper: Codable, Sendable, Identifiable, Equatable {
    public let purpose: PrivacyPurpose

    public var id: String { purpose.uuid }

    public init(purpose: PrivacyPurpose) {
        self.purpose = purpose
    }
}

public struct GrievanceOption: Codable, Sendable, Identifiable, Equatable {
    public let value: GrievanceType
    public let label: String

    public var id: String { value.rawValue }
}

/// A product the request form can scope a case to (React `FormProductGroup`).
public struct FormProductGroup: Codable, Sendable, Identifiable, Equatable {
    public let productUuid: String
    public let productName: String
    public let productDescription: String?
    public let nominator: NominatorInfo?
    public let purposes: [PrivacyPurpose]

    /// React `productGroupKey`: the same product reached directly and through a
    /// nominator are two separate choices.
    public var id: String {
        guard let nominator else { return productUuid }
        return "\(productUuid):\(nominator.uuid)"
    }

    enum CodingKeys: String, CodingKey {
        case productUuid = "product_uuid"
        case productName = "product_name"
        case productDescription = "product_description"
        case nominator, purposes
    }

    public init(productUuid: String, productName: String, productDescription: String? = nil, nominator: NominatorInfo? = nil, purposes: [PrivacyPurpose]) {
        self.productUuid = productUuid
        self.productName = productName
        self.productDescription = productDescription
        self.nominator = nominator
        self.purposes = purposes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productUuid = c.lenient(String.self, forKey: .productUuid)
        productName = c.lenient(String.self, forKey: .productName)
        productDescription = c.optional(String.self, forKey: .productDescription)
        nominator = c.optional(NominatorInfo.self, forKey: .nominator)
        purposes = c.lenient([PrivacyPurpose].self, forKey: .purposes)
    }
}

public struct PrivacyFormData: Codable, Sendable, Equatable {
    public let uuid: String
    public let name: String
    public let contact: String
    public let grievanceOptions: [GrievanceOption]
    public let purposes: [RawPurposeWrapper]
    public var directGroups: [FormProductGroup]? = nil
    public var nominatedGroups: [FormProductGroup]? = nil

    enum CodingKeys: String, CodingKey {
        case uuid, name, contact, purposes
        case grievanceOptions = "grievance_options"
        case directGroups = "direct_groups"
        case nominatedGroups = "nominated_groups"
    }

    public init(
        uuid: String,
        name: String,
        contact: String,
        grievanceOptions: [GrievanceOption] = [],
        purposes: [RawPurposeWrapper] = [],
        directGroups: [FormProductGroup]? = nil,
        nominatedGroups: [FormProductGroup]? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.contact = contact
        self.grievanceOptions = grievanceOptions
        self.purposes = purposes
        self.directGroups = directGroups
        self.nominatedGroups = nominatedGroups
    }

    /// An option or purpose this SDK cannot read is dropped rather than failing
    /// the whole form.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        contact = c.lenient(String.self, forKey: .contact)
        grievanceOptions = c.lenient([LenientElement<GrievanceOption>].self, forKey: .grievanceOptions).compactMap(\.value)
        purposes = c.lenient([LenientElement<RawPurposeWrapper>].self, forKey: .purposes).compactMap(\.value)
        directGroups = c.optional([FormProductGroup].self, forKey: .directGroups)
        nominatedGroups = c.optional([FormProductGroup].self, forKey: .nominatedGroups)
    }
}

/// Decodes an array element or nothing, so one bad entry is skipped.
struct LenientElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

public struct UpdatePurpose: Codable, Sendable, Equatable {
    public let purposeUuid: String
    public let dataElementUuids: [String]

    public init(purposeUuid: String, dataElementUuids: [String]) {
        self.purposeUuid = purposeUuid
        self.dataElementUuids = dataElementUuids
    }

    enum CodingKeys: String, CodingKey {
        case purposeUuid = "purpose_uuid"
        case dataElementUuids = "data_element_uuids"
    }
}

public struct UpdateCorrectionDataItem: Codable, Sendable, Equatable {
    public let name: String
    public let currValue: String
    public let newValue: String

    public init(name: String, currValue: String, newValue: String) {
        self.name = name
        self.currValue = currValue
        self.newValue = newValue
    }

    enum CodingKeys: String, CodingKey {
        case name
        case currValue = "curr_value"
        case newValue = "new_value"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenient(String.self, forKey: .name)
        currValue = c.lenient(String.self, forKey: .currValue)
        newValue = c.lenient(String.self, forKey: .newValue)
    }
}

public struct GrievanceTypeElement: Codable, Sendable, Equatable {
    public let grievance: GrievanceType

    public init(grievance: GrievanceType) {
        self.grievance = grievance
    }
}

public struct NominationData: Codable, Sendable, Equatable {
    public var nomineeEmail: String
    public var nomineeMobile: String?

    public init(nomineeEmail: String = "", nomineeMobile: String? = nil) {
        self.nomineeEmail = nomineeEmail
        self.nomineeMobile = nomineeMobile
    }

    enum CodingKeys: String, CodingKey {
        case nomineeEmail = "nominee_email"
        case nomineeMobile = "nominee_mobile"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomineeEmail = c.lenient(String.self, forKey: .nomineeEmail)
        nomineeMobile = c.optional(String.self, forKey: .nomineeMobile)
    }

    /// Either contact may be given alone (React 10.2.2-beta.2); an empty one is
    /// left out rather than sent blank.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if !nomineeEmail.isEmpty { try c.encode(nomineeEmail, forKey: .nomineeEmail) }
        if let nomineeMobile, !nomineeMobile.isEmpty { try c.encode(nomineeMobile, forKey: .nomineeMobile) }
    }
}

public struct UserDataRequestDetails: Codable, Sendable, Equatable {
    public let purposes: [UpdatePurpose]
    public let correctionData: [UpdateCorrectionDataItem]
    public let grievanceTypes: [GrievanceTypeElement]
    public let nominationData: NominationData?

    public init(
        purposes: [UpdatePurpose] = [],
        correctionData: [UpdateCorrectionDataItem] = [],
        grievanceTypes: [GrievanceTypeElement] = [],
        nominationData: NominationData? = nil
    ) {
        self.purposes = purposes
        self.correctionData = correctionData
        self.grievanceTypes = grievanceTypes
        self.nominationData = nominationData
    }

    enum CodingKeys: String, CodingKey {
        case purposes
        case correctionData = "correction_data"
        case grievanceTypes = "grievance_types"
        case nominationData = "nomination_data"
    }
}

public struct UserDataRequest: Codable, Sendable, Equatable {
    public let uuid: String
    public let name: String
    public let contact: String
    public let requestType: RequestType
    public let supportingDocsUuids: [String]
    public let requestDetails: UserDataRequestDetails
    public let timePeriod: Int?
    public let requestorNote: String
    /// ERASURE only: whether the consents behind the erased purposes are also
    /// revoked once the request is fulfilled.
    public let revokeConsentOnFulfilment: Bool?
    /// The product the case is scoped to (ACCESS / ERASURE / CORRECTION).
    public let productUuid: String?
    /// Set only when a nominee acts on a nominator's product; the server
    /// defaults a direct case's principal from the token.
    public let dataPrincipalUuid: String?

    public init(
        uuid: String,
        name: String,
        contact: String,
        requestType: RequestType,
        supportingDocsUuids: [String] = [],
        requestDetails: UserDataRequestDetails = UserDataRequestDetails(),
        timePeriod: Int? = nil,
        requestorNote: String = "",
        revokeConsentOnFulfilment: Bool? = nil,
        productUuid: String? = nil,
        dataPrincipalUuid: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.contact = contact
        self.requestType = requestType
        self.supportingDocsUuids = supportingDocsUuids
        self.requestDetails = requestDetails
        self.timePeriod = timePeriod
        self.requestorNote = requestorNote
        self.revokeConsentOnFulfilment = revokeConsentOnFulfilment
        self.productUuid = productUuid
        self.dataPrincipalUuid = dataPrincipalUuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid, name, contact
        case requestType = "request_type"
        case supportingDocsUuids = "supporting_docs_uuids"
        case requestDetails = "request_details"
        case timePeriod = "time_period"
        case requestorNote = "requestor_note"
        case revokeConsentOnFulfilment = "revoke_consent_on_fulfilment"
        case productUuid = "product_uuid"
        case dataPrincipalUuid = "data_principal_uuid"
    }
}
