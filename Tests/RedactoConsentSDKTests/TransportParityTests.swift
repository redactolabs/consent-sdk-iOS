import XCTest
@testable import RedactoConsentSDK

/// Submit payload, guardian calls and URL handling, checked against what the
/// React SDK's `api/index.ts` sends and reads.
final class TransportParityTests: XCTestCase {
    private typealias F = TransportFixtures

    override func setUp() async throws {
        try await super.setUp()
        await APICache.shared.clear()
        IdempotencyKeys.shared.reset()
    }

    override func tearDown() async throws {
        TransportStubProtocol.uninstall()
        IdempotencyKeys.shared.reset()
        await APICache.shared.clear()
        try await super.tearDown()
    }

    private func submit(language: String? = nil, metaData: MetaData? = nil, baseUrl: String? = F.python) async throws -> TransportStubRequest {
        TransportStubProtocol.install { _ in .empty(201) }
        try await ConsentAPI.submitConsentEvent(.init(
            accessToken: F.token(),
            baseUrl: baseUrl,
            noticeUuid: F.notice,
            purposes: [F.purpose()],
            declined: false,
            language: language,
            metaData: metaData
        ))
        return try XCTUnwrap(TransportStubProtocol.requests(pathSuffix: "/submit-consent").last)
    }

    // MARK: - Submit payload

    func testSubmitCarriesTheLanguageAndMinorAge() async throws {
        let request = try await submit(language: "pa", metaData: MetaData(specificUuid: "app-1", minorAge: 15))
        let body = try XCTUnwrap(request.jsonBody)
        XCTAssertEqual(body["language"] as? String, "pa")
        XCTAssertEqual(body["meta_data"] as? [String: AnyHashable], ["specific_uuid": "app-1", "minor_age": 15])
        // React sends no Accept-Language on the write.
        XCTAssertNil(request.header("Accept-Language"))
    }

    func testSubmitLeavesOutAnUnsetOrEmptyLanguage() async throws {
        for language in [nil, ""] as [String?] {
            let request = try await submit(language: language)
            let body = try XCTUnwrap(request.jsonBody)
            XCTAssertNil(body["language"])
            XCTAssertNil(body["meta_data"])
        }
    }

    func testMetaDataOmitsAnEmptySpecificUuid() async throws {
        let request = try await submit(metaData: MetaData(minorAge: 12))
        let body = try XCTUnwrap(request.jsonBody)
        XCTAssertEqual(body["meta_data"] as? [String: AnyHashable], ["minor_age": 12])
    }

