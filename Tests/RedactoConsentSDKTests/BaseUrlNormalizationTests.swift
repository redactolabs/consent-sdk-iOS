import XCTest
@testable import RedactoConsentSDK

/// `baseUrl` is the API host (host mode) or, as in earlier releases, the
/// consent server URL (legacy mode, where both values pass through untouched).
final class BaseUrlNormalizationTests: XCTestCase {
    private final class Messages: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [String] = []

        func append(_ message: String) {
            lock.lock()
            stored.append(message)
            lock.unlock()
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
    }

    private static let ledger = "https://ledger.test/consent-ledger"

    private func hostMode(_ host: String) -> NoticeEndpoints {
        NoticeEndpoints(mode: .host, baseUrl: "\(host)/consent", ledgerBaseUrl: "\(host)/consent-ledger", host: host)
    }

    func testAnAbsoluteUrlNotEndingInConsentIsTheApiHost() {
        let table: [(String, String)] = [
            ("https://api.test", "https://api.test"),
            ("https://api.test/", "https://api.test"),
            ("https://api.test//", "https://api.test"),
            ("  https://api.test \n", "https://api.test"),
            ("HTTPS://API.TEST", "HTTPS://API.TEST"),
            ("Http://Api.Test", "Http://Api.Test"),
            ("http://localhost:8000", "http://localhost:8000"),
            ("http://10.0.2.2:8000/", "http://10.0.2.2:8000"),
            ("http://[::1]:8080", "http://[::1]:8080"),
            ("https://gateway.test/redacto", "https://gateway.test/redacto"),
            ("https://api.test/consent-ledger", "https://api.test"),
            ("https://api.test/consent-ledger/", "https://api.test"),
            ("https://api.test/myconsent", "https://api.test/myconsent"),
            ("https://consent-ledger", "https://consent-ledger"),
        ]
        for (input, host) in table {
            XCTAssertEqual(NoticeBaseUrl.resolve(baseUrl: input, ledgerBaseUrl: nil), hostMode(host), input)
        }
    }

    func testEverythingElseIsLegacyAndPassesThroughUntouched() {
        let table: [String?] = [
            nil,
            "",
            "   ",
            "/",
            "https://api.test/consent",
            "https://api.test/consent/",
            " https://api.test/consent ",
            "HTTPS://API.TEST/consent",
            "https://api.test/v1/consent",
            "https://api.test/consent-ledger/consent",
            "api.test",
            "api.test/consent",
            "not a url",
            "ftp://api.test",
            "https://exa mple.test",
            "https://api.test?x=1",
            "https://user@api.test",
        ]
        for input in table {
            for ledger in [nil, "  ", Self.ledger, "\(Self.ledger)/"] as [String?] {
                XCTAssertEqual(
                    NoticeBaseUrl.resolve(baseUrl: input, ledgerBaseUrl: ledger),
                    NoticeEndpoints(mode: .legacy, baseUrl: input, ledgerBaseUrl: ledger, host: nil),
                    "\(String(describing: input)) + \(String(describing: ledger))"
                )
            }
        }
    }

    func testALedgerBaseUrlIsIgnoredWithTheApiHost() {
        let ignored: [String?] = ["http://localhost:8090/consent-ledger", " http://localhost:8090/consent-ledger/ ", Self.ledger, "not a url", nil, "", "   "]
        for host in ["https://api.test", "https://api.test/", "https://api.test/consent-ledger", "https://gateway.test/redacto"] {
            for ledger in ignored {
                XCTAssertEqual(
                    NoticeBaseUrl.resolve(baseUrl: host, ledgerBaseUrl: ledger),
                    NoticeBaseUrl.resolve(baseUrl: host, ledgerBaseUrl: nil),
                    "\(host) + \(String(describing: ledger))"
                )
            }
        }
        let resolved = NoticeBaseUrl.resolve(baseUrl: "https://api.test", ledgerBaseUrl: "http://localhost:8090/consent-ledger")
        XCTAssertEqual(resolved, hostMode("https://api.test"))
    }

    func testResolvingTheResolvedConsentServerUrlIsLegacy() {
        let resolved = NoticeBaseUrl.resolve(baseUrl: "https://api.test", ledgerBaseUrl: nil)
        let again = NoticeBaseUrl.resolve(baseUrl: resolved.baseUrl, ledgerBaseUrl: resolved.ledgerBaseUrl)
        XCTAssertEqual(again.mode, .legacy)
        XCTAssertEqual(again.baseUrl, resolved.baseUrl)
        XCTAssertEqual(again.ledgerBaseUrl, resolved.ledgerBaseUrl)
    }

    func testHostModeRoutesAsALedgerConfiguredReleaseExceptSandboxAudio() throws {
        let host = NoticeBaseUrl.resolve(baseUrl: "https://api.test", ledgerBaseUrl: nil)
        XCTAssertEqual(try host.consentServer(), "https://api.test/consent")
        XCTAssertEqual(try host.read(specificUuid: nil, isSandbox: false), "https://api.test/consent-ledger")
        XCTAssertEqual(try host.read(specificUuid: "app-1", isSandbox: false), "https://api.test/consent")
        XCTAssertEqual(try host.read(specificUuid: nil, isSandbox: true), "https://api.test/consent")
        XCTAssertEqual(try host.write(), "https://api.test/consent-ledger")
        XCTAssertEqual(try host.audio(isSandbox: false), "https://api.test/consent-ledger")
        XCTAssertEqual(try host.audio(isSandbox: true), "https://api.test/consent-ledger")

        let legacy = NoticeBaseUrl.resolve(baseUrl: "https://api.test/consent", ledgerBaseUrl: Self.ledger)
        XCTAssertEqual(try legacy.audio(isSandbox: false), Self.ledger)
        XCTAssertEqual(try legacy.audio(isSandbox: true), "https://api.test/consent")
    }

