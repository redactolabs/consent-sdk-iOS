import XCTest
@testable import RedactoConsentSDK

final class ReceiptTests: XCTestCase {
    func testDecodesReceiptUuidField() throws {
        let json = """
        {
          "receipt_uuid": "339b2ce4-dd0e-48e9-821b-bb060b3e6d42",
          "event_type": "GRANTED",
          "event_type_display": "Consent granted",
          "product_name": "Galaxy Mobiles",
          "product_name_display": "Galaxy Mobiles",
          "created_at": "2026-06-11T10:37:12.336Z"
        }
        """

        let receipt = try JSONDecoder().decode(Receipt.self, from: Data(json.utf8))

        XCTAssertEqual(receipt.uuid, "339b2ce4-dd0e-48e9-821b-bb060b3e6d42")
        XCTAssertEqual(receipt.eventType, "GRANTED")
        XCTAssertEqual(receipt.productName, "Galaxy Mobiles")
    }

    func testDecodesReceiptListEnvelope() throws {
        let json = """
        {
          "data": [
            {
              "receipt_uuid": "339b2ce4-dd0e-48e9-821b-bb060b3e6d42",
              "event_type": "GRANTED",
              "event_type_display": "Consent granted",
              "product_name": "Galaxy Mobiles",
              "product_name_display": "Galaxy Mobiles",
              "created_at": "2026-06-11T10:37:12.336Z"
            }
          ],
          "total": 1,
          "skip": 0,
          "limit": 10
        }
        """

        let detail = try JSONDecoder().decode(ReceiptDetail.self, from: Data(json.utf8))

        XCTAssertEqual(detail.items.count, 1)
        XCTAssertEqual(detail.items.first?.uuid, "339b2ce4-dd0e-48e9-821b-bb060b3e6d42")
        XCTAssertEqual(detail.page.totalCount, 1)
        XCTAssertEqual(detail.page.offset, 0)
        XCTAssertEqual(detail.page.limit, 10)
    }
}