    func testLanguageNamesMapToBcp47() {
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("Punjabi"), "pa")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("punjabi"), "pa")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("Goan Konkani"), "gom")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("Manipuri"), "mni-Mtei")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("mni-Mtei"), "mni-Mtei")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("hi"), "hi")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("en-US"), "en-US")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("zh-Hans"), "zh-Hans")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("Klingon"), "en")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code(""), "en")
        XCTAssertEqual(NoticeLanguageCodes.toBcp47Code("en\n"), "en")
        XCTAssertEqual(NoticeLanguageCodes.nativeLabel("Hindi"), "हिन्दी (Hindi)")
        XCTAssertEqual(NoticeLanguageCodes.nativeLabel("Klingon"), "Klingon")
    }

    // MARK: - Base URLs

    func testATrailingSlashOnTheHostIsDropped() async throws {
        let request = try await submit(baseUrl: " \(F.python)/ ")
        XCTAssertEqual(request.url.absoluteString, "\(F.scope(F.python))/submit-consent")
    }

    func testThereIsNoBuiltInHost() {
        for blank in [nil, "", "  ", "/"] as [String?] {
            XCTAssertThrowsError(try NoticeBaseUrl.consentServer(blank), String(describing: blank))
        }
        XCTAssertEqual(try NoticeBaseUrl.write(ledgerBaseUrl: "\(F.ledger)/", baseUrl: nil), F.ledger)
    }

    func testAReadWithNoBaseUrlFailsInsteadOfReachingADefaultHost() async {
        TransportStubProtocol.install { _ in .empty(200) }
        defer { TransportStubProtocol.uninstall() }

        do {
            _ = try await ConsentAPI.fetchConsentContent(.init(noticeId: "n-1", accessToken: F.token()))
            XCTFail("expected missing baseUrl to throw")
        } catch {
            XCTAssertEqual((error as? RedactoAPIError)?.localizedDescription, NoticeBaseUrl.missingBaseUrl.localizedDescription)
        }
        XCTAssertTrue(TransportStubProtocol.requests.isEmpty)
    }

    func testAnUnparseableHostThrowsInsteadOfTrapping() async {
        TransportStubProtocol.install { _ in .empty(201) }
        do {
            try await ConsentAPI.submitConsentEvent(.init(
                accessToken: F.token(),
                baseUrl: "https://exa mple.test/[x",
                noticeUuid: F.notice,
                purposes: [F.purpose()],
                declined: false
            ))
            XCTFail("expected an invalid request")
        } catch RedactoAPIError.invalidRequest {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertTrue(TransportStubProtocol.requests.isEmpty)
    }

    // MARK: - Guardian verification

    private func initiate(
        _ response: TransportStubResponse,
        metadata: [String: Any]? = nil
    ) async throws -> ConsentAPI.InitiateGuardianVerificationResponse {
        TransportStubProtocol.install { _ in response }
        return try await ConsentAPI.initiateGuardianVerification(.init(
            accessToken: F.token(),
            baseUrl: F.python,
            guardianName: " Asha ",
            guardianContact: "asha@example.test",
            guardianRelationship: "Mother",
            metadata: metadata
        ))
    }

    private var initiateRequests: [TransportStubRequest] {
        TransportStubProtocol.requests(pathSuffix: "/guardian/initiate-verification")
    }

    func testInitiateReadsAnUnwrappedBodyWithOneRequest() async throws {
        let response = try await initiate(.json(200, [
            "session_token": "s-1",
            "digilocker_redirect_url": "https://digilocker.example.test/auth",
            "expires_at": "2026-01-01T00:00:00Z",
        ]))
        XCTAssertEqual(initiateRequests.count, 1)
        XCTAssertEqual(response.sessionToken, "s-1")
        XCTAssertEqual(response.digilockerRedirectUrl, "https://digilocker.example.test/auth")
        XCTAssertEqual(response.success, true)
        XCTAssertEqual(response.alreadyVerified, false)
    }

    func testInitiateReadsAWrappedDetail() async throws {
        let response = try await initiate(.json(200, [
            "code": 200,
            "status": "success",
            "detail": ["already_verified": true, "verification_reference": "ref-1", "guardian_info_uuid": "g-1"],
        ]))
        XCTAssertEqual(initiateRequests.count, 1)
        XCTAssertEqual(response.alreadyVerified, true)
        XCTAssertEqual(response.verificationReference, "ref-1")
        XCTAssertEqual(response.guardianInfoUuid, "g-1")
        XCTAssertNil(response.sessionToken)
    }

    func testInitiateSendsMetadataAndTrimmedFields() async throws {
        _ = try await initiate(
            .json(200, ["session_token": "s", "digilocker_redirect_url": "https://d.example.test"]),
            metadata: ["minor_age": 15, "source": "app"]
        )
        let body = try XCTUnwrap(initiateRequests.first?.jsonBody)
        XCTAssertEqual(body["guardian_name"] as? String, "Asha")
        XCTAssertEqual(body["metadata"] as? [String: AnyHashable], ["minor_age": 15, "source": "app"])
        XCTAssertNil(body["frontend_callback_url"])
    }

    func testInitiateRejectsAResponseWithoutASession() async {
        do {
            _ = try await initiate(.json(200, ["detail": ["success": true]]))
            XCTFail("expected an invalid response")
        } catch RedactoAPIError.invalidRequest(let message) {
            XCTAssertEqual(message, "Invalid response: missing session_token or digilocker_redirect_url")
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(initiateRequests.count, 1)
    }

    private func verify(_ response: TransportStubResponse) async throws -> ConsentAPI.VerifyGuardianStatusResponse {
        TransportStubProtocol.install { _ in response }
        return try await ConsentAPI.verifyGuardianStatus(.init(accessToken: F.token(), baseUrl: F.python, sessionToken: "s-1"))
    }

    func testVerifyStatusMakesOneRequestAndDefaultsLikeReact() async throws {
        let response = try await verify(.json(200, ["code": 200]))
        XCTAssertEqual(TransportStubProtocol.requests(pathSuffix: "/guardian/verify-status").count, 1)
        XCTAssertEqual(response.status, "in_progress")
        XCTAssertEqual(response.canRetry, true)
        XCTAssertNil(response.verificationReference)
    }

    func testVerifyStatusReadsAWrappedDetailWithGuardianDetails() async throws {
        let response = try await verify(.json(200, [
            "detail": [
                "status": "failed",
                "error_code": "GUARDIAN_UNDER_18",
                "can_retry": false,
                "guardian_details": ["verified_name": "Asha", "is_guardian_adult": false, "verified_at": "t", "verification_reference": "ref-2"],
            ],
        ]))
        XCTAssertEqual(TransportStubProtocol.requests.count, 1)
        XCTAssertEqual(response.status, "failed")
        XCTAssertEqual(response.errorCode, "GUARDIAN_UNDER_18")
        XCTAssertEqual(response.canRetry, false)
        XCTAssertEqual(response.guardianDetails?.verificationReference, "ref-2")
        XCTAssertEqual(response.guardianDetails?.isGuardianAdult, false)
    }
}
