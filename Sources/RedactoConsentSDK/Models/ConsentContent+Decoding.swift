import Foundation

/// Both backends write a blank notice field as `null` (the ledger through
/// `strPtrOrNil`, the consent server through `Optional[...] = None`), and older
/// servers omit newer keys outright. A synthesized decoder throws on either, and
/// one throw drops the whole notice, so every field that is not an identity
/// decodes to the empty value the views already treat as "absent".
///
/// The decoders live in extensions so the memberwise initializers stay available.
extension KeyedDecodingContainer {
    func lenient(_ type: String.Type, forKey key: Key) -> String {
        ((try? decodeIfPresent(String.self, forKey: key)) ?? nil) ?? ""
    }

    func lenient(_ type: Bool.Type, forKey key: Key) -> Bool {
        ((try? decodeIfPresent(Bool.self, forKey: key)) ?? nil) ?? false
    }

    func lenient(_ type: Int.Type, forKey key: Key) -> Int {
        ((try? decodeIfPresent(Int.self, forKey: key)) ?? nil) ?? 0
    }

    func lenient<T: Decodable>(_ type: [T].Type, forKey key: Key) -> [T] {
        ((try? decodeIfPresent([T].self, forKey: key)) ?? nil) ?? []
    }

    func lenient<T: Decodable>(_ type: [String: T].Type, forKey key: Key) -> [String: T] {
        ((try? decodeIfPresent([String: T].self, forKey: key)) ?? nil) ?? [:]
    }

    /// Absent, `null` and malformed all read as `nil`, so an optional block the
    /// notice can render without never takes the notice down with it.
    func optional<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

extension ConsentContent {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenient(Int.self, forKey: .code)
        status = c.lenient(String.self, forKey: .status)
        detail = try c.decode(ConsentDetail.self, forKey: .detail)
    }
}

extension ConsentDetail {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        organisationUuid = c.lenient(String.self, forKey: .organisationUuid)
        workspaceUuid = c.lenient(String.self, forKey: .workspaceUuid)
        collectionPointUuids = c.lenient([String].self, forKey: .collectionPointUuids)
        collectionPoints = c.lenient([CollectionPoint].self, forKey: .collectionPoints)
        activeConfig = try c.decode(ActiveConfig.self, forKey: .activeConfig)
        noticeType = c.optional(String.self, forKey: .noticeType)
        complianceRequirement = c.optional(String.self, forKey: .complianceRequirement)
        isMinor = c.optional(Bool.self, forKey: .isMinor)
        purposeSelections = c.optional([String: PurposeSelection].self, forKey: .purposeSelections)
        productPurposeSelections = c.optional(
            [String: [String: PurposeSelection]].self, forKey: .productPurposeSelections
        )
        reconsentRequired = c.optional(Bool.self, forKey: .reconsentRequired)
        createdAt = c.lenient(String.self, forKey: .createdAt)
        updatedAt = c.lenient(String.self, forKey: .updatedAt)
    }
}

extension CollectionPoint {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        organisationUuid = c.lenient(String.self, forKey: .organisationUuid)
        workspaceUuid = c.lenient(String.self, forKey: .workspaceUuid)
        name = c.lenient(String.self, forKey: .name)
        createdAt = c.lenient(String.self, forKey: .createdAt)
        updatedAt = c.lenient(String.self, forKey: .updatedAt)
    }
}

