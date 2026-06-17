import XCTest
@testable import RedactoConsentSDK

final class DpoInfoTests: XCTestCase {
    func testDecodesDpoEmailWhenDpoUrlMissing() throws {
        let json = """
        {
          "grievance_text": "Grievance",
          "grievance_anchor_text": "here",
          "grievance_url": "https://example.com/grievance",
          "grievance_email": "help@example.com",
          "dp_board_text": "Board",
          "dp_board_anchor_text": "here",
          "dp_board_url": "https://example.com/board",
          "dpo_text": "DPO",
          "dpo_anchor_text": "Click here",
          "dpo_email": "dpo@example.com"
        }
        """

        let dpoInfo = try JSONDecoder().decode(DpoInfo.self, from: Data(json.utf8))

        XCTAssertNil(dpoInfo.dpoUrl)
        XCTAssertEqual(dpoInfo.dpoEmail, "dpo@example.com")
        XCTAssertEqual(dpoInfo.dpoContactUrl, "mailto:dpo@example.com")
    }

    func testPrefersDpoUrlOverDpoEmail() throws {
        let json = """
        {
          "grievance_text": "Grievance",
          "grievance_anchor_text": "here",
          "grievance_url": "https://example.com/grievance",
          "grievance_email": "help@example.com",
          "dp_board_text": "Board",
          "dp_board_anchor_text": "here",
          "dp_board_url": "https://example.com/board",
          "dpo_text": "DPO",
          "dpo_anchor_text": "Click here",
          "dpo_url": "https://example.com/dpo",
          "dpo_email": "dpo@example.com"
        }
        """

        let dpoInfo = try JSONDecoder().decode(DpoInfo.self, from: Data(json.utf8))

        XCTAssertEqual(dpoInfo.dpoUrl, "https://example.com/dpo")
        XCTAssertEqual(dpoInfo.dpoEmail, "dpo@example.com")
        XCTAssertEqual(dpoInfo.dpoContactUrl, "https://example.com/dpo")
    }
}
