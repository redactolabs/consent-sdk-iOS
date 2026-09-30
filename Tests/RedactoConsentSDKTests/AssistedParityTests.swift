import XCTest
@testable import RedactoConsentSDK

@MainActor
final class FakeAudioPlayer: AssistedAudioPlaying {
    private(set) var played: [URL] = []
    private(set) var pauses = 0
    private(set) var resumes = 0
    private(set) var stops = 0
    private var onEnd: (@MainActor () -> Void)?

    func play(url: URL, onEnd: @escaping @MainActor () -> Void, onError: @escaping @MainActor () -> Void) {
        played.append(url)
        self.onEnd = onEnd
    }

    func pause() { pauses += 1 }
    func resume() { resumes += 1 }
    func stop() {
        stops += 1
        onEnd = nil
    }

    func finishClip() {
        let callback = onEnd
        onEnd = nil
        callback?()
    }
}

/// The assisted flow's static copy, narration and footer against React's
/// `RedactoNoticeAssisted` (i18n.ts, tsx ~800-1144, ~1699-1849).
final class AssistedParityTests: XCTestCase {
    private typealias F = InlineFixtures
    private let base = "https://api.example.test/consent"

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    // MARK: - Static copy

    func testTranslatesAndInterpolatesTheFlowCopy() {
        XCTAssertEqual(AssistedI18n(language: "English")(.resendIn, ["seconds": 12]), "Resend OTP in 12s")
        XCTAssertEqual(AssistedI18n(language: "en")(.enterNDigitOtp, ["count": 6]), "Enter 6-digit OTP")
        XCTAssertEqual(AssistedI18n(language: "Hindi").code, "hi")
        XCTAssertEqual(AssistedI18n(language: "Manipuri").code, "mni-Mtei")
        XCTAssertNotEqual(AssistedI18n(language: "Hindi")(.sendOtp), AssistedI18n(language: "English")(.sendOtp))
        XCTAssertTrue(AssistedI18n(language: "Tamil")(.selectAllFor, ["name": "Marketing"]).contains("Marketing"))
    }

    func testFallsBackToEnglishAndLeavesUnknownTokens() {
        XCTAssertEqual(AssistedI18n(language: "Klingon")(.close), "Close")
        XCTAssertEqual(AssistedI18n.interpolate("Hi {name}, {missing} {}", ["name": "A"]), "Hi A, {missing} {}")
    }

    func testCoversEveryKeyInEveryLanguage() {
        XCTAssertEqual(AssistedI18n.tables.count, 23)
        for (code, table) in AssistedI18n.tables {
            XCTAssertEqual(Set(table.keys), Set(AssistedStaticKey.allCases), code)
        }
    }

    // MARK: - Content translation

