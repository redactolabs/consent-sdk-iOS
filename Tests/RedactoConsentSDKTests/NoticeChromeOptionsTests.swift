import SwiftUI
import XCTest
@testable import RedactoConsentSDK

/// The chrome switches the console serves on `active_config.appearance`, ported
/// from the React SDK's RedactoNoticeConsent.appearance.test.tsx.
///
/// Every one of them is absent-means-today, so each case is paired with the
/// negative control: nothing served, and the flag served as `true`, must read
/// the same as the notices published before the field existed.
@MainActor
final class NoticeChromeOptionsTests: XCTestCase {
    typealias N = NoticeProductFixtures

    private let orders = N.requiredPurpose("purpose-orders", "Order Fulfilment", [])

    /// Reads the switches back off a notice the real decoder parsed, so a key
    /// that never reaches `NoticeAppearance` fails here.
    private func options(_ appearance: [String: Any]?) throws -> NoticeChromeOptions {
        var config: [String: Any] = [:]
        if let appearance { config["appearance"] = appearance }
        let viewModel = N.viewModel(try N.notice(products: nil, purposes: [orders], config: config))
        return viewModel.chromeOptions
    }

    private func unset() throws -> NoticeChromeOptions {
        try options(nil)
    }

    // MARK: - Nothing served

    func testANoticeThatServesNoAppearanceDrawsEveryPieceOfChrome() throws {
        let absent = try unset()
        XCTAssertTrue(absent.showsProductSection)
        XCTAssertTrue(absent.showsDataElements)
        XCTAssertTrue(absent.showsDataElementControls)
        XCTAssertEqual(absent.descriptionPlacement, .always)
        XCTAssertTrue(absent.showsPurposeSectionHeading)
        XCTAssertEqual(absent.controlPosition, .right)
        XCTAssertEqual(absent.headerAlign, .left)
        XCTAssertTrue(absent.showsTitle)
        XCTAssertTrue(absent.showsAudioButton)
        XCTAssertTrue(absent.showsLogo)
        XCTAssertFalse(absent.leadsWithControl)
        XCTAssertFalse(absent.centresHeader)
        XCTAssertFalse(absent.inlinesPolicyLink)
        XCTAssertFalse(absent.privacyCenterAsText)
        XCTAssertTrue(absent.showsRequiredHint)
    }

    func testAnEmptyAppearanceReadsTheSameAsNoneAtAll() throws {
        XCTAssertEqual(try options([:]), try unset())
    }

    func testAnAppearanceCarryingOnlyOlderKeysReadsTheSameAsNoneAtAll() throws {
        let served = try options([
            "style": "glass",
            "selection_control": "radio",
            "collapsible_sections": true,
            "max_width": 480,
        ])
        XCTAssertEqual(served, try unset())
    }

    // MARK: - The purpose chrome switches

    func testTheProductSectionDataElementsDescriptionAndHeadingAreAllDrawnWhenAskedForExplicitly() throws {
        let served = try options([
            "show_product_section": true,
            "show_data_elements": true,
            "show_data_element_controls": true,
            "purpose_description": "always",
            "show_purpose_section_heading": true,
        ])
        XCTAssertEqual(served, try unset())
    }

    func testHidingTheProductSectionLeavesEveryOtherSwitchAlone() throws {
        let served = try options(["show_product_section": false])
        XCTAssertFalse(served.showsProductSection)
        XCTAssertTrue(served.showsDataElements)
        XCTAssertTrue(served.showsPurposeSectionHeading)
        XCTAssertEqual(served.descriptionPlacement, .always)
    }

    func testHidingTheDataElementsLeavesTheDescriptionOnTheRow() throws {
        let served = try options(["show_data_elements": false])
        XCTAssertFalse(served.showsDataElements)
        XCTAssertEqual(served.descriptionPlacement, .always)
    }

