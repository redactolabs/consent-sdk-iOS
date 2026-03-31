import XCTest
@testable import RedactoConsentSDK

final class TTSAudioTests: XCTestCase {
    func testTTSAudioResponseDecodesWhenOptionalUrlsAreMissing() throws {
        let json = """
        {
          "code": 200,
          "status": "success",
          "detail": {
            "uuid": "audio-uuid",
            "language": "English",
            "purposes_audio": {},
            "data_elements_audio": {}
          }
        }
        """

        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TTSAudioUrlsResponse.self, from: data)

        XCTAssertEqual(decoded.code, 200)
        XCTAssertEqual(decoded.detail.uuid, "audio-uuid")
        XCTAssertNil(decoded.detail.noticeTextAudioUrl)
        XCTAssertNil(decoded.detail.confirmButtonTextAudioUrl)
        XCTAssertNil(decoded.detail.privacyPolicyAnchorTextAudioUrl)
    }

    func testBuildQueueIncludesAllSegmentsInReactOrder() {
        let purpose = ActiveConfigPurpose(
            uuid: "purpose-1",
            name: "Analytics",
            description: "Analytics purpose",
            industries: nil,
            dataElements: [
                ActiveConfigDataElement(
                    uuid: "de-1",
                    name: "Email",
                    description: nil,
                    industries: nil,
                    enabled: true,
                    required: false
                ),
            ]
        )

        let urls: [String: String] = [
            "notice_banner_heading": "u1",
            "notice_text": "u2",
            "privacy_policy_prefix_text": "u3",
            "privacy_policy_anchor_text": "u4",
            "purpose_section_heading": "u5",
            "purpose_name_purpose-1": "u6",
            "purpose_desc_purpose-1": "u7",
            "element_de-1": "u8",
            "additional_text": "u9",
            "privacy_center_anchor_text": "u10",
            "dpo_grievance_text": "u11",
            "dpo_grievance_anchor_text": "u12",
            "dpo_grievance_email_connector_text": "u13",
            "dpo_grievance_email": "u14",
            "dpo_dp_board_text": "u15",
            "dpo_dp_board_anchor_text": "u16",
            "dpo_dpo_text": "u17",
            "dpo_dpo_anchor_text": "u18",
            "confirm_button_text": "u19",
            "decline_button_text": "u20",
        ]

        let queue = TTSQueueBuilder.buildQueue(
            urls: urls,
            purposes: [purpose],
            hasAdditionalText: true,
            hasPrivacyCenterUrl: true,
            hasDpoInfo: true
        )

        XCTAssertEqual(
            queue,
            [
                TTSQueueItem(segmentKey: "notice_banner_heading", url: "u1"),
                TTSQueueItem(segmentKey: "notice_text", url: "u2"),
                TTSQueueItem(segmentKey: "privacy_policy_prefix_text", url: "u3"),
                TTSQueueItem(segmentKey: "privacy_policy_anchor_text", url: "u4"),
                TTSQueueItem(segmentKey: "purpose_section_heading", url: "u5"),
                TTSQueueItem(segmentKey: "purpose_name_purpose-1", url: "u6"),
                TTSQueueItem(segmentKey: "purpose_desc_purpose-1", url: "u7"),
                TTSQueueItem(segmentKey: "element_de-1", url: "u8"),
                TTSQueueItem(segmentKey: "additional_text", url: "u9"),
                TTSQueueItem(segmentKey: "privacy_center_anchor_text", url: "u10"),
                TTSQueueItem(segmentKey: "dpo_grievance_text", url: "u11"),
                TTSQueueItem(segmentKey: "dpo_grievance_anchor_text", url: "u12"),
                TTSQueueItem(segmentKey: "dpo_grievance_email_connector_text", url: "u13"),
                TTSQueueItem(segmentKey: "dpo_grievance_email", url: "u14"),
                TTSQueueItem(segmentKey: "dpo_dp_board_text", url: "u15"),
                TTSQueueItem(segmentKey: "dpo_dp_board_anchor_text", url: "u16"),
                TTSQueueItem(segmentKey: "dpo_dpo_text", url: "u17"),
                TTSQueueItem(segmentKey: "dpo_dpo_anchor_text", url: "u18"),
                TTSQueueItem(segmentKey: "confirm_button_text", url: "u19"),
                TTSQueueItem(segmentKey: "decline_button_text", url: "u20"),
            ]
        )
    }

    func testBuildQueueSkipsConditionalSegmentsWithoutContentFlags() {
        let queue = TTSQueueBuilder.buildQueue(
            urls: [
                "notice_banner_heading": "u1",
                "notice_text": "u2",
                "additional_text": "u3",
                "privacy_center_anchor_text": "u4",
                "dpo_grievance_text": "u5",
                "confirm_button_text": "u6",
            ],
            purposes: [],
            hasAdditionalText: false,
            hasPrivacyCenterUrl: false,
            hasDpoInfo: false
        )

        XCTAssertEqual(
            queue,
            [
                TTSQueueItem(segmentKey: "notice_banner_heading", url: "u1"),
                TTSQueueItem(segmentKey: "notice_text", url: "u2"),
                TTSQueueItem(segmentKey: "confirm_button_text", url: "u6"),
            ]
        )
    }

    func testBuildQueueSkipsEmptyAndWhitespaceUrls() {
        let queue = TTSQueueBuilder.buildQueue(
            urls: [
                "notice_banner_heading": "",
                "notice_text": "   ",
                "confirm_button_text": "u1",
            ],
            purposes: [],
            hasAdditionalText: false,
            hasPrivacyCenterUrl: false,
            hasDpoInfo: false
        )

        XCTAssertEqual(queue, [TTSQueueItem(segmentKey: "confirm_button_text", url: "u1")])
    }

    @MainActor
    func testActiveSegmentTransitionsStartPauseResumeStop() {
        let vm = ConsentNoticeViewModel(
            noticeId: "notice-1",
            accessToken: "token",
            refreshToken: "refresh",
            onAccept: {},
            onDecline: {}
        )
        vm.content = makeMockConsentContent()
        vm.ttsAudioUrls = [
            "notice_banner_heading": "https://example.com/notice_banner.mp3",
            "notice_text": "https://example.com/notice_text.mp3",
        ]

        // Start
        vm.toggleAudio()
        XCTAssertEqual(vm.activeTTSSegmentKey, "notice_banner_heading")
        XCTAssertTrue(vm.isPlaying)
        XCTAssertFalse(vm.isPaused)

        // Pause
        vm.toggleAudio()
        XCTAssertNil(vm.activeTTSSegmentKey)
        XCTAssertTrue(vm.isPaused)

        // Resume should restore current segment key
        vm.toggleAudio()
        XCTAssertEqual(vm.activeTTSSegmentKey, "notice_banner_heading")
        XCTAssertFalse(vm.isPaused)

        // Stop clears highlight
        vm.stopAudio()
        XCTAssertNil(vm.activeTTSSegmentKey)
        XCTAssertFalse(vm.isPlaying)
    }

    private func makeMockConsentContent() -> ConsentContent {
        ConsentContent(
            code: 200,
            status: "success",
            detail: ConsentDetail(
                uuid: "consent-1",
                name: "Consent",
                organisationUuid: "org-1",
                workspaceUuid: "ws-1",
                collectionPointUuids: [],
                collectionPoints: [],
                activeConfig: ActiveConfig(
                    uuid: "cfg-1",
                    noticeUuid: "notice-1",
                    organisationUuid: "org-1",
                    workspaceUuid: "ws-1",
                    version: 1,
                    status: "active",
                    noticeText: "Notice",
                    additionalText: "",
                    confirmButtonText: "Accept",
                    declineButtonText: "Decline",
                    logoUrl: "",
                    privacyPolicyUrl: "",
                    privacyCenterUrl: "",
                    primaryColor: "#000000",
                    secondaryColor: "#ffffff",
                    fontPreference: "default",
                    purposes: [],
                    defaultLanguage: "en",
                    supportedLanguagesAndTranslations: [:],
                    createdAt: "2024-01-01T00:00:00.000Z",
                    updatedAt: "2024-01-01T00:00:00.000Z",
                    deployedAt: "2024-01-01T00:00:00.000Z",
                    privacyPolicyPrefixText: "Read",
                    privacyPolicyAnchorText: "Policy",
                    privacyCenterAnchorText: nil,
                    purposeSectionHeading: "Purposes",
                    noticeBannerHeading: "Privacy Notice",
                    dpoInfo: nil
                ),
                noticeType: nil,
                complianceRequirement: nil,
                isMinor: false,
                purposeSelections: nil,
                reconsentRequired: false,
                createdAt: "2024-01-01T00:00:00.000Z",
                updatedAt: "2024-01-01T00:00:00.000Z"
            )
        )
    }
}
