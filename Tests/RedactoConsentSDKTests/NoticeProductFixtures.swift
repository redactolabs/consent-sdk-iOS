import Foundation
@testable import RedactoConsentSDK

enum NoticeProductFixtures {
    static func element(_ uuid: String, _ name: String, required: Bool = false, enabled: Bool = true) -> [String: Any] {
        ["uuid": uuid, "name": name, "description": NSNull(), "enabled": enabled, "required": required]
    }

    static func requiredPurpose(_ uuid: String, _ name: String, _ productUuids: [String]) -> [String: Any] {
        [
            "uuid": uuid,
            "name": name,
            "description": "",
            "product_uuids": productUuids,
            "data_elements": [element("\(uuid)-id", "\(name) ID", required: true), element("\(uuid)-extra", "\(name) Extra")],
        ]
    }

    static func optionalPurpose(_ uuid: String, _ name: String, _ productUuids: [String]) -> [String: Any] {
        [
            "uuid": uuid,
            "name": name,
            "description": "",
            "product_uuids": productUuids,
            "data_elements": [element("\(uuid)-extra", "\(name) Extra")],
        ]
    }

    static func product(_ uuid: String, _ name: String, mandatory: Bool?) -> [String: Any] {
        var product: [String: Any] = ["uuid": uuid, "name": name]
        if let mandatory { product["mandatory"] = mandatory }
        return product
    }

    static func recorded(selected: Bool = true, status: String = "ACTIVE", needsReconsent: Bool = false) -> [String: Any] {
        ["selected": selected, "status": status, "needs_reconsent": needsReconsent, "data_elements": [String: Any]()]
    }

    static let shared = requiredPurpose("purpose-shared", "Shared Purpose", ["prod-a", "prod-b"])
    static let onlyA = optionalPurpose("purpose-only-a", "Only A", ["prod-a"])
    static let onlyB = optionalPurpose("purpose-only-b", "Only B", ["prod-b"])

    static func twoProducts(mandatoryA: Bool? = false, mandatoryB: Bool? = false) -> [[String: Any]] {
        [product("prod-a", "Product A", mandatory: mandatoryA), product("prod-b", "Product B", mandatory: mandatoryB)]
    }

    static func notice(
        products: [[String: Any]]?,
        purposes: [[String: Any]],
        config: [String: Any] = [:],
        detail: [String: Any] = [:]
    ) throws -> ConsentContent {
        var activeConfig: [String: Any] = [
            "uuid": "cfg-1",
            "notice_uuid": "notice-1",
            "organisation_uuid": "org-1",
            "workspace_uuid": "ws-1",
            "version": 1,
            "status": "active",
            "notice_text": "Notice",
            "additional_text": "",
            "confirm_button_text": "Accept Selected",
            "decline_button_text": "Decline",
            "logo_url": "",
            "privacy_policy_url": "",
            "privacy_center_url": "",
            "primary_color": "#000000",
            "secondary_color": "#ffffff",
            "font_preference": "default",
            "purposes": purposes,
            "default_language": "en",
            "supported_languages_and_translations": [String: Any](),
            "created_at": "2024-01-01T00:00:00.000Z",
            "updated_at": "2024-01-01T00:00:00.000Z",
            "deployed_at": "2024-01-01T00:00:00.000Z",
            "privacy_policy_prefix_text": "Read",
            "privacy_policy_anchor_text": "Policy",
            "purpose_section_heading": "Purposes",
            "notice_banner_heading": "Privacy Notice",
        ]
        if let products { activeConfig["products"] = products }
        activeConfig.merge(config) { _, next in next }

        var noticeDetail: [String: Any] = [
            "uuid": "notice-1",
            "name": "Notice",
            "organisation_uuid": "org-1",
            "workspace_uuid": "ws-1",
            "collection_point_uuids": [String](),
            "collection_points": [[String: Any]](),
            "active_config": activeConfig,
            "created_at": "2024-01-01T00:00:00.000Z",
            "updated_at": "2024-01-01T00:00:00.000Z",
        ]
        noticeDetail.merge(detail) { _, next in next }

        let body: [String: Any] = ["code": 200, "status": "success", "detail": noticeDetail]
        let data = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(ConsentContent.self, from: data)
    }

    @MainActor
    static func viewModel(
        _ content: ConsentContent,
        defaultOpenProducts: [String]? = nil,
        includeFullyConsentedData: Bool = false
    ) -> ConsentNoticeViewModel {
        let viewModel = ConsentNoticeViewModel(
            noticeId: "notice-1",
            accessToken: "",
            refreshToken: "",
            baseUrl: "https://api.example.test/consent",
            onAccept: {},
            onDecline: {},
            includeFullyConsentedData: includeFullyConsentedData,
            defaultOpenProducts: defaultOpenProducts
        )
        viewModel.content = content
        viewModel.seedSelectionState(from: content)
        return viewModel
    }
}