    func testTranslatesPurposesAndElementsButNeverProducts() {
        let hindi = InlineParityTests.translation(#"""
        {"purposes": {"p-1": "विपणन"}, "data_elements": {"e-1": "ईमेल"}, "products": {"prod-a": "उत्पाद"}, "notice_text": "सूचना"}
        """#)
        let config = F.config(products: nil, purposes: [], translations: ["Hindi": hindi])

        XCTAssertEqual(AssistedNotice.text(config, language: "Hindi", key: "purposes.name", fallback: "M", itemId: "p-1"), "विपणन")
        XCTAssertEqual(AssistedNotice.text(config, language: "Hindi", key: "purposes.description", fallback: "D", itemId: "p-1"), "D")
        XCTAssertEqual(AssistedNotice.text(config, language: "Hindi", key: "data_elements.name", fallback: "E", itemId: "e-1"), "ईमेल")
        XCTAssertEqual(AssistedNotice.text(config, language: "Hindi", key: "products.name", fallback: "Product A", itemId: "prod-a"), "Product A")
        XCTAssertEqual(AssistedNotice.text(config, language: "Hindi", key: "notice_text", fallback: "N"), "सूचना")
        XCTAssertEqual(AssistedNotice.text(config, language: "English", key: "notice_text", fallback: "N"), "N")
    }

    // MARK: - Footer

    func testLinksEachProductsPolicyInPlaceOfTheNoticePolicy() {
        var config = F.config(products: F.twoProducts, purposes: [])
        config.productPrivacyPolicies = [F.productA: "https://a.test/policy", F.productB: "https://b.test/policy"]
        let links = ProductPolicies.links(products: config.products, policies: config.productPrivacyPolicies)
        let footer = AssistedFooter.footerLines(config, policyLinks: links, translate: { _, fallback in fallback }, dpoText: { _, fallback in fallback })
        let notice = AssistedFooter.noticeLines(
            config,
            showsPolicyLink: ProductPolicies.showsNoticePolicyLink(products: config.products, links: links),
            translate: { _, fallback in fallback }
        )

        XCTAssertEqual(AssistedFooter.plainText(footer), "Privacy policies: Product A, Product B")
        XCTAssertEqual(footer[0].compactMap(\.link?.absoluteString), ["https://a.test/policy", "https://b.test/policy"])
        XCTAssertEqual(notice.count, 1, "every product names a policy, so the notice's own is not linked")
    }

    func testDrawsThePrivacyCenterAndDpoLinesAsReactDoes() throws {
        let dpo = try JSONDecoder().decode(DpoInfo.self, from: Data(#"""
        {"grievance_text": "Grievances:", "grievance_anchor_text": "", "grievance_url": "https://g.test",
         "grievance_email": "g@test.io", "dp_board_text": "Board:", "dp_board_anchor_text": "here", "dp_board_url": "",
         "dpo_text": "Officer:", "dpo_anchor_text": "", "dpo_email": "dpo@test.io"}
        """#.utf8))
        var config = F.config(products: nil, purposes: [])
        config = ActiveConfig(
            uuid: config.uuid, noticeUuid: config.noticeUuid, organisationUuid: config.organisationUuid,
            workspaceUuid: config.workspaceUuid, version: 1, status: "active", noticeText: "Notice",
            additionalText: "", acceptAllButtonText: nil, confirmButtonText: "Accept", declineButtonText: "Decline",
            logoUrl: "", privacyPolicyUrl: "", privacyCenterUrl: "https://pc.test", primaryColor: "#000000",
            secondaryColor: "#ffffff", fontPreference: "", purposes: [], defaultLanguage: "en",
            supportedLanguagesAndTranslations: [:], createdAt: "", updatedAt: "", deployedAt: "",
            privacyPolicyPrefixText: "Read", privacyPolicyAnchorText: "", privacyCenterAnchorText: nil,
            purposeSectionHeading: "", noticeBannerHeading: "", dpoInfo: dpo
        )
        let lines = AssistedFooter.footerLines(config, policyLinks: [], translate: { _, fallback in fallback }, dpoText: { _, fallback in fallback })

        XCTAssertEqual(AssistedFooter.plainText(lines), """
        Manage or withdraw consent anytime at Privacy Center.
        Grievances: click here or email to g@test.io
        Board: \("")
        Officer: Click here
        """)
        XCTAssertEqual(lines[3].last?.link?.absoluteString, "mailto:dpo@test.io")
        XCTAssertEqual(lines[1].last?.link?.absoluteString, "mailto:g@test.io")

        let notice = AssistedFooter.noticeLines(config, showsPolicyLink: true, translate: { _, fallback in fallback })
        XCTAssertEqual(AssistedFooter.plainText(notice), "Notice\nRead Privacy Policy")
        XCTAssertNil(notice[1].last?.link, "an unset policy URL still shows its anchor")
    }

    // MARK: - Narration

    private let audioJSON = #"""
    {"code": 200, "status": "success", "detail": {"uuid": "a-1", "language": "English",
      "notice_banner_heading_audio_url": "https://audio.test/title.mp3",
      "notice_text_audio_url": "https://audio.test/notice.mp3",
      "purposes_audio": {"p-account": {"name_audio_url": "https://audio.test/p.mp3", "description_audio_url": ""}},
      "data_elements_audio": {"e-email": {"name_audio_url": "https://audio.test/e.mp3"}},
      "confirm_button_text_audio_url": "https://audio.test/confirm.mp3",
      "accept_all_button_text_audio_url": "https://audio.test/all.mp3"}}
    """#

    private var singleProduct: ActiveConfig {
        F.config(products: nil, purposes: [
            F.purpose("p-account", nil, [F.element("e-email", required: true)]),
        ])
    }

    @MainActor
    private func loaded(_ player: FakeAudioPlayer, audio: [TransportStubResponse]? = nil) async -> AssistedNoticeViewModel {
        RouteStub.install([
            "get-notice": [F.noticeResponse(singleProduct)],
            "/audio/": audio ?? [.text(200, audioJSON)],
        ])
        let viewModel = AssistedNoticeViewModel(
            organisationUuid: "org-1",
            workspaceUuid: "ws-1",
            noticeUuid: "ntc-1",
            baseUrl: base,
            onComplete: {},
            onDecline: {},
            audioPlayer: player
        )
        await viewModel.load().value
        await viewModel.narrationTask?.value
        return viewModel
    }

    @MainActor
    func testFetchesTheNarrationPubliclyInTheNoticeLanguage() async {
        let viewModel = await loaded(FakeAudioPlayer())

        let request = RouteStub.requests(matching: "/audio/").first
        XCTAssertEqual(request?.url.absoluteString, "\(base)/public/organisations/org-1/workspaces/ws-1/notices/ntc-1/audio/English")
        XCTAssertNil(request?.header("Authorization"))
        XCTAssertTrue(viewModel.showsSpeaker)
        XCTAssertEqual(viewModel.narrationSequence.map(\.elementId), [
            "privacy-notice-title",
            "privacy-notice-text",
            "purpose-name-p-account",
            "data-element-p-account-e-email",
            "confirm-button-text",
        ])
    }

    @MainActor
    func testPlaysInOrderHighlightsAndExpandsThePurposeBeingRead() async {
        let player = FakeAudioPlayer()
        let viewModel = await loaded(player)
        XCTAssertEqual(viewModel.collapsedPurposes["p-account"], true)

        viewModel.toggleAudio()
        XCTAssertTrue(viewModel.isNarrating)
        XCTAssertTrue(viewModel.isHighlighted("privacy-notice-title"))

        player.finishClip()
        player.finishClip()
        XCTAssertTrue(viewModel.isHighlighted("purpose-name-p-account"))
        XCTAssertEqual(viewModel.collapsedPurposes["p-account"], false)

        viewModel.toggleAudio()
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.isPaused)
        XCTAssertFalse(viewModel.isHighlighted("purpose-name-p-account"))
        viewModel.toggleAudio()
        XCTAssertEqual(player.resumes, 1)
        XCTAssertTrue(viewModel.isNarrating)

        player.finishClip()
        player.finishClip()
        player.finishClip()
        XCTAssertEqual(player.played.map(\.lastPathComponent), ["title.mp3", "notice.mp3", "p.mp3", "e.mp3", "confirm.mp3"])
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertNil(viewModel.highlightedElementId)
    }

    @MainActor
    func testVerificationStopsTheNarrationAndHidesTheSpeaker() async {
        let viewModel = await loaded(FakeAudioPlayer())
        viewModel.toggleAudio()

        viewModel.acceptAll()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.showsSpeaker)
    }

    @MainActor
    func testRefetchesTheNarrationInTheNewLanguage() async {
        let viewModel = await loaded(FakeAudioPlayer(), audio: [.text(200, audioJSON), .text(200, audioJSON)])

        viewModel.selectLanguage("Hindi")
        XCTAssertFalse(viewModel.isTTSAvailable)
        await viewModel.narrationTask?.value

        XCTAssertEqual(RouteStub.requests(matching: "/audio/").last?.url.lastPathComponent, "Hindi")
        XCTAssertTrue(viewModel.isTTSAvailable)
    }

    @MainActor
    func testAMissingNarrationOnlyHidesTheSpeaker() async {
        let viewModel = await loaded(FakeAudioPlayer(), audio: [.text(404, "{}")])

        XCTAssertFalse(viewModel.showsSpeaker)
        XCTAssertNotNil(viewModel.activeConfig)
        XCTAssertNil(viewModel.fetchErrorMessage)
    }
}
