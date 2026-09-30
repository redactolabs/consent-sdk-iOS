import Foundation
import XCTest
@testable import RedactoConsentSDK

/// The ledger and the consent server both write a blank notice field as `null`;
/// a notice with no logo, font or privacy-center link must still decode.
final class NoticeContentDecodingTests: XCTestCase {
    private typealias F = NoticeFixtures

    private func decode(config: [String: Any], purposes: [[String: Any]]? = nil) throws -> ConsentContent {
        try JSONDecoder().decode(ConsentContent.self, from: F.contentData(purposes: purposes, config: config))
    }

    func testDecodesANoticeWhoseBlankFieldsAreNull() throws {
        let nulled = [
            "logo_url", "privacy_policy_url", "privacy_center_url", "primary_color", "secondary_color",
            "font_preference", "additional_text", "confirm_button_text", "decline_button_text",
            "accept_all_button_text", "deployed_at", "privacy_policy_prefix_text", "privacy_policy_anchor_text",
            "purpose_section_heading", "notice_banner_heading", "dpo_info", "products",
        ]
        let config = Dictionary(uniqueKeysWithValues: nulled.map { ($0, NSNull() as Any) })

        let ac = try decode(config: config).detail.activeConfig

        XCTAssertEqual(ac.logoUrl, "")
        XCTAssertEqual(ac.privacyCenterUrl, "")
        XCTAssertEqual(ac.fontPreference, "")
        XCTAssertEqual(ac.confirmButtonText, "")
        XCTAssertNil(ac.acceptAllButtonText)
        XCTAssertNil(ac.dpoInfo)
        XCTAssertEqual(ac.purposes.count, F.defaultPurposes.count)
    }

    func testDecodesANoticeMissingItsOptionalKeysOutright() throws {
        var data = try JSONSerialization.jsonObject(with: F.contentData()) as! [String: Any]
        var detail = data["detail"] as! [String: Any]
        var config = detail["active_config"] as! [String: Any]
        for key in ["logo_url", "font_preference", "deployed_at", "notice_banner_heading", "secondary_color"] {
            config.removeValue(forKey: key)
        }
        detail.removeValue(forKey: "collection_points")
        detail["active_config"] = config
        data["detail"] = detail

        let content = try JSONDecoder().decode(
            ConsentContent.self, from: JSONSerialization.data(withJSONObject: data)
        )

        XCTAssertEqual(content.detail.activeConfig.logoUrl, "")
        XCTAssertEqual(content.detail.collectionPoints.count, 0)
    }

    func testDecodesAPurposeWithANullDescription() throws {
        var purpose = F.purpose(F.orders, name: "Orders", elements: [F.element(F.email, name: "Email")])
        purpose["description"] = NSNull()

        let decoded = try decode(config: [:], purposes: [purpose]).detail.activeConfig.purposes

        XCTAssertEqual(decoded.first?.description, "")
    }

    func testReadsALegacyGrantWithNoStatusAsTheLegacyShape() throws {
        let selections: [String: Any] = [F.orders: ["selected": true]]
        let data = F.contentData(purposeSelections: selections)

        let recorded = try JSONDecoder().decode(ConsentContent.self, from: data).detail.purposeSelections?[F.orders]

        XCTAssertEqual(recorded?.selected, true)
        XCTAssertEqual(recorded?.status, "")
        XCTAssertEqual(recorded?.needsReconsent, false)
        XCTAssertEqual(recorded?.dataElements.count, 0)
    }

    func testDropsAMalformedDpoBlockRatherThanTheNotice() throws {
        let ac = try decode(config: ["dpo_info": "not-an-object"]).detail.activeConfig

        XCTAssertNil(ac.dpoInfo)
    }

    func testStillRejectsANoticeWithNoConfig() {
        let root: [String: Any] = ["code": 200, "status": "success", "detail": ["uuid": "notice-1"]]
        let data = try! JSONSerialization.data(withJSONObject: root)

        XCTAssertThrowsError(try JSONDecoder().decode(ConsentContent.self, from: data))
    }
}
