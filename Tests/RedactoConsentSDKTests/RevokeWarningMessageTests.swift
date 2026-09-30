import XCTest
@testable import RedactoConsentSDK

final class RevokeWarningMessageTests: XCTestCase {
    private func decodeUserConsent(_ json: String) throws -> UserConsent {
        try JSONDecoder().decode(UserConsent.self, from: Data(json.utf8))
    }

    /// Resolves the revoke warning the same way `ModifyConsentModal.revokeWarning`
    /// does: prefer a non-empty custom message, else the localized default.
    private func resolvedWarning(for consent: UserConsent) -> String {
        if let custom = consent.revokeWarningMessage,
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return PCStrings.revokeConsentWarning
    }

    func testDecodesRevokeWarningMessageWhenPresent() throws {
        let json = """
        {
          "purpose_uuid": "p-1",
          "purpose": "Marketing",
          "purpose_description": "Send offers",
          "status": "ACTIVE",
          "given_date": "2026-01-01",
          "method": "explicit",
          "data_elements": [],
          "revoke_warning_message": "Losing this stops all offers."
        }
        """

        let consent = try decodeUserConsent(json)

        XCTAssertEqual(consent.revokeWarningMessage, "Losing this stops all offers.")
    }

    func testRevokeWarningMessageIsNilWhenAbsent() throws {
        let json = """
        {
          "purpose_uuid": "p-1",
          "purpose": "Marketing",
          "purpose_description": "Send offers",
          "status": "ACTIVE",
          "given_date": "2026-01-01",
          "method": "explicit",
          "data_elements": []
        }
        """

        let consent = try decodeUserConsent(json)

        XCTAssertNil(consent.revokeWarningMessage)
    }

    func testRevokeWarningMessageIsNilWhenNull() throws {
        let json = """
        {
          "purpose_uuid": "p-1",
          "purpose": "Marketing",
          "purpose_description": "Send offers",
          "status": "ACTIVE",
          "given_date": "2026-01-01",
          "method": "explicit",
          "data_elements": [],
          "revoke_warning_message": null
        }
        """

        let consent = try decodeUserConsent(json)

        XCTAssertNil(consent.revokeWarningMessage)
    }

    func testPurposeItemDecodesRevokeWarningMessage() throws {
        let json = """
        {
          "purpose_uuid": "p-1",
          "name": "Marketing",
          "status": "ACTIVE",
          "method": "explicit",
          "data_elements": [],
          "revoke_warning_message": "Custom purpose warning."
        }
        """

        let purpose = try JSONDecoder().decode(PurposeItem.self, from: Data(json.utf8))

        XCTAssertEqual(purpose.revokeWarningMessage, "Custom purpose warning.")
    }

    func testCustomWarningWinsOverDefault() throws {
        let consent = try decodeUserConsent(
            """
            {
              "purpose_uuid": "p-1",
              "purpose": "Marketing",
              "purpose_description": "Send offers",
              "status": "ACTIVE",
              "given_date": "2026-01-01",
              "method": "explicit",
              "data_elements": [],
              "revoke_warning_message": "Custom warning wins."
            }
            """
        )

        XCTAssertEqual(resolvedWarning(for: consent), "Custom warning wins.")
    }

    func testDefaultUsedWhenNoCustomMessage() throws {
        PCStrings.currentLanguage = "en"
        let consent = try decodeUserConsent(
            """
            {
              "purpose_uuid": "p-1",
              "purpose": "Marketing",
              "purpose_description": "Send offers",
              "status": "ACTIVE",
              "given_date": "2026-01-01",
              "method": "explicit",
              "data_elements": []
            }
            """
        )

        XCTAssertEqual(
            resolvedWarning(for: consent),
            "If you revoke this consent, you may lose access to certain features that rely on this data."
        )
    }

    func testDefaultUsedWhenCustomMessageBlank() throws {
        PCStrings.currentLanguage = "en"
        let consent = try decodeUserConsent(
            """
            {
              "purpose_uuid": "p-1",
              "purpose": "Marketing",
              "purpose_description": "Send offers",
              "status": "ACTIVE",
              "given_date": "2026-01-01",
              "method": "explicit",
              "data_elements": [],
              "revoke_warning_message": "   "
            }
            """
        )

        XCTAssertEqual(
            resolvedWarning(for: consent),
            "If you revoke this consent, you may lose access to certain features that rely on this data."
        )
    }

    func testNormalizationThreadsRevokeWarningFromConsentGroup() throws {
        let json = """
        {
          "direct": [
            {
              "product_uuid": "prod-1",
              "product_name": "App",
              "product_description": null,
              "nominator": null,
              "total_purposes": 1,
              "active_purposes": 1,
              "has_more_purposes": false,
              "purposes": [
                {
                  "purpose_uuid": "p-1",
                  "name": "Marketing",
                  "status": "ACTIVE",
                  "method": "explicit",
                  "data_elements": [],
                  "revoke_warning_message": "Threaded through mapper."
                }
              ]
            }
          ]
        }
        """

        let detail = try JSONDecoder().decode(UserConsentDetail.self, from: Data(json.utf8))
        let groups = ConsentManagerNormalization.directGroups(from: detail)

        XCTAssertEqual(groups.first?.purposes.first?.revokeWarningMessage, "Threaded through mapper.")
    }
}
