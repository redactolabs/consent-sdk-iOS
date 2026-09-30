import SwiftUI
import XCTest
@testable import RedactoConsentSDK

final class PrivacyCenterParityTests: XCTestCase {
    private typealias F = PCFixtures

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

    private func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    @MainActor
    private func makeStore(language: String = "en", ledger: String? = F.ledger, onError: @escaping @Sendable (Error) -> Bool = { _ in false }) -> PrivacyCenterStore {
        PrivacyCenterStore(
            baseUrl: F.base,
            slug: "acme",
            accessToken: F.liveToken,
            refreshToken: "refresh-1",
            themeMode: .light,
            initialPage: .consentManager,
            onBack: nil,
            onError: onError,
            language: language,
            urlSession: F.session(),
            ledgerBaseUrl: ledger
        )
    }

    // MARK: - Decoding

    func testAPurposeKeyedByTheLegacyUuidStillDecodes() throws {
        let item = try decode(PurposeItem.self, ["uuid": "legacy-1", "name": "Marketing", "status": "ACTIVE"])
        XCTAssertEqual(item.purposeUuid, "legacy-1")
        XCTAssertEqual(item.method, "")
        XCTAssertTrue(item.dataElements.isEmpty)
    }

    func testAnUnknownPurposeStatusKeepsItsText() throws {
        let item = try decode(PurposeItem.self, ["purpose_uuid": "p", "name": "X", "status": "PAUSED"])
        XCTAssertEqual(item.status, .unknown)
        XCTAssertEqual(item.statusText, "PAUSED")
    }

    func testAnUnexpectedUserStatusDoesNotLoseTheConsentList() throws {
        var group = F.groupJSON(product: F.productA, name: "Savings", notice: F.notice)
        group["purposes"] = [["uuid": "legacy", "name": "Y", "status": "WITHDRAWN", "data_elements": [["uuid": "e"]]]]
        let detail = try decode(UserConsentDetail.self, ["user_status": "SUSPENDED", "direct": [group]])
        XCTAssertNil(detail.userStatus)
        XCTAssertEqual(detail.direct?.first?.purposes.first?.status, .withdrawn)
        XCTAssertEqual(detail.direct?.first?.purposes.first?.dataElements.first?.enabled, true)
    }

    func testFormDataDropsAnUnknownGrievanceAndReadsLegacyPurposeIds() throws {
        let form = try decode(PrivacyFormData.self, [
            "uuid": "form-1",
            "grievance_options": [["value": "data_breach", "label": "x"], ["value": "new_kind", "label": "y"]],
            "purposes": [["purpose": ["purpose_uuid": "pp", "name": "N", "data_elements": [["uuid": "d", "name": "Email"]]]]],
        ])
        XCTAssertEqual(form.grievanceOptions.map(\.value), [.dataBreach])
        XCTAssertEqual(form.purposes.first?.purpose.uuid, "pp")
        XCTAssertEqual(form.contact, "")
    }

    func testAnActivityWithoutATitleOrTimestampDecodes() throws {
        let detail = try decode(ActivityDetail.self, ["data": [["activity_type": "consent_granted"]], "pagination": ["total_count": 1]])
        XCTAssertEqual(detail.items.first?.title, "")
        XCTAssertEqual(detail.items.first?.displayType, "Consent Granted")
    }

    func testACaseCarriesItsRequestDetailsWithNullCollections() throws {
        let caseRequest = try decode(CaseRequest.self, [
            "uuid": "c-1", "case_id": "CASE-1", "status": "completed", "request_type": "correction",
            "completed_at": "2026-01-02T00:00:00Z",
            "request_details": [
                "purposes": NSNull(),
                "correction_data": [["name": "Email", "curr_value": "a", "new_value": "b"]],
                "grievance_types": [["grievance": "data_breach"]],
                "nomination_data": ["nominee_email": "n@example.test"],
            ] as [String: Any],
        ])
        XCTAssertEqual(caseRequest.requestDetails?.purposes.count, 0)
        XCTAssertEqual(caseRequest.requestDetails?.correctionData.first?.newValue, "b")
        XCTAssertEqual(caseRequest.requestDetails?.grievanceTypes, ["data_breach"])
        XCTAssertTrue(caseRequest.isFinalized)
        XCTAssertEqual(caseRequest.displayStatus, "Completed")
        XCTAssertEqual(caseRequest.displayRequestType, "Correction")
    }

    func testCreateCaseFallsBackToTheUuid() throws {
        XCTAssertEqual(try decode(CreateCaseDetail.self, ["uuid": "u-1"]).caseId, "u-1")
    }