    func testTakingTheTicksOffTheDataElementsStillListsThem() throws {
        let served = try options(["show_data_element_controls": false])
        XCTAssertFalse(served.showsDataElementControls)
        XCTAssertTrue(served.showsDataElements)
    }

    func testAnUnknownShowDataElementControlsValueKeepsTheTicks() throws {
        XCTAssertTrue(try options(["show_data_element_controls": "false"]).showsDataElementControls)
        XCTAssertTrue(try options(["show_data_element_controls": 0]).showsDataElementControls)
    }

    func testTheDescriptionCanGoBehindTheChevronOrAwayAltogether() throws {
        XCTAssertEqual(try options(["purpose_description": "expanded"]).descriptionPlacement, .expanded)
        XCTAssertEqual(try options(["purpose_description": "hidden"]).descriptionPlacement, .hidden)
    }

    func testAnUnknownDescriptionPlacementKeepsTheDescriptionOnTheRow() throws {
        XCTAssertEqual(try options(["purpose_description": "sidebar"]).descriptionPlacement, .always)
        XCTAssertEqual(try options(["purpose_description": true]).descriptionPlacement, .always)
    }

    func testHidingThePurposeSectionHeadingLeavesThePurposesAlone() throws {
        let served = try options(["show_purpose_section_heading": false])
        XCTAssertFalse(served.showsPurposeSectionHeading)
        XCTAssertTrue(served.showsDataElements)
        XCTAssertTrue(served.showsProductSection)
    }

    // MARK: - Where the row chrome sits

    func testTheTickStaysOnTheTrailingEdgeWhenNoPositionIsServed() throws {
        XCTAssertEqual(try unset().controlPosition, .right)
        XCTAssertEqual(try options(["control_position": "right"]).controlPosition, .right)
    }

    func testTheTickMovesToTheLeadingEdgeWhenAskedTo() throws {
        let served = try options(["control_position": "left"])
        XCTAssertEqual(served.controlPosition, .left)
        XCTAssertTrue(served.leadsWithControl)
    }

    func testAnUnknownControlPositionIsTheTrailingEdge() throws {
        XCTAssertEqual(try options(["control_position": "middle"]).controlPosition, .right)
        XCTAssertEqual(try options(["control_position": 1]).controlPosition, .right)
    }

    // MARK: - The notice's prose alignment

    func testTheTitleAndNoticeTextAreRangedLeftWhenNoAlignmentIsServed() throws {
        XCTAssertEqual(try unset().headerAlign, .left)
        XCTAssertEqual(try options(["header_align": "left"]).headerAlign, .left)
    }

    func testCentringTheHeaderTakesTheControlsOffTheTitlesRow() throws {
        let served = try options(["header_align": "center"])
        XCTAssertEqual(served.headerAlign, .center)
        XCTAssertTrue(served.centresHeader)
    }

    func testAnUnknownAlignmentIsRangedLeft() throws {
        XCTAssertFalse(try options(["header_align": "centre"]).centresHeader)
        XCTAssertFalse(try options(["header_align": "justify"]).centresHeader)
    }

    // MARK: - The title, the audio button and the logo

    func testTheTitleTheAudioButtonAndTheLogoAreAllDrawnWhenAskedForExplicitly() throws {
        let served = try options(["show_title": true, "show_audio_button": true, "show_logo": true])
        XCTAssertEqual(served, try unset())
    }

    func testHidingTheTitleLeavesTheAudioButtonAndTheLogoAlone() throws {
        let served = try options(["show_title": false])
        XCTAssertFalse(served.showsTitle)
        XCTAssertTrue(served.showsAudioButton)
        XCTAssertTrue(served.showsLogo)
    }

    func testHidingTheAudioButtonLeavesTheLanguageControlAndTheTitleAlone() throws {
        let served = try options(["show_audio_button": false])
        XCTAssertFalse(served.showsAudioButton)
        XCTAssertTrue(served.showsTitle)
    }

    func testHidingTheLogoKeepsTheTitle() throws {
        let served = try options(["show_logo": false])
        XCTAssertFalse(served.showsLogo)
        XCTAssertTrue(served.showsTitle)
    }