    func testABlankBaseUrlStillFailsWithBaseUrlIsRequired() {
        for blank in [nil, "", "  ", "/"] as [String?] {
            XCTAssertThrowsError(try NoticeBaseUrl.consentServer(blank), String(describing: blank)) { error in
                XCTAssertEqual(error.localizedDescription, NoticeBaseUrl.missingBaseUrl.localizedDescription)
            }
        }
    }

    // MARK: - Deprecation warnings

    func testTheDeprecatedFormsAreNamed() {
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "https://api.test", ledgerBaseUrl: nil), [])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "https://api.test", ledgerBaseUrl: "  "), [])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: nil, ledgerBaseUrl: nil), [])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "api.test/consent", ledgerBaseUrl: nil), [])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: " https://api.test/consent/ ", ledgerBaseUrl: nil), [.consentServerUrl])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "https://api.test", ledgerBaseUrl: Self.ledger), [.ledgerIgnored])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "https://api.test/consent-ledger", ledgerBaseUrl: Self.ledger), [.ledgerIgnored])
        XCTAssertEqual(
            NoticeBaseUrl.deprecations(baseUrl: "https://api.test/consent", ledgerBaseUrl: Self.ledger),
            [.consentServerUrl, .ledgerBaseUrl]
        )
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: nil, ledgerBaseUrl: Self.ledger), [.ledgerBaseUrl])
        XCTAssertEqual(NoticeBaseUrl.deprecations(baseUrl: "not a url", ledgerBaseUrl: Self.ledger), [.ledgerBaseUrl])
    }

    func testEachWarningIsLoggedOncePerProcess() {
        let messages = Messages()
        let log = BaseUrlDeprecationLog(sink: { messages.append($0) })
        for _ in 0..<3 {
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://api.test", ledgerBaseUrl: nil, log: log)
        }
        XCTAssertEqual(messages.all, [], "the API host is not deprecated")

        for _ in 0..<3 {
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://api.test/consent", ledgerBaseUrl: nil, log: log)
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://other.test/consent/", ledgerBaseUrl: nil, log: log)
        }
        XCTAssertEqual(messages.all, [BaseUrlDeprecation.consentServerUrl.message])

        for _ in 0..<3 {
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://api.test", ledgerBaseUrl: Self.ledger, log: log)
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://other.test", ledgerBaseUrl: "http://localhost:8090/consent-ledger", log: log)
        }
        XCTAssertEqual(messages.all, [BaseUrlDeprecation.consentServerUrl.message, BaseUrlDeprecation.ledgerIgnored.message])

        for _ in 0..<3 {
            _ = NoticeBaseUrl.endpoints(baseUrl: "https://api.test/consent", ledgerBaseUrl: "http://localhost:9000", log: log)
            _ = NoticeBaseUrl.endpoints(baseUrl: nil, ledgerBaseUrl: Self.ledger, log: log)
        }
        XCTAssertEqual(messages.all, [
            BaseUrlDeprecation.consentServerUrl.message,
            BaseUrlDeprecation.ledgerIgnored.message,
            BaseUrlDeprecation.ledgerBaseUrl.message,
        ])
    }

    func testTheIgnoredLedgerWarningReadsAsSpecified() {
        XCTAssertEqual(
            BaseUrlDeprecation.ledgerIgnored.message,
            "[Redacto] ledgerBaseUrl is ignored because baseUrl is the API host; the SDK reaches the ledger under that host. Remove ledgerBaseUrl."
        )
        XCTAssertEqual(
            BaseUrlDeprecation.ledgerBaseUrl.message,
            "[Redacto] ledgerBaseUrl is deprecated. Pass the Redacto API host as baseUrl instead; the SDK then reaches the consent server and the ledger under it."
        )
    }

    func testASlugIsReportedAsDeprecatedOncePerProcess() {
        let messages = Messages()
        let log = BaseUrlDeprecationLog(sink: { messages.append($0) })
        PrivacyCenterStore.reportSlugDeprecation(slug: "", log: log)
        XCTAssertEqual(messages.all, [])

        PrivacyCenterStore.reportSlugDeprecation(slug: "acme", log: log)
        PrivacyCenterStore.reportSlugDeprecation(slug: "beta", log: log)
        XCTAssertEqual(messages.all, [BaseUrlDeprecation.slug.message])
    }

    func testTheSlugWarningReadsAsSpecified() {
        XCTAssertEqual(
            BaseUrlDeprecation.slug.message,
            "[Redacto] slug is deprecated and ignored. The Privacy Center reads the organisation from the access token, or from organisationUuid and workspaceUuid. Remove slug."
        )
    }

    func testTheWarningsNameNoHost() {
        for deprecation in BaseUrlDeprecation.allCases {
            XCTAssertTrue(deprecation.message.hasPrefix("[Redacto] "))
            XCTAssertFalse(deprecation.message.contains("http"), deprecation.message)
            XCTAssertFalse(deprecation.message.contains("redacto."), deprecation.message)
        }
    }

    func testLoggingReturnsWhatResolveReturns() {
        let log = BaseUrlDeprecationLog(sink: { _ in })
        for (base, ledger) in [("https://api.test", nil), ("https://api.test/consent", Self.ledger), ("", nil)] as [(String, String?)] {
            XCTAssertEqual(
                NoticeBaseUrl.endpoints(baseUrl: base, ledgerBaseUrl: ledger, log: log),
                NoticeBaseUrl.resolve(baseUrl: base, ledgerBaseUrl: ledger)
            )
        }
    }
}