    // MARK: - Dates

    func testNaiveAndMicrosecondTimestampsParse() {
        XCTAssertNotNil(PrivacyCenterDateFormatters.parse("2026-01-15T10:30:00"))
        XCTAssertNotNil(PrivacyCenterDateFormatters.parse("2026-01-15T10:30:00.123456Z"))
        XCTAssertNotNil(PrivacyCenterDateFormatters.parse("2026-01-15T10:30:00.123456+05:30"))
        XCTAssertNotNil(PrivacyCenterDateFormatters.parse("2026-01-15"))
        XCTAssertNil(PrivacyCenterDateFormatters.parse("not a date"))
    }

    func testDatesFollowThePickerLanguage() {
        XCTAssertEqual(PrivacyCenterDateFormatters.formatDateShort("2025-01-15T10:30:00"), "15 Jan 2025")
        XCTAssertEqual(PrivacyCenterDateFormatters.formatDate("2025-01-15T10:30:00"), "Jan 15, 2025")
        XCTAssertEqual(PrivacyCenterDateFormatters.formatDateShort(nil), "-")
        PCStrings.currentLanguage = "hi"
        let hindi = PrivacyCenterDateFormatters.formatDate("2025-01-15T10:30:00")
        XCTAssertFalse(hindi.contains("Jan"))
        XCTAssertTrue(hindi.contains("2025"))
        PCStrings.currentLanguage = "sa"
        XCTAssertEqual(PrivacyCenterDateFormatters.formatDate("2025-01-15T10:30:00"), "Jan 15, 2025")
    }

    func testTimeAgoUsesTheTranslatedUnits() {
        let now = Date()
        let iso = ISO8601DateFormatter()
        XCTAssertEqual(PrivacyCenterDateFormatters.timeAgo(iso.string(from: now.addingTimeInterval(-300)), now: now), "5m ago")
        XCTAssertEqual(PrivacyCenterDateFormatters.timeAgo(iso.string(from: now.addingTimeInterval(-3 * 86400)), now: now), "3d ago")
        XCTAssertEqual(PrivacyCenterDateFormatters.timeAgo(nil, now: now), "Just now")
    }

    // MARK: - Strings

    func testSharedStringsInterpolateAndPluralise() {
        XCTAssertEqual(PCStrings.userIdLabel("U-1"), "User ID: U-1")
        XCTAssertEqual(PCStrings.activePurposes(1), "1 purpose")
        XCTAssertEqual(PCStrings.activePurposes(3), "3 purposes")
        XCTAssertEqual(PCStrings.pageOf(2, total: 5), "Page 2 of 5")
        PCStrings.currentLanguage = "hi"
        XCTAssertNotEqual(PCStrings.sessionExpiredTitle, "Your session has expired")
        XCTAssertEqual(PCStrings.revocationNotDeletionNote, PCStrings.t("revocationNotDeletionNote"))
    }

    func testDecodingErrorsDoNotShowTheResponse() {
        let error = PrivacyCenterAPIError.decodingError("keyNotFound. Response: {\"secret\":1}")
        XCTAssertFalse(error.localizedDescription.contains("Response"))
        XCTAssertTrue(error.debugDescription.contains("Response"))
    }

    // MARK: - Language

    @MainActor
    func testAnUnsupportedDeviceLanguageFallsBackToEnglish() {
        XCTAssertEqual(PrivacyCenterStore.resolveLanguage(nil, preferred: ["fr-FR"]), "en")
        XCTAssertEqual(PrivacyCenterStore.resolveLanguage(nil, preferred: ["fr-FR", "hi-IN"]), "hi")
        XCTAssertEqual(PrivacyCenterStore.resolveLanguage("mni-Mtei", preferred: []), "mni-Mtei")
        XCTAssertEqual(PrivacyCenterStore.resolveLanguage("de", preferred: ["hi"]), "en")
    }

    @MainActor
    func testEnglishSendsNoLanguageParam() {
        XCTAssertNil(makeStore(language: "en").langParam)
        XCTAssertEqual(makeStore(language: "ta").langParam, "ta")
    }

    // MARK: - Modify consent

    private func consent(_ status: ConsentStatus, elements: [ConsentDataElement] = []) -> UserConsent {
        UserConsent(
            purposeUuid: "p", purpose: "Marketing", purposeDescription: "", status: status, givenDate: "",
            validTill: nil, method: "WEB", dataElements: elements, productUuid: F.productA, productName: "Savings",
            productDescription: nil, nominatorInfo: nil, revokeWarningMessage: nil, noticeUuid: nil
        )
    }

