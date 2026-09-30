import Foundation

public struct ConsentContent: Codable {
    public let code: Int
    public let status: String
    public let detail: ConsentDetail

    enum CodingKeys: String, CodingKey {
        case code, status, detail
    }
}

public struct ConsentDetail: Codable {
    public let uuid: String
    public let name: String
    public let organisationUuid: String
    public let workspaceUuid: String
    public let collectionPointUuids: [String]
    public let collectionPoints: [CollectionPoint]
    public let activeConfig: ActiveConfig
    public let noticeType: String?
    public let complianceRequirement: String?
    public let isMinor: Bool?
    public let purposeSelections: [String: PurposeSelection]?
    public var productPurposeSelections: [String: [String: PurposeSelection]]?
    public let reconsentRequired: Bool?
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case uuid, name
        case organisationUuid = "organisation_uuid"
        case workspaceUuid = "workspace_uuid"
        case collectionPointUuids = "collection_point_uuids"
        case collectionPoints = "collection_points"
        case activeConfig = "active_config"
        case noticeType = "notice_type"
        case complianceRequirement = "compliance_requirement"
        case isMinor = "is_minor"
        case purposeSelections = "purpose_selections"
        case productPurposeSelections = "product_purpose_selections"
        case reconsentRequired = "reconsent_required"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct CollectionPoint: Codable {
    public let uuid: String
    public let organisationUuid: String
    public let workspaceUuid: String
    public let name: String
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case uuid, name
        case organisationUuid = "organisation_uuid"
        case workspaceUuid = "workspace_uuid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct ActiveConfig: Codable {
    public let uuid: String
    public let noticeUuid: String
    public let organisationUuid: String
    public let workspaceUuid: String
    public let version: Int
    public let status: String
    public let noticeText: String
    public let additionalText: String
    /// Optional: absent from an older consent-server. The notice falls back to
    /// the bundled English defaults in `NoticeButtonDefaults`.
    public let acceptAllButtonText: String?
    /// The "accept selected" slot — submits exactly what the user ticked.
    public let confirmButtonText: String
    public let declineButtonText: String
    public let logoUrl: String
    public let privacyPolicyUrl: String
    public let privacyCenterUrl: String
    public let primaryColor: String
    public let secondaryColor: String
    public let fontPreference: String
    public let purposes: [ActiveConfigPurpose]
    public let defaultLanguage: String
    public let supportedLanguagesAndTranslations: [String: LanguageTranslation]
    public let createdAt: String
    public let updatedAt: String
    public let deployedAt: String
    public let privacyPolicyPrefixText: String
    public let privacyPolicyAnchorText: String
    public let privacyCenterAnchorText: String?
    public let purposeSectionHeading: String
    public let noticeBannerHeading: String
    public let dpoInfo: DpoInfo?
    public var products: [NoticeProduct]?
    public var productPurposeOrder: [String: [String]]?
    public var productPrivacyPolicies: [String: String]?
    public var purposePreselection: String?
    public var logoPosition: String?
    /// The look the admin set in the Redacto console. Absent (an older server)
    /// or empty means classic, drawn from the primary and secondary colours.
    public var appearance: NoticeAppearance?

    enum CodingKeys: String, CodingKey {
        case uuid, purposes, status
        case noticeUuid = "notice_uuid"
        case organisationUuid = "organisation_uuid"
        case workspaceUuid = "workspace_uuid"
        case version
        case noticeText = "notice_text"
        case additionalText = "additional_text"
        case acceptAllButtonText = "accept_all_button_text"
        case confirmButtonText = "confirm_button_text"
        case declineButtonText = "decline_button_text"
        case logoUrl = "logo_url"
        case privacyPolicyUrl = "privacy_policy_url"
        case privacyCenterUrl = "privacy_center_url"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case fontPreference = "font_preference"
        case defaultLanguage = "default_language"
        case supportedLanguagesAndTranslations = "supported_languages_and_translations"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deployedAt = "deployed_at"
        case privacyPolicyPrefixText = "privacy_policy_prefix_text"
        case privacyPolicyAnchorText = "privacy_policy_anchor_text"
        case privacyCenterAnchorText = "privacy_center_anchor_text"
        case purposeSectionHeading = "purpose_section_heading"
        case noticeBannerHeading = "notice_banner_heading"
        case dpoInfo = "dpo_info"
        case products
        case productPurposeOrder = "product_purpose_order"
        case productPrivacyPolicies = "product_privacy_policies"
        case purposePreselection = "purpose_preselection"
        case logoPosition = "logo_position"
        case appearance
    }
}

public struct ActiveConfigPurpose: Codable {
    public let uuid: String
    public let name: String
    public let description: String
    public let industries: String?
    public let dataElements: [ActiveConfigDataElement]
    public var productUuids: [String]?

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, industries
        case dataElements = "data_elements"
        case productUuids = "product_uuids"
    }
}

public struct ActiveConfigDataElement: Codable {
    public let uuid: String
    public let name: String
    public let description: String?
    public let industries: String?
    public let enabled: Bool
    public let required: Bool

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, industries, enabled, required
    }
}
