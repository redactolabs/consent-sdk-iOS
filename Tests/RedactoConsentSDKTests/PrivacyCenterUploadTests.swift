import XCTest
@testable import RedactoConsentSDK

/// Both upload endpoints answer 422 without a JSON `payload` part next to `file`,
/// and the DSR endpoint also requires the document's own fields in it.
final class PrivacyCenterUploadTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
    }

    private let uploaded: [String: Any] = ["code": 200, "status": "OK", "detail": ["uuid": "doc-1"]]

    private func part(_ name: String, in request: PCCapturedRequest) -> [String: Any]? {
        let body = String(decoding: request.body, as: UTF8.self)
        guard let header = body.range(of: "name=\"\(name)\""),
              let start = body.range(of: "\r\n\r\n", range: header.upperBound..<body.endIndex),
              let end = body.range(of: "\r\n--", range: start.upperBound..<body.endIndex) else { return nil }
        let json = Data(body[start.upperBound..<end.lowerBound].utf8)
        return (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
    }

    func testADsrUploadCarriesEveryFieldTheEndpointRequires() async throws {
        PCMockURLProtocol.enqueue(.json(200, uploaded))

        let response = try await F.api(ledger: nil).uploadDocument(
            fileData: Data("pdf".utf8), filename: "id.pdf", mimeType: "application/pdf", principalUuid: "form-1"
        )

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/upload-document")
        let payload = try XCTUnwrap(part("payload", in: request))
        XCTAssertEqual(payload["organization_uuid"] as? String, F.org)
        XCTAssertEqual(payload["space"] as? String, "privacy/form-1")
        XCTAssertNotNil(payload["uuid"] as? String)
        XCTAssertEqual(payload["is_public"] as? Bool, true)
        XCTAssertEqual(payload["allow_ai_processing"] as? Bool, true)
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["case_uuid"] as? String, "form-1")
        XCTAssertEqual(metadata["product"] as? String, "privacy_center")
        XCTAssertNil(payload["org_user_id"])
        XCTAssertTrue(String(decoding: request.body, as: UTF8.self).contains("name=\"file\"; filename=\"id.pdf\""))
        XCTAssertEqual(response.uuid, "doc-1")
        XCTAssertEqual(response.fileName, "")
    }

    func testASandboxDsrUploadCarriesTheActingIdentity() async throws {
        PCMockURLProtocol.enqueue(.json(200, uploaded))

        _ = try await F.api(ledger: nil, sandbox: F.sandbox).uploadDocument(
            fileData: Data("pdf".utf8), filename: "id.pdf", mimeType: "application/pdf", principalUuid: "form-1"
        )

        let payload = try XCTUnwrap(part("payload", in: try XCTUnwrap(PCMockURLProtocol.requests.first)))
        XCTAssertEqual(payload["org_user_id"] as? String, "UCIC-9")
    }

    func testACaseUploadCarriesAPayloadPart() async throws {
        PCMockURLProtocol.enqueue(.json(200, uploaded))

        _ = try await F.api(ledger: nil).uploadCaseDocument(
            caseUuid: "case-1", fileData: Data("pdf".utf8), filename: "id.pdf", mimeType: "application/pdf"
        )

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.urlWithoutQuery, "\(F.consentPrefix)/cases/case-1/upload-document")
        let payload = try XCTUnwrap(part("payload", in: request))
        XCTAssertTrue(payload.keys.contains("metadata"))
    }
}
