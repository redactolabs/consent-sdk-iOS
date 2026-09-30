import XCTest
@testable import RedactoConsentSDK

final class ProfilePickerGateTests: XCTestCase {
    private typealias F = PCFixtures

    private let first = IdentityCandidate(uuid: "p-1", orgUserId: "U-1", primaryEmail: "shared@example.test", primaryMobile: nil)
    private let second = IdentityCandidate(uuid: "p-2", orgUserId: "U-2", primaryEmail: "shared@example.test", primaryMobile: "+911111111111")

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
        PCStrings.currentLanguage = "en"
    }

    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    private static func token(orgUserId: String?) -> String {
        var userData: [String: Any] = ["primary_email": "shared@example.test"]
        if let orgUserId { userData["org_user_id"] = orgUserId }
        return F.jwt([
            "organisation_uuid": F.org,
            "workspace_uuid": F.ws,
            "user_data": userData,
        ])
    }

    private static let identitiesBody: [String: Any] = [
        "identities": [
            ["uuid": "p-1", "org_user_id": "U-1", "primary_email": "shared@example.test"],
            ["uuid": "p-2", "org_user_id": "U-2", "primary_email": "shared@example.test"],
        ] as [[String: Any]],
    ]

    @MainActor
    private func makeStore(
        accessToken: String,
        sandbox: SandboxConfig? = nil,
        onError: @escaping @Sendable (Error) -> Bool = { _ in false }
    ) -> PrivacyCenterStore {
        PrivacyCenterStore(
            baseUrl: F.base,
            slug: "acme",
            accessToken: accessToken,
            refreshToken: "refresh-1",
            themeMode: .light,
            initialPage: .consentManager,
            onBack: nil,
            onError: onError,
            language: "en",
            sandbox: sandbox,
            urlSession: F.session(),
            ledgerBaseUrl: F.ledger
        )
    }

    func testPicksWhenSeveralPrincipalsShareTheContactAndNoneIsPinned() {
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first, second], pickedOrgUserId: nil, tokenOrgUserId: "shared@example.test", isSandbox: false), .picking)
    }

    func testResolvesASingleCandidateWithoutAPicker() {
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first], pickedOrgUserId: nil, tokenOrgUserId: nil, isSandbox: false), .resolved)
        XCTAssertEqual(PCProfileGate.resolve(candidates: [], pickedOrgUserId: nil, tokenOrgUserId: nil, isSandbox: false), .resolved)
    }

    func testResolvesAPinnedSessionOnlyWhenThePinMatchesTheToken() {
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first, second], pickedOrgUserId: "U-2", tokenOrgUserId: "U-2", isSandbox: false), .resolved)
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first, second], pickedOrgUserId: "U-2", tokenOrgUserId: "U-1", isSandbox: false), .picking)
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first, second], pickedOrgUserId: "", tokenOrgUserId: "", isSandbox: false), .picking)
    }

    func testSandboxNeverPicks() {
        XCTAssertEqual(PCProfileGate.resolve(candidates: [first, second], pickedOrgUserId: nil, tokenOrgUserId: nil, isSandbox: true), .resolved)
    }

    func testTheUserIdLeadsTheRowAndTheContactsFollowOnce() {
        let labels = PCProfileGate.labels(for: second)
        XCTAssertEqual(labels.primary, PCStrings.userIdLabel("U-2"))
        XCTAssertEqual(labels.secondary, ["shared@example.test", "+911111111111"])
    }

    func testARowWithoutAUserIdLeadsWithTheContactAndDoesNotRepeatIt() {
        let labels = PCProfileGate.labels(for: IdentityCandidate(uuid: "p-3", orgUserId: nil, primaryEmail: "a@example.test", primaryMobile: "a@example.test"))
        XCTAssertEqual(labels.primary, "a@example.test")
        XCTAssertEqual(labels.secondary, [])
    }

    func testCandidatesWithoutAUuidAreNotSelectable() {
        let blank = IdentityCandidate(uuid: "", orgUserId: "U-9")
        XCTAssertEqual(PCProfileGate.selectable([blank, first]), [first])
    }

    func testReadsTheOrgUserIdFromTheTokenUserData() {
        XCTAssertEqual(PCProfileGate.orgUserId(fromToken: Self.token(orgUserId: "U-7")), "U-7")
        XCTAssertNil(PCProfileGate.orgUserId(fromToken: Self.token(orgUserId: nil)))
        XCTAssertNil(PCProfileGate.orgUserId(fromToken: "not-a-jwt"))
    }

    func testIdentityRoutesStayOnTheConsentServer() async throws {
        PCMockURLProtocol.enqueue(.json(200, Self.identitiesBody), .json(200, ["token": Self.token(orgUserId: "U-2"), "refresh_token": "refresh-2"]))
        let api = F.api(ledger: F.ledger)
        let list = try await api.listIdentities()
        _ = try await api.selectPrincipal(uuid: "p-2")

        XCTAssertEqual(list.identities.map { $0.uuid }, ["p-1", "p-2"])
        let requests = PCMockURLProtocol.requests
        XCTAssertEqual(requests[0].url.absoluteString, "\(F.consentPrefix)/identities")
        XCTAssertEqual(requests[1].url.absoluteString, "\(F.consentPrefix)/identities/select")
        XCTAssertEqual(requests[1].json["uuid"] as? String, "p-2")
    }

    @MainActor
    func testStartShowsThePickerAndReadsNoConsentsOnTheUnscopedToken() async {
        PCMockURLProtocol.enqueue(.json(200, Self.identitiesBody))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))

        await store.start()

        XCTAssertEqual(store.profilePhase, .picking)
        XCTAssertEqual(store.profileCandidates.count, 2)
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/user-consents").isEmpty)
        XCTAssertEqual(store.dataStatus, .checking)
    }

    @MainActor
    func testStartPassesStraightThroughForASingleProfile() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, ["identities": [["uuid": "p-1", "org_user_id": "U-1"]]]))
        let reported = CallCounter()
        let store = makeStore(accessToken: Self.token(orgUserId: "U-1"), onError: { _ in reported.count += 1; return false })

        await store.start()

        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertFalse(store.canSwitchProfile)
        XCTAssertFalse(PCMockURLProtocol.requests(pathSuffix: "/user-consents").isEmpty)
        XCTAssertEqual(reported.count, 0)
    }

    @MainActor
    func testALookupFailureNeverBlocksThePrivacyCenterButReachesOnError() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(502, ["message": "ledger down"]))
        let reported = CallCounter()
        let store = makeStore(accessToken: Self.token(orgUserId: "U-1"), onError: { _ in reported.count += 1; return false })

        await store.start()

        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertTrue(store.profileCandidates.isEmpty)
        XCTAssertEqual(reported.count, 1)
    }

    @MainActor
    func testSandboxSkipsTheLookup() async {
        let store = makeStore(accessToken: "", sandbox: F.sandbox)

        await store.resolveProfiles()

        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/identities").isEmpty)
    }

    @MainActor
    func testChoosingAProfileRescopesEveryLaterRead() async throws {
        let scoped = Self.token(orgUserId: "U-2")
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, Self.identitiesBody))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(200, ["token": scoped, "refresh_token": "refresh-2"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()
        XCTAssertEqual(store.profilePhase, .picking)

        await store.selectProfile(second)

        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertEqual(store.currentOrgUserId, "U-2")
        XCTAssertNil(store.profileSelectError)
        let read = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/user-consents").first)
        XCTAssertEqual(read.header("Authorization"), "Bearer \(scoped)")

        await store.resolveProfiles()
        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertTrue(store.canSwitchProfile)
    }

    @MainActor
    func testAFailedChoiceStaysOnThePickerWithAnError() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, Self.identitiesBody))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(403, ["message": "principal_not_permitted"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()

        await store.selectProfile(second)

        XCTAssertEqual(store.profilePhase, .picking)
        XCTAssertEqual(store.profileSelectError, PCStrings.couldNotSwitchProfile)
        XCTAssertNil(store.profileBusyUuid)
    }

    @MainActor
    func testATokenThatNamesNoPrincipalIsRefusedRatherThanLooping() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, Self.identitiesBody))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(200, ["token": Self.token(orgUserId: nil), "refresh_token": "refresh-2"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()

        await store.selectProfile(second)

        XCTAssertEqual(store.profilePhase, .picking)
        XCTAssertNotNil(store.profileSelectError)
    }

    @MainActor
    func testSwitchProfileReopensThePicker() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, Self.identitiesBody))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(200, ["token": Self.token(orgUserId: "U-2"), "refresh_token": "refresh-2"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()
        await store.selectProfile(second)

        store.switchProfile()

        XCTAssertEqual(store.profilePhase, .picking)
    }

    @MainActor
    func testChoosingAProfileWhoseTokenCarriesNoContactUsesThatProfilesOwnContact() async {
        let bare = F.jwt(["organisation_uuid": F.org, "workspace_uuid": F.ws, "user_data": ["org_user_id": "U-3"]])
        let mobileOnly = IdentityCandidate(uuid: "p-3", orgUserId: "U-3", primaryEmail: nil, primaryMobile: "+913333333333")
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, [
            "identities": [
                ["uuid": "p-1", "org_user_id": "U-1", "primary_email": "shared@example.test"],
                ["uuid": "p-3", "org_user_id": "U-3", "primary_mobile": "+913333333333"],
            ] as [[String: Any]],
        ] as [String: Any]))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(200, ["token": bare, "refresh_token": "refresh-3"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()
        XCTAssertEqual(store.contact, "shared@example.test")

        await store.selectProfile(mobileOnly)

        XCTAssertEqual(store.profilePhase, .resolved)
        XCTAssertEqual(store.contact, "+913333333333")
        let tokenContact = await store.tokenStore.currentEmail()
        XCTAssertEqual(tokenContact, "+913333333333")
    }

    @MainActor
    func testChoosingAProfileKeepsTheContactItsTokenNames() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, Self.identitiesBody))
        PCMockURLProtocol.route(pathSuffix: "/identities/select", .json(200, ["token": Self.token(orgUserId: "U-2"), "refresh_token": "refresh-2"]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))
        await store.start()

        await store.selectProfile(second)

        XCTAssertEqual(store.contact, "shared@example.test")
    }

    func testTheScopedContactFallsBackThroughTheProfilesIdentifiers() {
        let emailOnly = IdentityCandidate(uuid: "p-1", orgUserId: "U-1", primaryEmail: "a@example.test", primaryMobile: "+911")
        let idOnly = IdentityCandidate(uuid: "p-2", orgUserId: "U-2")
        XCTAssertEqual(PCProfileGate.contact(for: emailOnly, tokenContact: "t@example.test", orgUserId: "U-1"), "t@example.test")
        XCTAssertEqual(PCProfileGate.contact(for: emailOnly, tokenContact: nil, orgUserId: "U-1"), "a@example.test")
        XCTAssertEqual(PCProfileGate.contact(for: idOnly, tokenContact: "", orgUserId: "U-2"), "U-2")
    }

    @MainActor
    func testAListWithAnUnselectableEntryStillOpensThePicker() async {
        PCMockURLProtocol.route(pathSuffix: "/identities", .json(200, [
            "identities": [
                ["uuid": "p-1", "org_user_id": "U-1"],
                ["org_user_id": "U-9"],
            ],
        ]))
        let store = makeStore(accessToken: Self.token(orgUserId: "shared@example.test"))

        await store.start()

        XCTAssertEqual(store.profilePhase, .picking)
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/user-consents").isEmpty)
        XCTAssertEqual(PCProfileGate.selectable(store.profileCandidates).map { $0.uuid }, ["p-1"])
    }
}
