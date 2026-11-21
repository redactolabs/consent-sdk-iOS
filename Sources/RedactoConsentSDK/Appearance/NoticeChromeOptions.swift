import Foundation

/// The notice-chrome choices, read straight off `active_config.appearance`.
///
/// They deliberately stay off `ResolvedNoticeAppearance`: the resolver's output
/// is pinned by `docs/appearance-fixtures.json`, the vectors every notice SDK
/// shares, and none of these keys appear there. Each one is absent-means-today,
/// so a flag is read as "anything but an explicit false" and a notice published
/// before the field existed draws exactly as it did.
struct NoticeChromeOptions: Equatable {
    let showsProductSection: Bool
    let showsDataElements: Bool
    /// Each data element answers on its own tick. Off, they are listed with no
    /// tick, and a purpose's tick grants every one of them: see
    /// `ProductConsent.tickGrant`.
    let showsDataElementControls: Bool
    let descriptionPlacement: PurposeDescriptionPlacement
    let showsPurposeSectionHeading: Bool
    let controlPosition: NoticeControlPosition
    let headerAlign: NoticeHeaderAlign
    let showsTitle: Bool
    let showsAudioButton: Bool
    let showsLogo: Bool
    /// The privacy policy line runs on from the notice text instead of under it.
    let inlinesPolicyLink: Bool
    let privacyCenterAsText: Bool
    /// Draws the hint naming required purposes still owed. Off, the button's
    /// accessibility hint still carries it.
    let showsRequiredHint: Bool

    init(served: NoticeAppearance?) {
        showsProductSection = served?.showProductSection != false
        showsDataElements = served?.showDataElements != false
        showsDataElementControls = served?.showDataElementControls != false
        descriptionPlacement = served?.purposeDescription
            .flatMap(PurposeDescriptionPlacement.init(rawValue:)) ?? .always
        showsPurposeSectionHeading = served?.showPurposeSectionHeading != false
        controlPosition = served?.controlPosition == NoticeControlPosition.left.rawValue ? .left : .right
        headerAlign = served?.headerAlign == NoticeHeaderAlign.center.rawValue ? .center : .left
        showsTitle = served?.showTitle != false
        showsAudioButton = served?.showAudioButton != false
        showsLogo = served?.showLogo != false
        inlinesPolicyLink = served?.privacyPolicyInline == true
        privacyCenterAsText = served?.privacyCenterAsText == true
        showsRequiredHint = served?.showRequiredHint != false
    }

    var leadsWithControl: Bool { controlPosition == .left }

    var centresHeader: Bool { headerAlign == .center }

    /// With nothing but the controls left in the header, the padding sized for
    /// a masthead reads as dead space above the notice text. Unlike the web,
    /// a native notice draws no bundled mark, so a notice without a `logo_url`
    /// has no masthead either.
    func headerHoldsOnlyControls(hasLogo: Bool) -> Bool {
        !showsTitle && !(showsLogo && hasLogo)
    }
}

extension ActiveConfig {
    var privacyCenterAsText: Bool {
        NoticeChromeOptions(served: appearance).privacyCenterAsText
    }

    var showsPrivacyCenterEntry: Bool {
        privacyCenterAsText
            ? !(privacyCenterAnchorText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !privacyCenterUrl.isEmpty
    }
}
