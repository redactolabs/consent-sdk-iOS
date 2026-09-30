import SwiftUI
import XCTest
@testable import RedactoConsentSDK

/// Modal-notice behaviour ported from the React SDK's RedactoNoticeConsent.
@MainActor
final class NoticeReactParityTests: XCTestCase {
    typealias N = NoticeProductFixtures

    private let orders = N.requiredPurpose("purpose-orders", "Order Fulfilment", [])
    private let marketing = N.optionalPurpose("purpose-marketing", "Marketing", [])
    private let alerts = N.optionalPurpose("purpose-alerts", "Alerts", [])

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    // MARK: - Order

    func testASingleProductNoticeFollowsTheSavedOrderInRowsListAndTalkback() throws {
        let viewModel = N.viewModel(try N.notice(
            products: [N.product("prod-a", "Product A", mandatory: false)],
            purposes: [orders, marketing, alerts],
            config: ["product_purpose_order": ["prod-a": ["purpose-alerts", "purpose-orders"]]]
        ))

        let expected = ["purpose-alerts", "purpose-orders", "purpose-marketing"]
        XCTAssertEqual(viewModel.purposeRows.map(\.purpose.uuid), expected)
        XCTAssertEqual(viewModel.renderedPurposes.map(\.uuid), expected)
        XCTAssertEqual(viewModel.ttsPurposes.map(\.uuid), expected)
        XCTAssertTrue(viewModel.purposeRows.allSatisfy { $0.productUuid == nil })
    }

    // MARK: - Locks and review

