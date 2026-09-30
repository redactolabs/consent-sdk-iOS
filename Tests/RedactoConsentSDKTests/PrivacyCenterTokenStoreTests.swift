import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterTokenStoreTests: XCTestCase {
    private typealias F = PCFixtures

    private let scoped = PCFixtures.jwt([
        "organisation_uuid": PCFixtures.org,
        "workspace_uuid": PCFixtures.ws,
        "user_data": ["org_user_id": "U-2", "primary_email": "second@example.test"],
    ])

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
    }

    override func tearDown() {
        PCMockURLProtocol.releaseHeld()
        super.tearDown()
    }

    private func makeStore() -> TokenStore {
        TokenStore(
            baseUrl: F.base,
            accessToken: F.liveToken,
            refreshToken: "refresh-1",
            onError: { _ in false },
            urlSession: F.session()
        )
    }

    private func startHeldRefresh(_ store: TokenStore) async -> Task<String, Error> {
        PCMockURLProtocol.hold(pathSuffix: "/otp/refresh")
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(200, ["access_token": F.refreshedToken, "refresh_token": "refresh-old"]))
        let refreshing = Task { try await store.forceRefresh() }
        await waitUntil { !PCMockURLProtocol.requests(pathSuffix: "/otp/refresh").isEmpty }
        return refreshing
    }

    func testARefreshStartedBeforeAProfileSwitchCannotReplaceTheAdoptedTokens() async throws {
        let store = makeStore()
        let refreshing = await startHeldRefresh(store)

        await store.adopt(accessToken: scoped, refreshToken: "refresh-scoped", contact: "second@example.test")
        PCMockURLProtocol.releaseHeld()
        _ = try await refreshing.value

        let token = await store.currentRawToken()
        let email = await store.currentEmail()
        XCTAssertEqual(token, scoped)
        XCTAssertEqual(email, "second@example.test")
    }

    func testARefreshWithNoProfileSwitchStillLandsItsTokens() async throws {
        let store = makeStore()
        let refreshing = await startHeldRefresh(store)

        PCMockURLProtocol.releaseHeld()
        _ = try await refreshing.value

        let token = await store.currentRawToken()
        XCTAssertEqual(token, F.refreshedToken)
    }

    func testAdoptingATokenWithNoContactClearsThePreviousProfilesContact() async {
        let store = makeStore()
        let bare = F.jwt(["organisation_uuid": F.org, "workspace_uuid": F.ws, "user_data": ["org_user_id": "U-3"]])
        let before = await store.currentEmail()
        XCTAssertEqual(before, F.contact)

        await store.adopt(accessToken: bare, refreshToken: "refresh-3")

        let after = await store.currentEmail()
        XCTAssertNil(after)
    }

    func testAdoptingPrefersTheContactTheCallerDerived() async {
        let store = makeStore()

        await store.adopt(accessToken: scoped, refreshToken: "refresh-scoped", contact: "+913333333333")

        let email = await store.currentEmail()
        XCTAssertEqual(email, "+913333333333")
    }
}
