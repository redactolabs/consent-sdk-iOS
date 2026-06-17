import XCTest
@testable import RedactoConsentSDK

final class CaseMessageTests: XCTestCase {
    func testDecodesMessageWithoutDocumentUuids() throws {
        let json = """
        {
          "uuid": "aa74de11-ee3c-49ec-b59f-d21b1cb3f214",
          "case_uuid": "62461c27-29e2-4d3a-aec8-7bec06d2be2c",
          "sender_role": "data_principal",
          "triggered_by_email": "user@example.com",
          "created_at": "2026-06-11T10:38:50.593Z",
          "body": "Hi",
          "documents": [],
          "message_type": "message_sent",
          "document_request_metadata": null
        }
        """

        let message = try JSONDecoder().decode(CaseMessage.self, from: Data(json.utf8))

        XCTAssertEqual(message.body, "Hi")
        XCTAssertEqual(message.documentUuids, [])
        XCTAssertEqual(message.documents, [])
        XCTAssertEqual(message.messageType, .messageSent)
    }

    func testDecodesMessageListEnvelope() throws {
        let json = """
        [
          {
            "uuid": "aa74de11-ee3c-49ec-b59f-d21b1cb3f214",
            "case_uuid": "62461c27-29e2-4d3a-aec8-7bec06d2be2c",
            "sender_role": "data_principal",
            "triggered_by_email": "user@example.com",
            "created_at": "2026-06-11T10:38:50.593Z",
            "body": "Hi",
            "documents": [],
            "message_type": "message_sent",
            "document_request_metadata": null
          }
        ]
        """

        let messages = try JSONDecoder().decode([CaseMessage].self, from: Data(json.utf8))

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.documentUuids, [])
    }
}
