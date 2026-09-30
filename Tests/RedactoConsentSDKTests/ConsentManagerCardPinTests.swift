import XCTest
@testable import RedactoConsentSDK

final class ConsentManagerCardPinTests: XCTestCase {
    private typealias F = PCFixtures

    override func setUp() {
        super.setUp()
        PCMockURLProtocol.reset()
        IdempotencyKeys.shared.reset()
    }

    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    @MainActor
    private func makeViewModel(ledger: String?) -> ConsentManagerViewModel {
        let store = PrivacyCenterStore(
            baseUrl: F.base,
            slug: "acme",
            accessToken: F.liveToken,
            refreshToken: "refresh-1",
            themeMode: .light,
            initialPage: .consentManager,
            onBack: nil,
            onError: { _ in false },
            language: "hi",
            urlSession: F.session(),
            ledgerBaseUrl: ledger
        )
        return ConsentManagerViewModel(store: store)
    }

    private func twoCardDetail() throws -> UserConsentDetail {
        try F.detail(direct: [
            F.groupJSON(product: F.productA, name: "Savings", notice: F.notice),
            F.groupJSON(product: F.productB, name: "Loans", notice: F.noticeB, hasMore: true),
        ])
    }

    func testNormalizationKeepsEachCardsProductAndNotice() throws {
        let groups = ConsentManagerNormalization.directGroups(from: try twoCardDetail())
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].purposes[0].purposeUuid, groups[1].purposes[0].purposeUuid)
        XCTAssertEqual(groups[0].purposes[0].productUuid, F.productA)
        XCTAssertEqual(groups[0].purposes[0].noticeUuid, F.notice)
        XCTAssertEqual(groups[1].purposes[0].productUuid, F.productB)
        XCTAssertEqual(groups[1].purposes[0].noticeUuid, F.noticeB)
    }

    @MainActor
    func testRevokingTheSecondCardPinsTheLedgerSubmitToThatCard() async throws {
        let vm = makeViewModel(ledger: F.ledger)
        vm.detail = try twoCardDetail()
        let consent = vm.directGroups[1].purposes[0]

        await vm.performAction(on: consent, action: .revoke)

        let submit = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/submit-consent").first)
        XCTAssertEqual(submit.json["product_uuid"] as? String, F.productB)
        XCTAssertEqual(submit.firstPurpose["product_uuid"] as? String, F.productB)
        XCTAssertEqual(submit.json["notice_uuid"] as? String, F.noticeB)
        XCTAssertEqual(submit.json["language"] as? String, "hi")
        XCTAssertNil(submit.json["nominator_uuid"])
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testRevokingOnPythonPinsTheBodyToTheCard() async throws {
        let vm = makeViewModel(ledger: nil)
        vm.detail = try twoCardDetail()
        let consent = vm.directGroups[0].purposes[0]

        await vm.performAction(on: consent, action: .revoke)

        let submit = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/manage-consent").first)
        XCTAssertEqual(submit.json["product_uuid"] as? String, F.productA)
        XCTAssertEqual(submit.json["language"] as? String, "hi")
        XCTAssertNil(submit.json["nominator_contact"])
    }

    @MainActor
    func testANomineeRevokeCarriesTheNominatorOnBothBackends() async throws {
        let detail = try F.detail(nominated: [
            F.groupJSON(product: F.productA, name: "Savings", notice: F.notice, nominator: F.nominatorJSON),
        ])

        let ledgerVm = makeViewModel(ledger: F.ledger)
        ledgerVm.detail = detail
        await ledgerVm.performAction(on: ledgerVm.nominatedProductGroups[0].purposes[0], action: .revoke)

        let pythonVm = makeViewModel(ledger: nil)
        pythonVm.detail = detail
        await pythonVm.performAction(on: pythonVm.nominatedProductGroups[0].purposes[0], action: .revoke)

        let ledgerSubmit = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/submit-consent").first)
        XCTAssertEqual(ledgerSubmit.json["nominator_uuid"] as? String, F.nominator)
        XCTAssertEqual(ledgerSubmit.json["product_uuid"] as? String, F.productA)

        let pythonSubmit = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/manage-consent").first)
        XCTAssertEqual(pythonSubmit.json["nominator_contact"] as? String, "nominator@example.test")
    }

    func testTheNominatorContactFallsBackToTheUserId() {
        let withEmail = NominatorInfo(orgUserId: "NOM-1", name: nil, uuid: F.nominator, email: "n@example.test")
        let withoutEmail = NominatorInfo(orgUserId: "NOM-1", name: nil, uuid: F.nominator, email: nil)
        XCTAssertEqual(ConsentManagerViewModel.nominatorContact(for: withEmail), "n@example.test")
        XCTAssertEqual(ConsentManagerViewModel.nominatorContact(for: withoutEmail), "NOM-1")
        XCTAssertNil(ConsentManagerViewModel.nominatorContact(for: nil))
    }

    @MainActor
    func testLoadMoreFetchesTheCardsRemainingPurposesFromTheLedger() async throws {
        let vm = makeViewModel(ledger: F.ledger)
        vm.detail = try twoCardDetail()
        let full = vm.directGroups[0]
        let truncated = vm.directGroups[1]
        XCTAssertFalse(vm.hasMorePurposes(in: full))
        XCTAssertTrue(vm.hasMorePurposes(in: truncated))

        var extra = F.purposeJSON(notice: F.noticeB)
        extra["purpose_uuid"] = "99999999-9999-9999-9999-999999999999"
        PCMockURLProtocol.enqueue(.json(200, [
            "purposes": [extra],
            "pagination": ["total_count": 2, "offset": 1, "limit": 50] as [String: Any],
        ] as [String: Any]))

        await vm.loadMorePurposes(in: truncated)

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.urlWithoutQuery, "\(F.ledgerPrefix)/user-consents/\(F.productB)/purposes")
        XCTAssertEqual(request.query("offset"), "1")
        XCTAssertEqual(request.query("language"), "hi")
        XCTAssertNil(request.query("nominator_uuid"))
        let rows = vm.purposes(in: truncated)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].productUuid, F.productB)
        XCTAssertEqual(rows[1].noticeUuid, F.noticeB)
        XCTAssertFalse(vm.hasMorePurposes(in: truncated))
        XCTAssertEqual(vm.purposes(in: full).count, 1)
    }

    @MainActor
    func testLoadMoreOnANominatedCardAsksForThatNominator() async throws {
        let vm = makeViewModel(ledger: F.ledger)
        vm.detail = try F.detail(nominated: [
            F.groupJSON(product: F.productA, name: "Savings", notice: F.notice, nominator: F.nominatorJSON, hasMore: true),
        ])
        let group = vm.nominatedProductGroups[0]
        XCTAssertTrue(vm.hasMorePurposes(in: group))
        PCMockURLProtocol.enqueue(.json(200, ["purposes": [] as [Any]]))

        await vm.loadMorePurposes(in: group)

        let request = try XCTUnwrap(PCMockURLProtocol.requests.first)
        XCTAssertEqual(request.query("nominator_uuid"), F.nominator)
        XCTAssertFalse(vm.hasMorePurposes(in: group))
    }

    @MainActor
    func testLoadMoreThatFinishesAfterAFilterRefreshIsDiscarded() async throws {
        let vm = makeViewModel(ledger: F.ledger)
        vm.detail = try twoCardDetail()
        let truncated = vm.directGroups[1]
        var extra = F.purposeJSON(notice: F.noticeB)
        extra["purpose_uuid"] = "99999999-9999-9999-9999-999999999999"
        PCMockURLProtocol.hold(pathSuffix: "/purposes")
        PCMockURLProtocol.route(pathSuffix: "/purposes", .json(200, [
            "purposes": [extra],
            "pagination": ["total_count": 2, "offset": 1, "limit": 50] as [String: Any],
        ] as [String: Any]))

        let loading = Task { await vm.loadMorePurposes(in: truncated) }
        await waitUntil { !PCMockURLProtocol.requests(pathSuffix: "/purposes").isEmpty }
        vm.statusFilter = .withdrawn
        await vm.refresh()
        PCMockURLProtocol.releaseHeld()
        await loading.value

        XCTAssertTrue(vm.extraPurposes.isEmpty)
        XCTAssertTrue(vm.moreAvailable.isEmpty)
    }
}