extension ActiveConfig {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenient(String.self, forKey: .uuid)
        noticeUuid = c.lenient(String.self, forKey: .noticeUuid)
        organisationUuid = c.lenient(String.self, forKey: .organisationUuid)
        workspaceUuid = c.lenient(String.self, forKey: .workspaceUuid)
        version = c.lenient(Int.self, forKey: .version)
        status = c.lenient(String.self, forKey: .status)
        noticeText = c.lenient(String.self, forKey: .noticeText)
        additionalText = c.lenient(String.self, forKey: .additionalText)
        acceptAllButtonText = c.optional(String.self, forKey: .acceptAllButtonText)?.nonEmpty
        confirmButtonText = c.lenient(String.self, forKey: .confirmButtonText)
        declineButtonText = c.lenient(String.self, forKey: .declineButtonText)
        logoUrl = c.lenient(String.self, forKey: .logoUrl)
        privacyPolicyUrl = c.lenient(String.self, forKey: .privacyPolicyUrl)
        privacyCenterUrl = c.lenient(String.self, forKey: .privacyCenterUrl)
        primaryColor = c.lenient(String.self, forKey: .primaryColor)
        secondaryColor = c.lenient(String.self, forKey: .secondaryColor)
        fontPreference = c.lenient(String.self, forKey: .fontPreference)
        // The purposes are the notice: a malformed list must fail loudly, not
        // render a notice with nothing to consent to.
        purposes = try c.decodeIfPresent([ActiveConfigPurpose].self, forKey: .purposes) ?? []
        defaultLanguage = c.lenient(String.self, forKey: .defaultLanguage)
        supportedLanguagesAndTranslations = c.lenient(
            [String: LanguageTranslation].self, forKey: .supportedLanguagesAndTranslations
        )
        createdAt = c.lenient(String.self, forKey: .createdAt)
        updatedAt = c.lenient(String.self, forKey: .updatedAt)
        deployedAt = c.lenient(String.self, forKey: .deployedAt)
        privacyPolicyPrefixText = c.lenient(String.self, forKey: .privacyPolicyPrefixText)
        privacyPolicyAnchorText = c.lenient(String.self, forKey: .privacyPolicyAnchorText)
        privacyCenterAnchorText = c.optional(String.self, forKey: .privacyCenterAnchorText)
        purposeSectionHeading = c.lenient(String.self, forKey: .purposeSectionHeading)
        noticeBannerHeading = c.lenient(String.self, forKey: .noticeBannerHeading)
        dpoInfo = c.optional(DpoInfo.self, forKey: .dpoInfo)
        products = c.optional([NoticeProduct].self, forKey: .products)
        productPurposeOrder = c.optional([String: [String]].self, forKey: .productPurposeOrder)
        productPrivacyPolicies = c.optional([String: String].self, forKey: .productPrivacyPolicies)
        purposePreselection = c.optional(String.self, forKey: .purposePreselection)
        logoPosition = c.optional(String.self, forKey: .logoPosition)
        appearance = c.optional(NoticeAppearance.self, forKey: .appearance)
    }
}

extension ActiveConfigPurpose {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        description = c.lenient(String.self, forKey: .description)
        industries = c.optional(String.self, forKey: .industries)
        dataElements = c.lenient([ActiveConfigDataElement].self, forKey: .dataElements)
        productUuids = c.optional([String].self, forKey: .productUuids)
    }
}

extension ActiveConfigDataElement {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        description = c.optional(String.self, forKey: .description)
        industries = c.optional(String.self, forKey: .industries)
        enabled = c.lenient(Bool.self, forKey: .enabled)
        required = c.lenient(Bool.self, forKey: .required)
    }
}

extension PurposeSelection {
    /// A legacy grant carries no `status`; the empty string is what
    /// `ProductConsent` and `PurposePreselectionLogic` read as that shape.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selected = c.lenient(Bool.self, forKey: .selected)
        status = c.lenient(String.self, forKey: .status)
        needsReconsent = c.lenient(Bool.self, forKey: .needsReconsent)
        dataElements = c.lenient([String: DataElementSelection].self, forKey: .dataElements)
    }
}

extension DataElementSelection {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selected = c.lenient(Bool.self, forKey: .selected)
        enabled = c.lenient(Bool.self, forKey: .enabled)
        required = c.lenient(Bool.self, forKey: .required)
    }
}

extension DpoInfo {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grievanceText = c.lenient(String.self, forKey: .grievanceText)
        grievanceAnchorText = c.lenient(String.self, forKey: .grievanceAnchorText)
        grievanceUrl = c.lenient(String.self, forKey: .grievanceUrl)
        grievanceEmail = c.lenient(String.self, forKey: .grievanceEmail)
        grievanceEmailConnectorText = c.optional(String.self, forKey: .grievanceEmailConnectorText)
        dpBoardText = c.lenient(String.self, forKey: .dpBoardText)
        dpBoardAnchorText = c.lenient(String.self, forKey: .dpBoardAnchorText)
        dpBoardUrl = c.lenient(String.self, forKey: .dpBoardUrl)
        dpoText = c.lenient(String.self, forKey: .dpoText)
        dpoAnchorText = c.lenient(String.self, forKey: .dpoAnchorText)
        dpoUrl = c.optional(String.self, forKey: .dpoUrl)
        dpoEmail = c.optional(String.self, forKey: .dpoEmail)
    }
}

extension NoticeProduct {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = c.lenient(String.self, forKey: .name)
        description = c.optional(String.self, forKey: .description)
        mandatory = c.optional(Bool.self, forKey: .mandatory)
    }
}
