import XCTest
@testable import RedactoConsentSDK

/// Port of the React SDK's `settings/api.test.ts`.
final class PrivacyCenterSettingsAPITests: XCTestCase {
    private let base = "https://api.test/consent"
    private let body: [String: Any] = [
        "settings": ["portal": ["welcome_enabled": true]],
        "version": 3,
        "published_at": "2026-10-01T10:00:00Z",
        "language": "hi",
    ]

    override func setUp() async throws {
        try await super.setUp()
        await PrivacyCenterSettingsCache.shared.clear()
        await PrivacyCenterSettingsCache.shared.setClock { Date() }
    }

    override func tearDown() async throws {
        TransportStubProtocol.uninstall()
        await PrivacyCenterSettingsCache.shared.clear()
        await PrivacyCenterSettingsCache.shared.setClock { Date() }
        try await super.tearDown()
    }

    private func fetch(_ org: String = "org-1", _ language: String = "hi") async -> PublicPrivacyCenterSettings? {
        await PrivacyCenterPublicAPI.fetchSettings(baseUrl: base, organisationUuid: org, language: language)
    }

    func testIsThePublicRouteOnTheConsentServerWithTheLanguage() {
        XCTAssertEqual(
            PrivacyCenterPublicAPI.settingsUrl(baseUrl: "https://api.example.test/consent/", organisationUuid: "org-1", language: "mni-Mtei"),
            "https://api.example.test/consent/public/organisations/org-1/privacy-center-settings/?lang=mni-Mtei"
        )
    }

    func testReadsABareBodyWithoutCredentials() async {
        TransportStubProtocol.install { _ in .json(200, self.body) }
        let response = await fetch()

        XCTAssertEqual(response?.version, 3)
        XCTAssertEqual(response?.language, "hi")
        XCTAssertTrue(response?.isPublished ?? false)
        let request = TransportStubProtocol.requests.first
        XCTAssertEqual(request?.url.absoluteString, "\(base)/public/organisations/org-1/privacy-center-settings/?lang=hi")
        XCTAssertEqual(request?.method, "GET")
        XCTAssertNil(request?.header("Authorization"))
    }

    func testReadsTheEnvelopeAndItsBrandContact() async {
        var detail = body
        detail["brand_contact"] = ["legal_entity_name": "Acme Ltd"]
        TransportStubProtocol.install { _ in .json(200, ["code": 200, "status": "success", "detail": detail]) }
        let response = await fetch()

        XCTAssertEqual(response?.version, 3)
        XCTAssertEqual(PrivacyCenterSettingsResolver.brandContact(response?.brandContact).legalEntityName, "Acme Ltd")
        let resolved = PrivacyCenterSettingsResolver.resolve(published: response?.settings)
        XCTAssertTrue(resolved.portal.welcomeEnabled)
    }

    func testANeverPublishedPayloadIsNotCustomised() {
        let response = PrivacyCenterPublicAPI.parseSettings(Data(#"{"settings":{},"version":0,"published_at":null,"language":"en"}"#.utf8))
        XCTAssertEqual(response?.isPublished, false)
    }

    func testAnOutOfRangeVersionReadsAsZeroWithoutTrapping() {
        for version in ["1e20", "-1e20"] {
            let body = #"{"settings":{},"version":\#(version),"published_at":null,"language":"en"}"#
            XCTAssertEqual(PrivacyCenterPublicAPI.parseSettings(Data(body.utf8))?.version, 0, version)
        }
        let fractional = PrivacyCenterPublicAPI.parseSettings(Data(#"{"settings":{},"version":3.7,"published_at":null}"#.utf8))
        XCTAssertEqual(fractional?.version, 3)
    }

    func testResolvesToNothingWhenTheRequestFailsOrTheBodyIsNotSettings() async {
        TransportStubProtocol.install { request in
            if request.url.absoluteString.contains("org-1") { return .json(500, ["detail": "nope"]) }
            if request.url.absoluteString.contains("org-2") { return .offline }
            return .json(200, ["unexpected": true])
        }
        let failed = await fetch("org-1", "en")
        let offline = await fetch("org-2", "en")
        let unexpected = await fetch("org-3", "en")
        XCTAssertNil(failed)
        XCTAssertNil(offline)
        XCTAssertNil(unexpected)
    }

    func testAsksOncePerOrganisationAndLanguage() async {
        TransportStubProtocol.install { _ in .json(200, self.body) }
        _ = await fetch("org-1", "hi")
        _ = await fetch("org-1", "hi")
        XCTAssertEqual(TransportStubProtocol.requests.count, 1)

        _ = await fetch("org-1", "en")
        _ = await fetch("org-2", "hi")
        XCTAssertEqual(TransportStubProtocol.requests.count, 3)
    }

    func testReusesACopyForTheCacheLifetimeThenAsksAgain() async {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000))
        await PrivacyCenterSettingsCache.shared.setClock { clock.now }
        TransportStubProtocol.install { _ in .json(200, self.body) }
        let before = await PrivacyCenterPublicAPI.hasCachedSettings(baseUrl: base, organisationUuid: "org-1", language: "hi")
        XCTAssertFalse(before)

        _ = await fetch()
        let cached = await PrivacyCenterPublicAPI.hasCachedSettings(baseUrl: base, organisationUuid: "org-1", language: "hi")
        XCTAssertTrue(cached)

        clock.now = clock.now.addingTimeInterval(PrivacyCenterSettingsLimits.cacheLifetime)
        let expired = await PrivacyCenterPublicAPI.hasCachedSettings(baseUrl: base, organisationUuid: "org-1", language: "hi")
        XCTAssertFalse(expired)
        _ = await fetch()
        XCTAssertEqual(TransportStubProtocol.requests.count, 2)
    }

    func testAsksAgainAfterAFailure() async {
        let attempts = TestCounter()
        TransportStubProtocol.install { _ in
            attempts.value += 1
            return attempts.value == 1 ? .offline : .json(200, self.body)
        }
        let first = await fetch()
        let second = await fetch()
        XCTAssertNil(first)
        XCTAssertEqual(second?.version, 3)
        XCTAssertEqual(TransportStubProtocol.requests.count, 2)
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        get { lock.lock(); defer { lock.unlock() }; return current }
        set { lock.lock(); current = newValue; lock.unlock() }
    }
}

final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        get { lock.lock(); defer { lock.unlock() }; return count }
        set { lock.lock(); count = newValue; lock.unlock() }
    }
}