    func testAReconsentLocksAndListsFirstWhatIsAlreadyConsentedAndLeavesTheRestEditable() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [orders, marketing, alerts],
            detail: [
                "reconsent_required": true,
                "purpose_selections": [
                    "purpose-orders": N.recorded(needsReconsent: true),
                    "purpose-marketing": N.recorded(),
                ],
            ]
        ))

        XCTAssertEqual(viewModel.categorizedPurposes?.alreadyConsented.map(\.uuid), ["purpose-marketing"])
        XCTAssertEqual(viewModel.categorizedPurposes?.needsConsent.map(\.uuid), ["purpose-orders", "purpose-alerts"])
        XCTAssertTrue(viewModel.isRowLocked("purpose-marketing", productUuid: nil))
        XCTAssertFalse(viewModel.isRowLocked("purpose-orders", productUuid: nil))
        XCTAssertFalse(viewModel.isRowLocked("purpose-alerts", productUuid: nil))
        XCTAssertFalse(viewModel.isReviewMode)
        XCTAssertEqual(viewModel.ttsPurposes.map(\.uuid), ["purpose-marketing", "purpose-orders", "purpose-alerts"])
    }

    func testAnExpiredGrantNotAskedBackIsListedInBothHalvesOfTheSplit() {
        let split = ProductConsent.categorize(
            purposes: NoticeFixtures.content().detail.activeConfig.purposes,
            purposeSelections: [
                NoticeFixtures.orders: PurposeSelection(selected: true, status: "EXPIRED", needsReconsent: false, dataElements: [:]),
            ]
        )
        XCTAssertEqual(split.alreadyConsented.map(\.uuid), [NoticeFixtures.orders])
        XCTAssertEqual(split.needsConsent.map(\.uuid), [NoticeFixtures.orders, NoticeFixtures.marketing])
    }

    func testOutsideAReconsentOrReviewNothingIsLocked() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [orders, marketing],
            detail: ["purpose_selections": ["purpose-orders": N.recorded()]]
        ))
        XCTAssertNil(viewModel.categorizedPurposes)
        XCTAssertFalse(viewModel.isRowLocked("purpose-orders", productUuid: nil))
    }

    func testReviewModeNeedsOnlyEveryRowSelectedAndLocksThemAll() throws {
        let viewModel = N.viewModel(
            try N.notice(
                products: nil,
                purposes: [orders, marketing],
                detail: ["purpose_selections": [
                    "purpose-orders": N.recorded(needsReconsent: true),
                    "purpose-marketing": N.recorded(),
                ]]
            ),
            includeFullyConsentedData: true
        )
        XCTAssertTrue(viewModel.isReviewMode)
        XCTAssertTrue(viewModel.isRowLocked("purpose-orders", productUuid: nil))
        XCTAssertTrue(viewModel.isRowLocked("purpose-marketing", productUuid: nil))
    }

    func testReviewModeNeedsTheHostToAskForIt() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [orders],
            detail: ["purpose_selections": ["purpose-orders": N.recorded()]]
        ))
        XCTAssertFalse(viewModel.isReviewMode)
    }

    // MARK: - Element baseline and edits

    func testTheElementBaselineCoversRecordedRowsOnly() throws {
        let email: [String: Any] = ["selected": true, "enabled": true, "required": true]
        var recorded = N.recorded()
        recorded["data_elements"] = ["purpose-orders-id": email]
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [orders, marketing],
            detail: ["purpose_selections": [
                "purpose-orders": recorded,
                "purpose-marketing": N.recorded(selected: false, status: "INACTIVE"),
            ]]
        ))
        XCTAssertEqual(viewModel.initialDataElementSelections, [
            "purpose-orders-purpose-orders-id": true,
            "purpose-orders-purpose-orders-extra": false,
        ])
    }

    func testAnElementEditSubmitsAConsentedPurposeSelectedOnlyOnAReconsent() throws {
        let detail: (Bool) -> [String: Any] = { reconsent in
            ["reconsent_required": reconsent, "purpose_selections": ["purpose-marketing": N.recorded(selected: true)]]
        }
        for reconsent in [false, true] {
            let viewModel = N.viewModel(try N.notice(products: nil, purposes: [marketing], detail: detail(reconsent)))
            viewModel.selectedPurposes["purpose-marketing"] = false
            viewModel.selectedDataElements["purpose-marketing-purpose-marketing-extra"] = true

            let sent = ProductConsent.submissionPurposes(
                rows: viewModel.purposeRows,
                selection: SelectionState(selectedPurposes: viewModel.selectedPurposes, selectedDataElements: viewModel.selectedDataElements),
                mode: .selected,
                recordedPurposeSelections: viewModel.modificationBaseline,
                initialDataElementSelections: viewModel.initialDataElementSelections
            )
            XCTAssertEqual(sent.first?.selected, reconsent, "reconsent: \(reconsent)")
        }
    }

    // MARK: - Submit payload

    private func submittedBody(language: String, applicationId: String?) async throws -> [String: Any] {
        TransportStubProtocol.install { request in
            request.path.hasSuffix("/submit-consent") ? .empty(201) : .json(404, ["message": "none"])
        }
        let viewModel = ConsentNoticeViewModel(
            noticeId: "notice-1",
            accessToken: NoticeFixtures.agentToken,
            refreshToken: "",
            baseUrl: NoticeFixtures.baseUrl,
            onAccept: {},
            onDecline: {},
            applicationId: applicationId
        )
        viewModel.content = NoticeFixtures.content()
        viewModel.seedSelectionState(from: NoticeFixtures.content())
        viewModel.selectedLanguage = language
        viewModel.handleAccept(mode: .all)
        await waitUntil { !TransportStubProtocol.requests(pathSuffix: "/submit-consent").isEmpty }
        return try XCTUnwrap(TransportStubProtocol.requests(pathSuffix: "/submit-consent").first?.jsonBody)
    }

    func testSubmitCarriesTheShownLanguageAsBcp47AndNoMetaDataWithoutAnApplication() async throws {
        let body = try await submittedBody(language: "Hindi", applicationId: "")
        XCTAssertEqual(body["language"] as? String, "hi")
        XCTAssertNil(body["meta_data"])
    }

    func testSubmitCarriesTheApplicationAndNoMinorAge() async throws {
        let body = try await submittedBody(language: "English", applicationId: "app-9")
        XCTAssertEqual(body["language"] as? String, "en")
        XCTAssertEqual(body["meta_data"] as? [String: String], ["specific_uuid": "app-9"])
    }

    // MARK: - Footer

    func testAdditionalTextShowsWithoutAPrivacyCenterLink() {
        let notice = makeNotice(content: NoticeFixtures.content(config: ["additional_text": "Ask us anything."]))
        XCTAssertTrue(notice.vm.hasPrivacyCenterLine)
        XCTAssertTrue(notice.vm.showsNoticeFooter)

        let bare = makeNotice()
        XCTAssertFalse(bare.vm.hasPrivacyCenterLine)
        XCTAssertFalse(bare.vm.showsNoticeFooter)
    }

    // MARK: - Load, errors and props

    private func serve(_ data: @escaping (TransportStubRequest) -> TransportStubResponse) async {
        await ConsentAPI.clearCache()
        TransportStubProtocol.install(data)
    }

    nonisolated private static func noticeJSON(_ config: [String: Any] = [:]) -> Any {
        try! JSONSerialization.jsonObject(with: NoticeFixtures.contentData(config: config))
    }

    func testAFailedReadShowsTheErrorDialogAndRetryReadsAgain() async {
        var fail = true
        await serve { request in
            guard request.path.contains("/notices/"), !request.path.contains("/audio/") else { return .json(404, [:]) }
            return fail ? .json(500, ["message": "Notice unavailable."]) : .json(200, Self.noticeJSON())
        }
        let errors = CallCounter()
        let viewModel = ConsentNoticeViewModel(
            noticeId: "notice-1",
            accessToken: NoticeFixtures.agentToken,
            refreshToken: "",
            baseUrl: NoticeFixtures.baseUrl,
            onAccept: {},
            onDecline: {},
            onError: { _ in errors.count += 1 }
        )
        await viewModel.fetchContent().value

        XCTAssertEqual(viewModel.fetchErrorMessage, "Notice unavailable.")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(errors.count, 1)

        fail = false
        await viewModel.fetchContent().value
        XCTAssertNil(viewModel.fetchErrorMessage)
        XCTAssertNotNil(viewModel.content)
    }

    func testAMissingTokenIsAConfigurationErrorAndReadsNothing() async {
        await serve { _ in .json(200, Self.noticeJSON()) }
        let viewModel = ConsentNoticeViewModel(noticeId: "notice-1", accessToken: " ", refreshToken: "", baseUrl: NoticeFixtures.baseUrl, onAccept: {}, onDecline: {})
        await viewModel.fetchContent().value

        XCTAssertEqual(viewModel.configurationErrorMessage, NoticeErrorCopy.missingAccessToken)
        XCTAssertTrue(TransportStubProtocol.requests.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testTheReadUsesTheHostLanguageAndOpensInTheDefaultLanguageNamedAsTheMenuNamesIt() async throws {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(200, Self.noticeJSON(["default_language": "en"]))
        }
        let viewModel = ConsentNoticeViewModel(noticeId: "notice-1", accessToken: NoticeFixtures.agentToken, refreshToken: "", baseUrl: NoticeFixtures.baseUrl, language: "hi", onAccept: {}, onDecline: {})
        await viewModel.fetchContent().value

        XCTAssertEqual(viewModel.selectedLanguage, "English")
        let read = try XCTUnwrap(TransportStubProtocol.requests.first { $0.path.hasSuffix("/notices/notice-1") })
        XCTAssertEqual(read.header("Accept-Language"), "hi")
    }

    private func identity(of viewModel: ConsentNoticeViewModel, token: String? = nil, language: String? = nil, applicationId: String? = nil) -> NoticeIdentity {
        NoticeIdentity(
            noticeId: viewModel.noticeId,
            accessToken: token ?? viewModel.accessToken,
            refreshToken: viewModel.refreshToken,
            language: language ?? viewModel.initialLanguage,
            applicationId: applicationId ?? viewModel.applicationId,
            ledgerBaseUrl: viewModel.ledgerBaseUrl,
            validateAgainst: viewModel.validateAgainst,
            includeFullyConsentedData: viewModel.includeFullyConsentedData,
            sandbox: NoticeSandboxInputs()
        )
    }

    func testChangingTheApplicationOrLanguageOnAMountedNoticeReadsItAgain() async throws {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(200, Self.noticeJSON())
        }
        let viewModel = ConsentNoticeViewModel(noticeId: "notice-1", accessToken: NoticeFixtures.agentToken, refreshToken: "", baseUrl: NoticeFixtures.baseUrl, onAccept: {}, onDecline: {})
        await viewModel.fetchContent().value

        await viewModel.updateIdentity(identity(of: viewModel, language: "ta", applicationId: "app-2"))?.value

        let reads = TransportStubProtocol.requests.filter { $0.path.hasSuffix("/notices/notice-1") }
        XCTAssertEqual(reads.count, 2)
        XCTAssertEqual(reads.last?.query("specific_uuid"), "app-2")
        XCTAssertEqual(reads.last?.header("Accept-Language"), "ta")
    }

    func testANewTokenDropsThePreviousPrincipalsChoicesAndReadsAgain() async throws {
        await serve { request in
            request.path.contains("/audio/") ? .json(404, [:]) : .json(200, Self.noticeJSON())
        }
        let viewModel = ConsentNoticeViewModel(noticeId: "notice-1", accessToken: NoticeFixtures.agentToken, refreshToken: "", baseUrl: NoticeFixtures.baseUrl, onAccept: {}, onDecline: {})
        await viewModel.fetchContent().value
        viewModel.handlePurposeToggle(NoticeFixtures.marketing)
        viewModel.errorMessage = "old"

        let task = viewModel.updateIdentity(identity(of: viewModel, token: NoticeFixtures.customerToken))
        XCTAssertNil(viewModel.content)
        XCTAssertTrue(viewModel.selectedPurposes.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        await task?.value

        XCTAssertEqual(viewModel.selectedPurposes[NoticeFixtures.marketing], false)
        let reads = TransportStubProtocol.requests.filter { $0.path.hasSuffix("/notices/notice-1") }
        XCTAssertEqual(reads.last?.header("Authorization"), "Bearer \(NoticeFixtures.customerToken)")
    }

    // MARK: - Language

    func testTheLanguageMenuPinsEnglishThenTheDefaultThenTheRestByName() {
        let content = NoticeFixtures.content(config: [
            "default_language": "Tamil",
            "supported_languages_and_translations": ["hindi": [String: Any](), "Bengali": [String: Any](), "Tamil": [String: Any]()],
        ])
        XCTAssertEqual(NoticeTranslation.supportedLanguages(content.detail.activeConfig), ["English", "Tamil", "Bengali", "hindi"])
    }

    func testTalkbackReadsAnUntranslatedLanguageInTheDefaultLanguage() {
        let config = NoticeFixtures.content(config: [
            "default_language": "Hindi",
            "supported_languages_and_translations": ["Hindi": [String: Any]()],
        ]).detail.activeConfig
        XCTAssertEqual(NoticeTranslation.audioLanguage("en", config: config), "English")
        XCTAssertEqual(NoticeTranslation.audioLanguage("Hindi", config: config), "Hindi")
        XCTAssertEqual(NoticeTranslation.audioLanguage("Tamil", config: config), "Hindi")
        XCTAssertEqual(NoticeTranslation.openingLanguage(defaultLanguage: "EN"), "English")
        XCTAssertNil(NoticeTranslation.openingLanguage(defaultLanguage: ""))
    }

    func testSectionTitlesFollowTheLanguageAndFallBackToNoticeCopy() {
        XCTAssertEqual(NoticeSectionCopy.labels(for: "English")?.about, "About this notice")
        XCTAssertEqual(NoticeSectionCopy.labels(for: "Hindi")?.dpo, "शिकायत और संपर्क")
        XCTAssertNil(NoticeSectionCopy.labels(for: "Klingon"))
        XCTAssertNil(NoticeSectionCopy.labels(for: "Bodo"))

        let notice = makeNotice(content: NoticeFixtures.content(config: ["notice_text": "We collect data."]))
        notice.vm.selectedLanguage = "Bodo"
        let about = notice.vm.sectionTitle(.about)
        XCTAssertEqual(about.title, "We collect data.")
        XCTAssertTrue(about.clamped)
    }

    // MARK: - Appearance

    func testTheConsoleSetsConfirmAndSelectionControlUnlessTheHostOverrides() {
        let console = NoticeFixtures.content(config: ["appearance": ["confirm_before_submit": true, "selection_control": "radio"]])
        let fromConsole = makeNotice(content: console)
        XCTAssertTrue(fromConsole.vm.confirmBeforeSubmit)
        XCTAssertEqual(fromConsole.vm.selectionControl, .radio)

        fromConsole.vm.requestAction(.decline)
        XCTAssertEqual(fromConsole.vm.pendingConfirmAction, .decline)
        XCTAssertEqual(fromConsole.declines.count, 0)

        let host = makeNotice(settings: ConsentSettings(selectionControl: .dropdown, confirmBeforeSubmit: false), content: console)
        XCTAssertFalse(host.vm.confirmBeforeSubmit)
        XCTAssertEqual(host.vm.selectionControl, .dropdown)
        host.vm.requestAction(.decline)
        XCTAssertEqual(host.declines.count, 1)
    }

    func testTheThemePaintsTheButtonsFromTheConsolePalette() {
        let appearance = NoticeAppearance.resolve(
            console: NoticeAppearance(colors: ["accept_all_bg": "#112233", "decline_border": "#445566", "accept_text": "#778899"]),
            settings: nil,
            colorScheme: .light
        )
        let theme = NoticeTheme(appearance: appearance, primaryColor: "#000000", secondaryColor: nil, isPhone: true)
        XCTAssertEqual(theme.acceptAll.background, AppearanceColor.color("#112233"))
        XCTAssertEqual(theme.decline.border, AppearanceColor.color("#445566"))
        XCTAssertEqual(theme.acceptSelected.foreground, AppearanceColor.color("#778899"))
        XCTAssertEqual(theme.accent, AppearanceColor.color("#112233"))
    }

    func testAcceptAllFallsBackToTheNoticeBrandThenTheSDKBlue() {
        let classic = NoticeTheme(appearance: ResolvedNoticeAppearance(), primaryColor: "#aa0000", secondaryColor: nil, isPhone: true)
        XCTAssertEqual(classic.acceptAll.background, AppearanceColor.color("#aa0000"))
        XCTAssertEqual(classic.checkboxOn, AppearanceColor.color("#4f87ff"))
        XCTAssertEqual(classic.overlay, Color.black.opacity(0.5))
        XCTAssertEqual(classic.size(.title), 16)

        let bare = NoticeTheme(appearance: ResolvedNoticeAppearance(), primaryColor: "", secondaryColor: nil, isPhone: false)
        XCTAssertEqual(bare.acceptAll.background, AppearanceColor.color("#4f87ff"))
        XCTAssertEqual(bare.size(.title), 18)
    }

    func testTheBackdropOffLeavesThePageUndimmedAndGlassTakesItsOwnSizes() {
        let glass = NoticeTheme(
            appearance: ResolvedNoticeAppearance(style: .glass, backdrop: NoticeBackdrop.none),
            primaryColor: nil,
            secondaryColor: nil,
            isPhone: true
        )
        XCTAssertNil(glass.overlay)
        XCTAssertTrue(glass.isGlass)
        XCTAssertEqual(glass.size(.title), 19)
        XCTAssertEqual(glass.desktopWidth, 640)
        XCTAssertTrue(glass.layout.pairedFooter)
        XCTAssertTrue(glass.layout.collapsibleSections)
    }

    func testPlacementFollowsTheResolvedLayout() {
        let sheet = ResolvedNoticeAppearance(mobileLayout: .sheet).layout
        let phone = NoticePlacement.resolve(layout: sheet, isPhone: true, isGlass: false, containerWidth: 400, desktopWidth: 700)
        XCTAssertTrue(phone.docked)
        XCTAssertEqual(phone.alignment, .bottom)
        XCTAssertEqual(phone.maxHeightFraction, 0.92)

        let modal = NoticePlacement.resolve(layout: ResolvedNoticeAppearance().layout, isPhone: true, isGlass: false, containerWidth: 400, desktopWidth: 700)
        XCTAssertFalse(modal.docked)
        XCTAssertEqual(modal.width, 360)

        let corner = NoticePlacement.resolve(
            layout: ResolvedNoticeAppearance(desktopPosition: .bottomRight).layout,
            isPhone: false, isGlass: false, containerWidth: 1000, desktopWidth: 480
        )
        XCTAssertEqual(corner.alignment, .bottomTrailing)
        XCTAssertEqual(corner.width, 480)
        XCTAssertEqual(corner.edgeInset, 24)

        let bar = NoticePlacement.resolve(
            layout: ResolvedNoticeAppearance(desktopPosition: .bottomBar).layout,
            isPhone: false, isGlass: false, containerWidth: 1400, desktopWidth: 700
        )
        XCTAssertTrue(bar.docked)
        XCTAssertNil(bar.width)
        XCTAssertEqual(bar.contentMaxWidth, 1100)
    }

    func testTheLastServedAppearanceDrawsTheNextLoad() {
        let store = UserDefaults(suiteName: "notice-appearance-cache-test")!
        store.removePersistentDomain(forName: "notice-appearance-cache-test")
        let previous = NoticeAppearanceCache.store
        NoticeAppearanceCache.store = store
        defer { NoticeAppearanceCache.store = previous }

        NoticeAppearanceCache.write(noticeId: "n-1", appearance: NoticeAppearance(style: "glass"))
        XCTAssertEqual(NoticeAppearanceCache.read(noticeId: "n-1")?.style, "glass")
        let viewModel = ConsentNoticeViewModel(noticeId: "n-1", accessToken: "", refreshToken: "", baseUrl: "https://api.example.test/consent", onAccept: {}, onDecline: {})
        XCTAssertEqual(viewModel.servedAppearance?.style, "glass")

        NoticeAppearanceCache.write(noticeId: "n-1", appearance: NoticeAppearance())
        XCTAssertNil(NoticeAppearanceCache.read(noticeId: "n-1"))
    }

    // MARK: - Sections

    func testTalkbackHoldsTheSectionsOpenAndIgnoresToggles() {
        let notice = makeNotice()
        XCTAssertFalse(notice.vm.isSectionOpen(.about))
        notice.vm.toggleSection(.about)
        XCTAssertTrue(notice.vm.isSectionOpen(.about))

        notice.vm.isPlaying = true
        XCTAssertTrue(notice.vm.isSectionOpen(.dpo))
        notice.vm.toggleSection(.about)
        XCTAssertTrue(notice.vm.openSections.contains(.about))
    }

    // MARK: - Guardian

    func testTheGuardianFormNamesEveryMissingField() {
        let notice = makeNotice()
        notice.vm.handleGuardianFormNext()
        XCTAssertEqual(notice.vm.guardianFormErrors, [
            "guardianName": GuardianCopy.nameRequired,
            "guardianContact": GuardianCopy.contactRequired,
            "guardianRelationship": GuardianCopy.relationshipRequired,
        ])
    }

    func testAnsweringUnderEighteenAlwaysOpensTheGuardianForm() {
        let notice = makeNotice()
        notice.vm.showAgeVerification = true
        notice.vm.handleAgeVerificationNo()
        XCTAssertFalse(notice.vm.showAgeVerification)
        XCTAssertTrue(notice.vm.showGuardianForm)
    }

    private func fillGuardian(_ vm: ConsentNoticeViewModel) {
        vm.guardianFormData = .init(guardianName: "Asha", guardianContact: "9876543210", guardianRelationship: "Mother")
        vm.openURL = { _ in true }
        vm.pollIntervalNanos = 1_000_000
    }

    func testAVerifiedStatusTakesTheReferenceFromTheGuardianDetails() async {
        TransportStubProtocol.install { request in
            if request.path.hasSuffix("/guardian/initiate-verification") {
                return .json(200, ["session_token": "s-1", "digilocker_redirect_url": "https://digilocker.test/x"])
            }
            return .json(200, ["status": "verified", "guardian_details": ["verification_reference": "ref-9"]])
        }
        let notice = makeNotice()
        fillGuardian(notice.vm)
        await notice.vm.handleGuardianFormNext()?.value
        await waitUntil { notice.vm.isVerificationComplete }

        XCTAssertEqual(notice.vm.verificationReference, "ref-9")
        XCTAssertFalse(notice.vm.isPollingStatus)
    }

    func testAnAlreadyVerifiedGuardianWithoutAReferenceIsAnInvalidResponse() async {
        TransportStubProtocol.install { _ in .json(200, ["already_verified": true]) }
        let notice = makeNotice()
        fillGuardian(notice.vm)
        await notice.vm.handleGuardianFormNext()?.value

        XCTAssertEqual(notice.vm.guardianFormErrors["general"], GuardianCopy.invalidResponse)
        XCTAssertTrue(notice.vm.showGuardianForm)
        XCTAssertEqual(notice.errors.count, 1)
    }

    func testPollingGivesUpAfterThreeFailuresInARow() async {
        TransportStubProtocol.install { request in
            request.path.hasSuffix("/guardian/initiate-verification")
                ? .json(200, ["session_token": "s-1", "digilocker_redirect_url": "https://digilocker.test/x"])
                : .json(500, ["message": "Status down."])
        }
        let notice = makeNotice()
        fillGuardian(notice.vm)
        await notice.vm.handleGuardianFormNext()?.value
        await waitUntil { notice.vm.verificationError != nil }

        XCTAssertEqual(notice.vm.verificationError, "Status down.")
        XCTAssertNil(notice.vm.verificationErrorCode)
        XCTAssertTrue(notice.vm.canRetryVerification)
        XCTAssertEqual(TransportStubProtocol.requests(pathSuffix: "/guardian/verify-status").count, 3)
    }
}