    @MainActor
    func testEachStatusOffersReactsOneAction() {
        XCTAssertEqual(ModifyConsentViewModel(consent: consent(.active)).action, .revoke)
        XCTAssertEqual(ModifyConsentViewModel(consent: consent(.withdrawn)).action, .regrant)
        XCTAssertEqual(ModifyConsentViewModel(consent: consent(.expired)).action, .renew)
        XCTAssertNil(ModifyConsentViewModel(consent: consent(.declined)).action)
        XCTAssertNil(ModifyConsentViewModel(consent: consent(.unknown)).action)
        XCTAssertFalse(ModifyConsentViewModel(consent: consent(.active)).canRenew)
    }

    @MainActor
    func testARegrantStartsWithEveryEnabledElementAndKeepsTheRequiredOnes() {
        let vm = ModifyConsentViewModel(consent: consent(.withdrawn, elements: [
            ConsentDataElement(uuid: "a", name: "A", enabled: true, required: true, selected: false),
            ConsentDataElement(uuid: "b", name: "B", enabled: true, required: false, selected: false),
            ConsentDataElement(uuid: "c", name: "C", enabled: false, required: false, selected: false),
        ]))
        XCTAssertEqual(vm.selectedDataElementUuids, ["a", "b"])
        XCTAssertTrue(vm.isAccordionOpen)
        vm.toggleDataElement("a")
        vm.toggleDataElement("b")
        XCTAssertEqual(vm.dataElementUuidsForAction, ["a"])
        XCTAssertEqual(vm.warningText, PCStrings.regrantConsentWarning)
    }

    // MARK: - DSR form

    @MainActor
    func testNomineeContactRules() {
        XCTAssertEqual(DSRFormViewModel.cleanMobile("+91 98765-43210"), "+919876543210")
        XCTAssertTrue(DSRFormViewModel.isNominationValid(NominationData(nomineeEmail: "n@example.test")))
        XCTAssertTrue(DSRFormViewModel.isNominationValid(NominationData(nomineeEmail: "", nomineeMobile: "+91 98765 43210")))
        XCTAssertFalse(DSRFormViewModel.isNominationValid(NominationData(nomineeEmail: "")))
        XCTAssertFalse(DSRFormViewModel.isNominationValid(NominationData(nomineeEmail: "nope")))
        XCTAssertFalse(DSRFormViewModel.isNominationValid(NominationData(nomineeEmail: "", nomineeMobile: "12")))
    }

