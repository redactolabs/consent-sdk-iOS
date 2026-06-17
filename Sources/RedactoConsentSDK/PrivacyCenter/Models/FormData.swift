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
}

public struct RawPurposeWrapper: Codable, Sendable, Identifiable, Equatable {
    public let purpose: PrivacyPurpose

    public var id: String { purpose.uuid }
}

public struct GrievanceOption: Codable, Sendable, Identifiable, Equatable {
    public let value: GrievanceType
    public let label: String

    public var id: String { value.rawValue }
}

public struct PrivacyFormData: Codable, Sendable, Equatable {
    public let uuid: String
    public let name: String
    public let contact: String
    public let grievanceOptions: [GrievanceOption]
    public let purposes: [RawPurposeWrapper]

    enum CodingKeys: String, CodingKey {
        case uuid, name, contact, purposes
        case grievanceOptions = "grievance_options"
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

    public init(
        uuid: String,
        name: String,
        contact: String,
        requestType: RequestType,
        supportingDocsUuids: [String] = [],
        requestDetails: UserDataRequestDetails = UserDataRequestDetails(),
        timePeriod: Int? = nil,
        requestorNote: String = ""
    ) {
        self.uuid = uuid
        self.name = name
        self.contact = contact
        self.requestType = requestType
        self.supportingDocsUuids = supportingDocsUuids
        self.requestDetails = requestDetails
        self.timePeriod = timePeriod
        self.requestorNote = requestorNote
    }

    enum CodingKeys: String, CodingKey {
        case uuid, name, contact
        case requestType = "request_type"
        case supportingDocsUuids = "supporting_docs_uuids"
        case requestDetails = "request_details"
        case timePeriod = "time_period"
        case requestorNote = "requestor_note"
    }
}