    /// The masthead padding goes only when the header has nothing left to
    /// space out. A native notice draws no bundled mark, so a notice with no
    /// `logo_url` has no masthead either.
    func testTheMastheadPaddingGoesOnlyWhenNothingButTheControlsIsLeft() throws {
        let absent = try unset()
        XCTAssertFalse(absent.headerHoldsOnlyControls(hasLogo: true))
        XCTAssertFalse(absent.headerHoldsOnlyControls(hasLogo: false))

        let noTitle = try options(["show_title": false])
        XCTAssertFalse(noTitle.headerHoldsOnlyControls(hasLogo: true))
        XCTAssertTrue(noTitle.headerHoldsOnlyControls(hasLogo: false))

        let noLogo = try options(["show_logo": false])
        XCTAssertFalse(noLogo.headerHoldsOnlyControls(hasLogo: true))
        XCTAssertFalse(noLogo.headerHoldsOnlyControls(hasLogo: false))

        let neither = try options(["show_title": false, "show_logo": false])
        XCTAssertTrue(neither.headerHoldsOnlyControls(hasLogo: true))
        XCTAssertTrue(neither.headerHoldsOnlyControls(hasLogo: false))
    }

    // MARK: - The privacy policy line

    func testThePrivacyPolicyLineStartsUnderTheNoticeTextUntilAskedToRunOn() throws {
        XCTAssertFalse(try unset().inlinesPolicyLink)
        XCTAssertFalse(try options(["privacy_policy_inline": false]).inlinesPolicyLink)
        XCTAssertTrue(try options(["privacy_policy_inline": true]).inlinesPolicyLink)
    }

    func testAnUnknownPrivacyPolicyInlineValueKeepsTheLineUnderTheNoticeText() throws {
        XCTAssertFalse(try options(["privacy_policy_inline": "true"]).inlinesPolicyLink)
        XCTAssertFalse(try options(["privacy_policy_inline": 1]).inlinesPolicyLink)
    }

    // MARK: - The privacy center entry

    func testThePrivacyCenterStaysALinkUntilAskedForText() throws {
        XCTAssertFalse(try unset().privacyCenterAsText)
        XCTAssertFalse(try options(["privacy_center_as_text": false]).privacyCenterAsText)
        XCTAssertTrue(try options(["privacy_center_as_text": true]).privacyCenterAsText)
    }

    func testAnUnknownPrivacyCenterAsTextValueKeepsTheLink() throws {
        XCTAssertFalse(try options(["privacy_center_as_text": "true"]).privacyCenterAsText)
        XCTAssertFalse(try options(["privacy_center_as_text": 1]).privacyCenterAsText)
    }

    private func privacyCenterNotice(_ config: [String: Any]) throws -> ConsentNoticeViewModel {
        N.viewModel(try N.notice(products: nil, purposes: [orders], config: config))
    }

    func testAPrivacyCenterLinkShowsOnlyWithAUrl() throws {
        let linked = try privacyCenterNotice(["privacy_center_url": "https://pc.test"])
        XCTAssertTrue(try XCTUnwrap(linked.activeConfig).showsPrivacyCenterEntry)
        XCTAssertTrue(linked.hasPrivacyCenterLine)

        let unlinked = try privacyCenterNotice(["privacy_center_anchor_text": "Account Centre > Privacy Centre"])
        XCTAssertFalse(try XCTUnwrap(unlinked.activeConfig).showsPrivacyCenterEntry)
        XCTAssertFalse(unlinked.hasPrivacyCenterLine)
    }