    func testAnEmptyNomineeContactIsLeftOut() throws {
        let data = try JSONEncoder().encode(NominationData(nomineeEmail: "", nomineeMobile: "+919876543210"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["nominee_email"])
        XCTAssertEqual(json["nominee_mobile"] as? String, "+919876543210")
    }

    private static let formJSON: [String: Any] = [
        "uuid": "form-1",
        "name": "Person",
        "contact": F.contact,
        "grievance_options": [["value": "data_breach", "label": "Data breach"]],
        "purposes": [["purpose": [
            "uuid": F.purpose, "name": "Marketing",
            "data_elements": [["uuid": "e-1", "name": "Email"], ["uuid": "e-2", "name": "Phone"]],
        ] as [String: Any]]],
    ]

    @MainActor
    private func loadedForm(groups: [[String: Any]] = [], nominated: [[String: Any]] = []) async -> (DSRFormViewModel, PrivacyCenterStore) {
        PCMockURLProtocol.route(pathSuffix: "/form/data", .json(200, Self.formJSON))
        PCMockURLProtocol.route(pathSuffix: "/user-consents", .json(200, ["direct": groups, "nominated": nominated]))
        PCMockURLProtocol.route(pathSuffix: "/case", .json(200, ["case_id": "CASE-9", "uuid": "c-9"]))
        let store = makeStore()
        let vm = DSRFormViewModel(store: store)
        await vm.loadFormData()
        return (vm, store)
    }

    @MainActor
    func testTheProductPickerIsReadFromUserConsents() async throws {
        let (vm, _) = await loadedForm(
            groups: [F.groupJSON(product: F.productA, name: "Savings", notice: F.notice)],
            nominated: [F.groupJSON(product: F.productB, name: "Loans", notice: F.notice, nominator: F.nominatorJSON)]
        )
        let read = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/user-consents").first)
        XCTAssertEqual(read.query("limit"), "100")
        XCTAssertEqual(read.query("nominated_limit"), "100")
        XCTAssertEqual(vm.groups.map(\.id), [F.productA, "\(F.productB):\(F.nominator)"])
        XCTAssertFalse(vm.skipProductStep)
    }

    @MainActor
    func testANominatedAccessCaseCarriesTheProductAndThePrincipal() async throws {
        let (vm, _) = await loadedForm(
            groups: [F.groupJSON(product: F.productA, name: "Savings", notice: F.notice)],
            nominated: [F.groupJSON(product: F.productB, name: "Loans", notice: F.notice, nominator: F.nominatorJSON)]
        )
        vm.requestType = .access
        XCTAssertFalse(vm.isRequestDetailsValid)
        vm.selectProduct(vm.groups[1])
        vm.setPurpose(vm.purposes[0], selected: true)
        vm.timePeriod = "7"
        vm.confirmChecked = true
        XCTAssertTrue(vm.canSubmit)

        await vm.submitTapped()

        let body = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/case").first).json
        XCTAssertEqual(body["request_type"] as? String, "access")
        XCTAssertEqual(body["product_uuid"] as? String, F.productB)
        XCTAssertEqual(body["data_principal_uuid"] as? String, F.nominator)
        XCTAssertEqual(body["time_period"] as? Int, 7)
        XCTAssertEqual(body["name"] as? String, " ")
        XCTAssertNil(body["revoke_consent_on_fulfilment"])
        let purposes = try XCTUnwrap((body["request_details"] as? [String: Any])?["purposes"] as? [[String: Any]])
        XCTAssertEqual(purposes.first?["data_element_uuids"] as? [String], ["e-1", "e-2"])
        XCTAssertEqual(vm.submittedCase?.caseId, "CASE-9")
        XCTAssertEqual(vm.submittedCase?.productName, "Loans")
    }

    @MainActor
    func testADirectCaseLeavesThePrincipalToTheServer() async throws {
        let (vm, _) = await loadedForm(groups: [F.groupJSON(product: F.productA, name: "Savings", notice: F.notice)])
        XCTAssertTrue(vm.skipProductStep)
        vm.requestType = .access
        vm.setAllPurposes(selected: true)
        vm.confirmChecked = true

        await vm.submitTapped()

        let body = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/case").first).json
        XCTAssertEqual(body["product_uuid"] as? String, F.productA)
        XCTAssertNil(body["data_principal_uuid"])
        XCTAssertEqual(body["time_period"] as? Int, 30)
    }

    @MainActor
    func testErasureAsksBeforeSubmittingAndSendsTheChoice() async throws {
        let (vm, _) = await loadedForm(groups: [F.groupJSON(product: F.productA, name: "Savings", notice: F.notice)])
        vm.requestType = .erasure
        vm.setPurpose(vm.purposes[0], selected: true)
        vm.confirmChecked = true

        await vm.submitTapped()
        XCTAssertTrue(vm.isErasureModalOpen)
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/case").isEmpty)

        await vm.chooseErasureRevoke(true)
        let body = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/case").first).json
        XCTAssertEqual(body["revoke_consent_on_fulfilment"] as? Bool, true)
        XCTAssertEqual(body["time_period"] as? Int, 0)
        XCTAssertTrue(vm.revokeConsentOnFulfilment)
        XCTAssertEqual(vm.erasurePurposeSummary, "Marketing")
    }

    @MainActor
    func testWithoutProductGroupsTheFlatListIsOneUnanchoredGroup() async throws {
        let (vm, _) = await loadedForm()
        XCTAssertEqual(vm.groups.map(\.productUuid), [DSRFormViewModel.legacyProductGroupUuid])
        vm.requestType = .correction
        vm.toggleCorrectionField("Email")
        vm.confirmChecked = true
        XCTAssertFalse(vm.isRequestDetailsValid)
        vm.updateCorrection(name: "Email", current: "a@x.test", updated: " ")
        XCTAssertFalse(vm.isRequestDetailsValid)
        vm.updateCorrection(name: "Email", updated: "b@x.test")

        await vm.submitTapped()

        let body = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/case").first).json
        XCTAssertNil(body["product_uuid"])
        XCTAssertEqual(body["request_type"] as? String, "correction")
        let corrections = try XCTUnwrap((body["request_details"] as? [String: Any])?["correction_data"] as? [[String: Any]])
        XCTAssertEqual(corrections.first?["name"] as? String, "Email")
        XCTAssertEqual(corrections.first?["new_value"] as? String, "b@x.test")
    }

    @MainActor
    func testANominationSendsTheCleanedMobileOnly() async throws {
        let (vm, _) = await loadedForm()
        vm.requestType = .nomination
        vm.nominationData.nomineeMobile = "+91 (98765) 43210"
        vm.confirmChecked = true

        await vm.submitTapped()

        let body = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/case").first).json
        let nomination = try XCTUnwrap((body["request_details"] as? [String: Any])?["nomination_data"] as? [String: Any])
        XCTAssertEqual(nomination["nominee_mobile"] as? String, "+919876543210")
        XCTAssertNil(nomination["nominee_email"])
        XCTAssertNil(body["product_uuid"])
    }

    // MARK: - Uploads

    func testUploadsFollowReactsSizeAndTypeRules() {
        XCTAssertEqual(PCUploadValidation.problem(size: 0, mimeType: "application/pdf"), PCStrings.fileEmpty)
        XCTAssertEqual(PCUploadValidation.problem(size: 11 * 1024 * 1024, mimeType: "application/pdf"), PCStrings.fileTooLarge)
        XCTAssertEqual(PCUploadValidation.problem(size: 10, mimeType: "application/zip"), PCStrings.fileTypeNotSupported)
        XCTAssertEqual(PCUploadValidation.problem(size: 10, mimeType: ""), PCStrings.fileTypeUnknown)
        XCTAssertNil(PCUploadValidation.problem(size: 10, mimeType: "image/png"))
        XCTAssertEqual(PCUploadValidation.message(for: PrivacyCenterAPIError.serverError(409, nil)), PCStrings.uploadDuplicate)
        XCTAssertEqual(PCUploadValidation.message(for: PrivacyCenterAPIError.validationError(nil)), PCStrings.uploadFormatRejected)
    }

    @MainActor
    func testARejectedFileNeverReachesTheServer() async {
        let store = makeStore()
        let vm = CaseDetailsViewModel(store: store, caseRequest: CaseRequest(uuid: "c-1", caseId: "CASE-1"))
        await vm.uploadAttachment(fileData: Data(count: 4), filename: "a.zip", mimeType: "application/zip")
        XCTAssertTrue(PCMockURLProtocol.requests(pathSuffix: "/upload-document").isEmpty)
        XCTAssertEqual(store.toast?.text, PCStrings.fileTypeNotSupported)
    }

    @MainActor
    func testAFinalizedCaseTakesNoMessages() {
        let store = makeStore()
        let vm = CaseDetailsViewModel(store: store, caseRequest: CaseRequest(uuid: "c-1", caseId: "CASE-1", status: "rejected"))
        vm.draftMessage = "hello"
        XCTAssertTrue(vm.isCaseFinalized)
        XCTAssertFalse(vm.canSend)
    }

    @MainActor
    func testADocumentRequestUploadIsFiledAgainstTheRequest() async throws {
        PCMockURLProtocol.route(pathSuffix: "/upload-document", .json(200, ["uuid": "doc-1", "file_name": "id.pdf", "file_size": 4]))
        PCMockURLProtocol.route(pathSuffix: "/submit", .json(200, ["uuid": "m-2", "message_type": "document_submitted"]))
        PCMockURLProtocol.route(pathSuffix: "/messages", .json(200, [] as [Any]))
        let store = makeStore()
        let vm = CaseDetailsViewModel(store: store, caseRequest: CaseRequest(uuid: "c-1", caseId: "CASE-1"))

        await vm.uploadForDocumentRequest(requestEventUuid: "req-1", fileData: Data(count: 4), filename: "id.pdf", mimeType: "application/pdf")

        let submit = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/submit").first)
        XCTAssertTrue(submit.path.hasSuffix("/cases/c-1/document-requests/req-1/submit"))
        XCTAssertEqual(submit.json["document_uuid"] as? String, "doc-1")
        XCTAssertNil(vm.submittingForRequest)
    }

    @MainActor
    func testAnAttachmentWithoutAUrlIsLookedUp() async throws {
        PCMockURLProtocol.route(pathSuffix: "/documents/doc-1", .json(200, ["uuid": "doc-1", "file_url": ["download_url": "https://files.example.test/doc-1"]]))
        let vm = CaseDetailsViewModel(store: makeStore(), caseRequest: CaseRequest(uuid: "c-1", caseId: "CASE-1"))
        let url = await vm.documentURL(for: MessageDocument(uuid: "doc-1"))
        XCTAssertEqual(url?.absoluteString, "https://files.example.test/doc-1")
        XCTAssertEqual(PCMockURLProtocol.requests.first?.urlWithoutQuery, "\(F.consentPrefix)/cases/c-1/documents/doc-1")
    }

    @MainActor
    func testMessagesReadOldestFirst() {
        let late = CaseMessage(uuid: "b", caseUuid: "c", senderRole: .dataPrincipal, triggeredByEmail: "", createdAt: "2026-01-02T00:00:00Z", body: "", messageType: .messageSent)
        let early = CaseMessage(uuid: "a", caseUuid: "c", senderRole: .dataPrincipal, triggeredByEmail: "", createdAt: "2026-01-01T00:00:00Z", body: "", messageType: .messageSent)
        XCTAssertEqual(CaseDetailsViewModel.sorted([late, early]).map(\.uuid), ["a", "b"])
    }

    // MARK: - Case list

    @MainActor
    func testTheCaseListIsReadWholeAndFilteredOnTheDevice() async throws {
        PCMockURLProtocol.route(pathSuffix: "/cases", .json(200, ["data": [
            ["uuid": "1", "case_id": "A-1", "status": "in_progress", "request_type": "access"],
            ["uuid": "2", "case_id": "B-2", "status": "declined", "request_type": "erasure"],
            ["uuid": "3", "case_id": "C-3", "status": "completed", "request_type": "access", "description": "About my phone"],
        ]]))
        let vm = CaseHistoryViewModel(store: makeStore())
        await vm.loadInitial()

        let read = try XCTUnwrap(PCMockURLProtocol.requests(pathSuffix: "/cases").first)
        XCTAssertNil(read.query("offset"))
        XCTAssertNil(read.query("limit"))
        vm.statusFilter = .processing
        XCTAssertEqual(vm.filteredCases.map(\.caseId), ["A-1"])
        vm.statusFilter = .rejected
        XCTAssertEqual(vm.filteredCases.map(\.caseId), ["B-2"])
        vm.statusFilter = .all
        vm.selectedRequestTypes = [.erasure]
        XCTAssertEqual(vm.filteredCases.map(\.caseId), ["B-2"])
        vm.selectedRequestTypes = Set(RequestType.allCases)
        vm.searchText = "phone"
        XCTAssertEqual(vm.filteredCases.map(\.caseId), ["C-3"])
        vm.searchText = ""
        vm.pageSize = 2
        vm.goToPage(1)
        XCTAssertEqual(vm.pagedCases.map(\.caseId), ["C-3"])
    }

    // MARK: - Consent manager

    @MainActor
    func testExportDefusesFormulasAndQuotesCells() {
        let csv = ConsentManagerViewModel.csv(headers: ["A"], rows: [["=SUM(1)"], ["say \"hi\""]])
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        XCTAssertTrue(csv.contains("\"'=SUM(1)\""))
        XCTAssertTrue(csv.contains("\"say \"\"hi\"\"\""))
    }

    @MainActor
    func testValidTillReadsAsReactShowsIt() {
        XCTAssertEqual(ConsentManagerViewModel.validTillLabel(consent(.active)), "Until Withdrawal (no expiry)")
        XCTAssertEqual(ConsentManagerViewModel.validTillLabel(consent(.withdrawn)), "-")
    }

    @MainActor
    func testANominatorErrorGetsItsOwnMessage() {
        let error = PrivacyCenterAPIError.validationError("nominator_not_found")
        XCTAssertEqual(ConsentManagerViewModel.failureMessage(.revoke, error: error), PCStrings.nominatorNotFound)
        let other = PrivacyCenterAPIError.validationError("nominee_must_specify_nominator")
        XCTAssertEqual(ConsentManagerViewModel.failureMessage(.revoke, error: other), PCStrings.nomineeMustSpecifyNominator)
        XCTAssertEqual(ConsentManagerViewModel.failureMessage(.renew, error: nil), PCStrings.unableToRenewConsent)
    }

    @MainActor
    func testTheProductFilterKeepsTheFullProductList() async throws {
        PCMockURLProtocol.route(pathSuffix: "/user-consents", .json(200, [
            "direct": [F.groupJSON(product: F.productA, name: "Savings", notice: F.notice), F.groupJSON(product: F.productB, name: "Loans", notice: F.notice)],
            "user_status": "TRANSFERRED",
        ] as [String: Any]))
        let vm = ConsentManagerViewModel(store: makeStore())
        await vm.refresh()
        XCTAssertEqual(vm.productOptions.map(\.name), ["Savings", "Loans"])
        XCTAssertEqual(vm.userStatus, .transferred)
        XCTAssertEqual(vm.displayGroups.first?.activeCount, 1)
        XCTAssertEqual(vm.summaryText, "2 products, 2 consents")

        vm.productFilter = F.productA
        await vm.refresh()
        XCTAssertEqual(vm.productOptions.count, 2)
        XCTAssertEqual(vm.displayGroups.map(\.group.productUuid), [F.productA])
    }

    // MARK: - Session

    private func expiredToken() -> String {
        F.jwt(["organisation_uuid": F.org, "workspace_uuid": F.ws, "email": F.contact, "exp": 1])
    }

    func testADeadRefreshTokenIsPresentedOnce() async throws {
        let reported = CallCounter()
        let expired = CallCounter()
        let tokens = TokenStore(
            baseUrl: F.base, accessToken: expiredToken(), refreshToken: "dead",
            onError: { _ in reported.count += 1; return false },
            urlSession: F.session(),
            onSessionExpired: { expired.count += 1 }
        )
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(401, ["detail": "Refresh token already used"]))

        await XCTAssertThrowsAsync(try await tokens.rawToken())
        await XCTAssertThrowsAsync(try await tokens.rawToken())

        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/otp/refresh").count, 1)
        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual(expired.count, 1)
        let isExpired = await tokens.isSessionExpired
        XCTAssertTrue(isExpired)
        let blocked = await tokens.isRefreshBlocked()
        XCTAssertTrue(blocked)

        await tokens.syncFromHost(accessToken: expiredToken(), refreshToken: "fresh")
        let stillBlocked = await tokens.isRefreshBlocked()
        let stillExpired = await tokens.isSessionExpired
        XCTAssertFalse(stillBlocked)
        XCTAssertFalse(stillExpired)
    }

