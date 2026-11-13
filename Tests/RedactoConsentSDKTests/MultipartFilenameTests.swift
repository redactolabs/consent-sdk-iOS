import XCTest
@testable import RedactoConsentSDK

final class MultipartFilenameTests: XCTestCase {
    func testTheNameIsReducedToWhatTheHeaderCanCarry() {
        let cases: [(input: String, expected: String)] = [
            ("evil\".pdf\r\nX-Injected: 1", "evil.pdfX-Injected: 1"),
            ("../../etc/passwd", "passwd"),
            ("C:\\Users\\me\\scan.png", "scan.png"),
            ("  ", "upload"),
            ("statement 2026.pdf", "statement 2026.pdf"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(MultipartFormBuilder.safeFilename(input), expected, input)
        }
    }

    func testTheHeaderCarriesTheSanitisedName() {
        let body = MultipartFormBuilder(boundary: "B").body(filename: "a\"b.txt", mimeType: "text/plain", fileData: Data("x".utf8), payload: Data("{}".utf8))
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("filename=\"ab.txt\""))
        XCTAssertFalse(text.contains("filename=\"a\""))
    }
}