    func testPrivacyCenterTextShowsWithoutAUrlButNotWhenBlank() throws {
        let asText = try privacyCenterNotice([
            "privacy_center_anchor_text": "Account Centre > Privacy Centre",
            "appearance": ["privacy_center_as_text": true],
        ])
        XCTAssertTrue(try XCTUnwrap(asText.activeConfig).showsPrivacyCenterEntry)
        XCTAssertTrue(asText.hasPrivacyCenterLine)

        let blank = try privacyCenterNotice([
            "privacy_center_url": "https://pc.test",
            "privacy_center_anchor_text": "  ",
            "appearance": ["privacy_center_as_text": true],
        ])
        XCTAssertFalse(try XCTUnwrap(blank.activeConfig).showsPrivacyCenterEntry)
        XCTAssertFalse(blank.hasPrivacyCenterLine)
    }

    // MARK: - The required-purposes hint

    func testTheRequiredHintIsDrawnUntilTurnedOff() throws {
        XCTAssertTrue(try unset().showsRequiredHint)
        XCTAssertTrue(try options(["show_required_hint": true]).showsRequiredHint)
        XCTAssertFalse(try options(["show_required_hint": false]).showsRequiredHint)
    }

    func testAnUnknownShowRequiredHintValueKeepsTheHint() throws {
        XCTAssertTrue(try options(["show_required_hint": "false"]).showsRequiredHint)
        XCTAssertTrue(try options(["show_required_hint": 0]).showsRequiredHint)
    }

    // MARK: - The data elements listed with no tick

    private typealias Background = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute
    private typealias Foreground = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute

    private static let listed = [
        ActiveConfigDataElement(uuid: "de-email", name: "Email", description: nil, industries: nil, enabled: true, required: true),
        ActiveConfigDataElement(uuid: "de-phone", name: "Phone Number", description: nil, industries: nil, enabled: true, required: false),
        ActiveConfigDataElement(uuid: "de-old", name: "Old ID", description: nil, industries: nil, enabled: false, required: true),
    ]

    private func listedLine(highlighting uuid: String? = nil, highlightText: Color? = nil) -> AttributedString {
        DataElementList.line(
            Self.listed,
            name: \.name,
            isHighlighted: { $0.uuid == uuid },
            highlightBackground: .yellow,
            highlightText: highlightText
        )
    }

    private func text(of line: AttributedString, where matches: (AttributedString.Runs.Run) -> Bool) -> String {
        line.runs.filter(matches).map { String(line[$0.range].characters) }.joined()
    }

    /// Only a live mandatory element is marked, as on its row.
    func testTheDataElementsListedWithNoTickReadAsOneCommaSeparatedLine() {
        let line = listedLine()
        XCTAssertEqual(String(line.characters), "Email *, Phone Number, Old ID")
        XCTAssertEqual(text(of: line) { $0[Foreground.self] == .red }, " *")
        XCTAssertEqual(text(of: line) { $0[Background.self] != nil }, "")
    }

    func testTheLineHighlightsOnlyTheDataElementTalkbackIsReading() {
        let email = listedLine(highlighting: "de-email", highlightText: .black)
        XCTAssertEqual(text(of: email) { $0[Background.self] == .yellow }, "Email *")
        XCTAssertEqual(text(of: email) { $0[Foreground.self] == .black }, "Email")
        XCTAssertEqual(text(of: email) { $0[Foreground.self] == .red }, " *")

        let phone = listedLine(highlighting: "de-phone")
        XCTAssertEqual(text(of: phone) { $0[Background.self] == .yellow }, "Phone Number")
        XCTAssertEqual(text(of: phone) { $0[Foreground.self] != nil && $0[Foreground.self] != .red }, "")
    }

    func testVoiceOverReadsTheListedNamesWithTheMandatoryOnesSaidSo() {
        XCTAssertEqual(
            DataElementList.accessibilityLabel(Self.listed, name: \.name),
            "Email (required), Phone Number, Old ID"
        )
    }

    // MARK: - The resolver stays out of it