    func testATransientRefreshFailureBacksOff() async {
        let tokens = TokenStore(baseUrl: F.base, accessToken: expiredToken(), refreshToken: "r", onError: { _ in false }, urlSession: F.session())
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(503))

        await XCTAssertThrowsAsync(try await tokens.rawToken())
        do {
            _ = try await tokens.rawToken()
            XCTFail("expected backoff")
        } catch {
            XCTAssertTrue(error is PrivacyCenterRefreshBackoffError)
        }
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/otp/refresh").count, 1)
        let expired = await tokens.isSessionExpired
        XCTAssertFalse(expired)
    }

    func testARefreshTellsTheHostOfTheRotatedTokens() async throws {
        let received = TokenBox()
        let tokens = TokenStore(
            baseUrl: F.base, accessToken: expiredToken(), refreshToken: "r",
            onError: { _ in false }, updateTokens: { access, refresh in received.set(access, refresh) },
            urlSession: F.session()
        )
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(200, ["access_token": F.refreshedToken, "refresh_token": "r2"]))
        _ = try await tokens.rawToken()
        XCTAssertEqual(received.access, F.refreshedToken)
        XCTAssertEqual(received.refresh, "r2")
    }

    @MainActor
    func testTheStoreShowsTheExpiredScreenAndReportsOnce() async throws {
        let reported = CallCounter()
        let store = PrivacyCenterStore(
            baseUrl: F.base, slug: "", accessToken: expiredToken(), refreshToken: "dead",
            themeMode: .light, initialPage: .consentManager, onBack: .signout,
            onError: { _ in reported.count += 1; return false },
            language: "en", urlSession: F.session(), ledgerBaseUrl: F.ledger
        )
        PCMockURLProtocol.route(pathSuffix: "/otp/refresh", .json(401))
        await store.checkDataAvailability()
        await waitUntil { store.isSessionExpired }

        XCTAssertTrue(store.isSessionExpired)
        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual(PCMockURLProtocol.requests(pathSuffix: "/otp/refresh").count, 1)

        await store.syncHostTokens(accessToken: F.liveToken, refreshToken: "fresh")
        XCTAssertFalse(store.isSessionExpired)
    }

    // MARK: - Notifications

    func testNotificationRoutes() async throws {
        let api = F.api(ledger: F.ledger)
        PCMockURLProtocol.route(pathSuffix: "/notifications", .json(200, ["data": [["uuid": "n-1", "notification_type": "brand_new_kind", "title": "T"]], "total": 1]))
        let list = try await api.getNotifications(category: .consent, skip: 10, limit: 10, includeSummary: true, language: "hi")
        try await api.markNotificationRead(uuid: "n-1")
        try await api.markAllNotificationsRead()
        try await api.acknowledgeNotification(uuid: "n-1")
        _ = try await api.getUnreadNotificationCount()

        XCTAssertEqual(list.data.first?.uuid, "n-1")
        XCTAssertEqual(PrivacyNotificationIconCategory(notificationType: list.data[0].notificationType), .system)
        let requests = PCMockURLProtocol.requests
        XCTAssertEqual(requests[0].urlWithoutQuery, "\(F.consentPrefix)/notifications/")
        XCTAssertEqual(requests[0].query("category"), "consent")
        XCTAssertEqual(requests[0].query("include_summary"), "true")
        XCTAssertEqual(requests[0].query("language"), "hi")
        XCTAssertEqual(requests[1].method, "PATCH")
        XCTAssertEqual(requests[1].urlWithoutQuery, "\(F.consentPrefix)/notifications/n-1/read")
        XCTAssertEqual(requests[2].method, "POST")
        XCTAssertEqual(requests[2].urlWithoutQuery, "\(F.consentPrefix)/notifications/mark-all-read")
        XCTAssertEqual(requests[3].urlWithoutQuery, "\(F.consentPrefix)/notifications/n-1/acknowledge")
        XCTAssertEqual(requests[4].urlWithoutQuery, "\(F.consentPrefix)/notifications/unread-count")
    }

    @MainActor
    func testOnlyActionableCTAsRender() {
        XCTAssertTrue(NotificationsViewModel.isActionable(PrivacyNotificationCTA(label: "OK", actionType: .acknowledge)))
        XCTAssertFalse(NotificationsViewModel.isActionable(PrivacyNotificationCTA(label: "Go", actionType: .link)))
        XCTAssertFalse(NotificationsViewModel.isActionable(PrivacyNotificationCTA(label: "", actionType: .acknowledge)))
        XCTAssertFalse(NotificationsViewModel.isActionable(PrivacyNotificationCTA(label: "?", actionType: nil)))
    }

    @MainActor
    func testACaseLinkOpensTheCase() async throws {
        PCMockURLProtocol.route(pathSuffix: "/cases", .json(200, ["data": [["uuid": "c-7", "case_id": "CASE-7"]]]))
        let store = makeStore()
        let vm = NotificationsViewModel(store: store)
        let notification = PrivacyNotification(uuid: "n-1", notificationType: "case_message", title: "T", isRead: true)
        let result = await vm.performCTA(PrivacyNotificationCTA(label: "View", actionType: .link, url: "/case-details/c-7"), on: notification, fromPage: true)
        XCTAssertEqual(result, .navigated)
        XCTAssertEqual(store.currentPage, .caseDetails)
        XCTAssertEqual(store.selectedCase?.caseId, "CASE-7")
    }

    // MARK: - Branding

    func testBrandingSurfacesApplyOnlyInLightMode() {
        let branding = OrgBrandingTheme(primary: "#112233", surface: "#fafafa", text: "#101010", danger: "#aa0000")
        let light = PrivacyCenterTheme.from(mode: .light, branding: branding)
        let dark = PrivacyCenterTheme.from(mode: .dark, branding: branding, appearance: .glass)
        XCTAssertEqual(light.primary, AppearanceColor.parse("#112233")!.color)
        XCTAssertEqual(light.background, AppearanceColor.parse("#fafafa")!.color)
        XCTAssertEqual(dark.primary, AppearanceColor.parse("#112233")!.color)
        XCTAssertEqual(dark.background, PrivacyCenterTheme.dark.background)
        XCTAssertEqual(dark.error, AppearanceColor.parse("#aa0000")!.color)
        XCTAssertTrue(dark.isGlass)
        XCTAssertEqual(PrivacyCenterSettings(theme: "neon").appearance, .classic)
    }

    func testBrandingIsReadFromTheUserServer() {
        XCTAssertEqual(PrivacyCenterBrandingAPI.userServerBaseUrl(for: "https://api.redacto.io/consent"), "https://api.redacto.io/user/api/0")
        XCTAssertEqual(PrivacyCenterBrandingAPI.userServerBaseUrl(for: F.base), "https://api.redacto.tech/user/api/0")
    }
}

final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var access: String?
    private(set) var refresh: String?

    func set(_ access: String, _ refresh: String?) {
        lock.lock(); defer { lock.unlock() }
        self.access = access
        self.refresh = refresh
    }
}

func XCTAssertThrowsAsync<T>(_ expression: @autoclosure () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("expected an error", file: file, line: line)
    } catch {}
}
