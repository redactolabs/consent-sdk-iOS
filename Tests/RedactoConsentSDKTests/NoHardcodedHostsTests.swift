import XCTest

/// The SDK ships no host of its own: every request is built from the
/// integrator's `baseUrl`. Documentation comments may name the production
/// host as an example; code may not, apart from the one line below.
final class NoHardcodedHostsTests: XCTestCase {
    private static let forbidden = [
        #"api\.redacto\.io"#,
        #"api\.redacto\.tech"#,
        #"api-[A-Za-z0-9-]*\.redacto\.[A-Za-z]+"#,
    ]

    /// The user service's fallback origin for a consent server URL with none,
    /// which legacy mode (`baseUrl` ending in `/consent`) still uses.
    private static let allowed: Set<String> = [
        #"PrivacyCenterAPI.swift: static let defaultConsentBaseUrl = "https://api.redacto.io/consent""#,
    ]

    private var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
    }

    private func swiftSources() -> [URL] {
        guard let walker = FileManager.default.enumerator(at: sourcesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func testNoSourceFileNamesARedactoHostOutsideAComment() throws {
        let files = swiftSources()
        XCTAssertGreaterThan(files.count, 50, "found the SDK sources at \(sourcesDirectory.path)")
        var offenders: [String] = []
        for file in files {
            let code = Self.strippingComments(try String(contentsOf: file, encoding: .utf8))
            for (index, line) in code.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !Self.allowed.contains("\(file.lastPathComponent): \(trimmed)") else { continue }
                for pattern in Self.forbidden where line.range(of: pattern, options: .regularExpression) != nil {
                    offenders.append("\(file.lastPathComponent):\(index + 1): \(trimmed)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    func testTheGuardSeesAHostInCodeButNotInAComment() {
        let source = """
        /// Pass the host, e.g. `https://api.redacto.io`.
        let a = "https://api.redacto.tech/consent" // https://api.redacto.io
        /* https://api-staging.redacto.tech */ let b = 1
        let c = "https://example.test" // api.redacto.io
        let d = "x // y"; let e = "https://api-uat.redacto.io"
        """
        let code = Self.strippingComments(source)
        XCTAssertFalse(code.contains("api.redacto.io\n"))
        XCTAssertTrue(code.contains(#""https://api.redacto.tech/consent""#))
        XCTAssertFalse(code.contains("api-staging"))
        XCTAssertTrue(code.contains(#"let c = "https://example.test""#))
        XCTAssertTrue(code.contains(#""https://api-uat.redacto.io""#))
        XCTAssertEqual(code.components(separatedBy: "\n").filter { $0.contains("api.redacto.io") }.count, 0)

        let multiline = Self.strippingComments("let f = \"\"\"\nhttps://api-dev.redacto.io // kept\n\"\"\" // dropped\n")
        XCTAssertTrue(multiline.contains("https://api-dev.redacto.io // kept"))
        XCTAssertFalse(multiline.contains("dropped"))
    }

    /// `source` with `//` line comments and `/* */` block comments blanked,
    /// leaving string literals (where `//` is part of a URL) intact.
    static func strippingComments(_ source: String) -> String {
        var output = ""
        var index = source.startIndex
        var inString = false
        var inMultilineString = false
        var inLineComment = false
        var blockDepth = 0
        func peek(_ offset: Int) -> Character? {
            source.index(index, offsetBy: offset, limitedBy: source.endIndex).flatMap { $0 < source.endIndex ? source[$0] : nil }
        }
        func atTripleQuote() -> Bool {
            source[index] == "\"" && peek(1) == "\"" && peek(2) == "\""
        }
        while index < source.endIndex {
            let char = source[index]
            if inMultilineString {
                if atTripleQuote() {
                    output.append("\"\"\"")
                    index = source.index(index, offsetBy: 2)
                    inMultilineString = false
                } else {
                    output.append(char)
                }
            } else if inLineComment {
                if char == "\n" {
                    inLineComment = false
                    output.append(char)
                }
            } else if blockDepth > 0 {
                if char == "*", peek(1) == "/" {
                    blockDepth -= 1
                    index = source.index(after: index)
                } else if char == "/", peek(1) == "*" {
                    blockDepth += 1
                    index = source.index(after: index)
                } else if char == "\n" {
                    output.append(char)
                }
            } else if inString {
                output.append(char)
                if char == "\\", let next = peek(1) {
                    output.append(next)
                    index = source.index(after: index)
                } else if char == "\"" || char == "\n" {
                    inString = false
                }
            } else if char == "/", peek(1) == "/" {
                inLineComment = true
            } else if char == "/", peek(1) == "*" {
                blockDepth = 1
                index = source.index(after: index)
            } else if atTripleQuote() {
                output.append("\"\"\"")
                index = source.index(index, offsetBy: 2)
                inMultilineString = true
            } else {
                if char == "\"" {
                    inString = true
                }
                output.append(char)
            }
            index = source.index(after: index)
        }
        return output
    }
}
