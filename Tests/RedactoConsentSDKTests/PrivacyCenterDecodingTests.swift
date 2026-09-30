import XCTest
@testable import RedactoConsentSDK

/// One value this SDK did not expect must cost one row at most, never the
/// whole Consent Manager or case thread.
final class PrivacyCenterDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testEveryRevocationSpellingIsTheWithdrawnState() throws {
        for raw in ["WITHDRAW", "WITHDRAWN", "REVOKED", "revoked"] {
            XCTAssertEqual(try decode([ConsentStatus].self, [raw]), [.withdrawn], raw)
        }
    }

    func testAnUnrecognisedStatusDecodesAsUnknown() throws {
        XCTAssertEqual(try decode([ConsentStatus].self, ["ACTIVE", "SUSPENDED"]), [.active, .unknown])
    }

    func testAFreshDocumentRequestWithNullFieldsDecodes() throws {
        let message = try decode(CaseMessage.self, [
            "uuid": "m-1",
            "case_uuid": "c-1",
            "sender_role": "data_fiduciary",
            "triggered_by_email": NSNull(),
            "created_at": "2026-09-01T10:00:00Z",
            "body": NSNull(),
            "message_type": "document_requested",
            "document_request_metadata": [
                "title": NSNull(),
                "accepted_document": NSNull(),
                "document_request_status": NSNull(),
                "rejection_reason": NSNull(),
            ],
        ] as [String: Any])

        XCTAssertEqual(message.triggeredByEmail, "")
        XCTAssertEqual(message.body, "")
        XCTAssertEqual(message.documentRequestMetadata?.title, "")
        XCTAssertEqual(message.documentRequestMetadata?.documentRequestStatus, .pending)
    }

    func testAMessageTypeAddedLaterReadsAsAPlainMessage() throws {
        let message = try decode(CaseMessage.self, [
            "uuid": "m-1",
            "case_uuid": "c-1",
            "sender_role": "system",
            "created_at": "2026-09-01T10:00:00Z",
            "body": "Case reassigned",
            "message_type": "case_reassigned",
        ] as [String: Any])

        XCTAssertEqual(message.messageType, .messageSent)
        XCTAssertEqual(message.senderRole, .other("system"))
    }

    func testASenderRoleAddedLaterIsKeptAndRoundTrips() throws {
        let message = try decode(CaseMessage.self, [
            "uuid": "m-1",
            "sender_role": "system",
            "message_type": "message_sent",
        ] as [String: Any])
        let reencoded = try JSONDecoder().decode(CaseMessage.self, from: JSONEncoder().encode(message))

        XCTAssertEqual(reencoded.senderRole, .other("system"))
        XCTAssertEqual(try decode(CaseMessage.self, ["uuid": "m-2"]).senderRole, .other(""))
        XCTAssertEqual(SenderRole(rawValue: "data_principal"), .dataPrincipal)
        XCTAssertEqual(SenderRole(rawValue: "data_fiduciary"), .dataFiduciary)
    }

    func testAnUnknownSenderIsNotAttributedToEitherParty() {
        PCStrings.currentLanguage = "en"
        func message(_ role: SenderRole, email: String = "") -> CaseMessage {
            CaseMessage(uuid: "m", caseUuid: "c", senderRole: role, triggeredByEmail: email, createdAt: "", body: "hi", messageType: .messageSent)
        }

        XCTAssertEqual(MessageItemView.senderLabel(for: message(.dataPrincipal)), PCStrings.senderYou)
        XCTAssertEqual(MessageItemView.senderLabel(for: message(.dataFiduciary)), PCStrings.senderPrivacyTeam)
        XCTAssertEqual(MessageItemView.senderLabel(for: message(.dataFiduciary, email: "dpo@acme.test")), "dpo@acme.test")
        XCTAssertNil(MessageItemView.senderLabel(for: message(.other("system"))))
        XCTAssertEqual(MessageItemView.senderLabel(for: message(.other("system"), email: "bot@acme.test")), "bot@acme.test")
    }

    func testAnUploadResponseWithoutFileDetailsStillReturnsTheDocument() throws {
        let response = try decode(UploadDocumentResponse.self, ["uuid": "doc-1", "file_size": NSNull()])

        XCTAssertEqual(response.uuid, "doc-1")
        XCTAssertEqual(response.fileSize, 0)
    }
}
