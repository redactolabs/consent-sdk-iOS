import Foundation

public struct Purpose: Codable {
    public let uuid: String
    public let name: String
    public let description: String
    public let industries: String?
    public var selected: Bool
    public var dataElements: [DataElement]

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, industries, selected
        case dataElements = "data_elements"
    }

    public init(uuid: String, name: String, description: String, industries: String? = nil, selected: Bool, dataElements: [DataElement]) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.industries = industries
        self.selected = selected
        self.dataElements = dataElements
    }
}

public struct DataElement: Codable {
    public let uuid: String
    public let name: String
    public let description: String?
    public let industries: String?
    public let enabled: Bool
    public let required: Bool
    public var selected: Bool

    public init(uuid: String, name: String, description: String? = nil, industries: String? = nil, enabled: Bool, required: Bool, selected: Bool) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.industries = industries
        self.enabled = enabled
        self.required = required
        self.selected = selected
    }
}

public struct PurposeSelection: Codable {
    public let selected: Bool
    public let status: String
    public let needsReconsent: Bool
    public let dataElements: [String: DataElementSelection]

    enum CodingKeys: String, CodingKey {
        case selected, status
        case needsReconsent = "needs_reconsent"
        case dataElements = "data_elements"
    }
}

public struct DataElementSelection: Codable {
    public let selected: Bool
    public let enabled: Bool
    public let required: Bool
}