    /// These keys are read off the served appearance, never through the
    /// resolver: `docs/appearance-fixtures.json` pins the resolver's output for
    /// all six SDKs and holds none of them.
    func testNoneOfTheChromeSwitchesReachTheResolvedAppearance() throws {
        let appearance = NoticeAppearance(
            collapsibleSections: true,
            showProductSection: false,
            showDataElements: false,
            showDataElementControls: false,
            purposeDescription: "hidden",
            showPurposeSectionHeading: false,
            controlPosition: "left",
            headerAlign: "center",
            showTitle: false,
            showAudioButton: false,
            showLogo: false,
            privacyPolicyInline: true,
            privacyCenterAsText: true,
            showRequiredHint: false
        )
        XCTAssertEqual(
            NoticeAppearanceResolver.resolve(appearance),
            NoticeAppearanceResolver.resolve(NoticeAppearance(collapsibleSections: true))
        )
    }

    // MARK: - Talkback

    private static let talkbackUrls = [
        "notice_banner_heading": "u1",
        "purpose_section_heading": "u2",
        "purpose_name_purpose-1": "u3",
        "purpose_desc_purpose-1": "u4",
        "element_de-1": "u5",
    ]

    private static let talkbackPurpose = ActiveConfigPurpose(
        uuid: "purpose-1",
        name: "Marketing",
        description: "Send offers",
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

    private func talkbackKeys(_ appearance: NoticeAppearance?) -> [String] {
        TTSQueueBuilder.buildQueue(
            urls: Self.talkbackUrls,
            purposes: [Self.talkbackPurpose],
            hasAdditionalText: false,
            hasPrivacyCenterEntry: false,
            hasDpoInfo: false,
            options: NoticeChromeOptions(served: appearance)
        ).map(\.segmentKey)
    }

    func testTalkbackReadsEverySegmentWhenNoChromeIsHidden() {
        let everything = [
            "notice_banner_heading",
            "purpose_section_heading",
            "purpose_name_purpose-1",
            "purpose_desc_purpose-1",
            "element_de-1",
        ]
        XCTAssertEqual(talkbackKeys(nil), everything)
        XCTAssertEqual(talkbackKeys(NoticeAppearance()), everything)
        XCTAssertEqual(
            talkbackKeys(NoticeAppearance(
                showDataElements: true,
                showDataElementControls: true,
                purposeDescription: "always",
                showPurposeSectionHeading: true
            )),
            everything
        )
    }

    func testTalkbackSkipsAHeadingTheNoticeNeverDraws() {
        XCTAssertEqual(
            talkbackKeys(NoticeAppearance(showPurposeSectionHeading: false)),
            ["notice_banner_heading", "purpose_name_purpose-1", "purpose_desc_purpose-1", "element_de-1"]
        )
    }

    func testTalkbackSkipsDataElementsTheNoticeNeverDraws() {
        XCTAssertEqual(
            talkbackKeys(NoticeAppearance(showDataElements: false)),
            ["notice_banner_heading", "purpose_section_heading", "purpose_name_purpose-1", "purpose_desc_purpose-1"]
        )
    }

    /// Listed with no tick, a data element is still on the notice.
    func testTalkbackStillReadsDataElementsListedWithNoTick() {
        XCTAssertEqual(talkbackKeys(NoticeAppearance(showDataElementControls: false)), talkbackKeys(nil))
    }

    func testTalkbackSkipsADescriptionTheNoticeHidesButKeepsOneBehindTheChevron() {
        XCTAssertEqual(
            talkbackKeys(NoticeAppearance(purposeDescription: "hidden")),
            ["notice_banner_heading", "purpose_section_heading", "purpose_name_purpose-1", "element_de-1"]
        )
        XCTAssertTrue(
            talkbackKeys(NoticeAppearance(purposeDescription: "expanded"))
                .contains("purpose_desc_purpose-1")
        )
    }

    /// A hidden title is taken out of sight, not out of the notice: talkback
    /// still reads it, and the card still borrows it to name the dialog.
    func testTalkbackStillReadsATitleTakenOutOfSight() {
        XCTAssertEqual(talkbackKeys(NoticeAppearance(showTitle: false)).first, "notice_banner_heading")
    }
}
