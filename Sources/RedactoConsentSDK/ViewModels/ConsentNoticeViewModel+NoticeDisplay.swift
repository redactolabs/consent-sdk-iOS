import SwiftUI

extension ConsentNoticeViewModel {
    /// The appearance served with the notice, or before it arrives the last
    /// one served for it; a notice that serves none is classic.
    var servedAppearance: NoticeAppearance? {
        content != nil ? activeConfig?.appearance : cachedAppearance
    }

    /// The console appearance under the host's settings. Colours follow the
    /// colour scheme, which the view resolves with; the choices read here do not.
    func appearance(colorScheme: ColorScheme = .light) -> ResolvedNoticeAppearance {
        NoticeAppearance.resolve(console: servedAppearance, settings: settings, colorScheme: colorScheme)
    }

    /// Host override, then the console, then checkboxes.
    var selectionControl: SelectionControlType {
        appearance().effectiveSelectionControl
    }

    /// Host override, then the console.
    var confirmBeforeSubmit: Bool {
        appearance().confirmBeforeSubmit
    }

    var logoPosition: LogoPosition {
        NoticeLayout.resolveLogoPosition(activeConfig?.logoPosition)
    }

    var noticeFontFamily: String? {
        NoticeFontResolver.resolve(
            hostFont: settings?.font,
            noticeFont: activeConfig?.fontPreference,
            installed: NoticeFontResolver.installedFamily
        )
    }

    var productPolicyLinks: [ProductPolicyLink] {
        ProductPolicies.links(
            products: activeConfig?.products,
            policies: activeConfig?.productPrivacyPolicies
        )
    }

    var showsNoticePolicyLink: Bool {
        ProductPolicies.showsNoticePolicyLink(products: activeConfig?.products, links: productPolicyLinks)
    }

    /// The admin's additional text shows with or without a privacy-center
    /// link; the link follows it only when the notice has one.
    var hasPrivacyCenterLine: Bool {
        guard let activeConfig else { return false }
        return !activeConfig.privacyCenterUrl.isEmpty || !activeConfig.additionalText.isEmpty
    }

    var showsNoticeFooter: Bool {
        guard let activeConfig else { return false }
        return hasPrivacyCenterLine
            || !productPolicyLinks.isEmpty
            || activeConfig.dpoInfo != nil
    }

    /// Section titles: the SDK's labels for the language, else the notice's
    /// own copy, English only as the last resort.
    func sectionTitle(_ section: NoticeSection) -> (title: String, hint: String?, clamped: Bool) {
        let label = NoticeSectionCopy.labels(for: selectedLanguage)
        let preview = sectionPreview(section)
        if let label {
            let title = section == .about ? label.about : label.dpo
            return (title, preview.isEmpty ? nil : preview, false)
        }
        let fallback = sectionFallbackTitle(section)
        let english = section == .about ? NoticeSectionCopy.english.about : NoticeSectionCopy.english.dpo
        let title = !preview.isEmpty ? preview : (!fallback.isEmpty ? fallback : english)
        return (title, nil, true)
    }

    private func sectionPreview(_ section: NoticeSection) -> String {
        guard let ac = activeConfig else { return "" }
        switch section {
        case .about:
            return getTranslatedText("notice_text", defaultText: ac.noticeText)
        case .dpo:
            if let dpo = ac.dpoInfo {
                return getTranslatedDpoText("grievance_text", defaultText: dpo.grievanceText)
            }
            return ac.additionalText.isEmpty ? "" : getTranslatedText("additional_text", defaultText: ac.additionalText)
        }
    }

    private func sectionFallbackTitle(_ section: NoticeSection) -> String {
        guard let ac = activeConfig else { return "" }
        switch section {
        case .about:
            return ac.privacyPolicyAnchorText.isEmpty
                ? ""
                : getTranslatedText("privacy_policy_anchor_text", defaultText: ac.privacyPolicyAnchorText)
        case .dpo:
            guard !ac.privacyCenterUrl.isEmpty, let anchor = ac.privacyCenterAnchorText, !anchor.isEmpty else { return "" }
            return getTranslatedText("privacy_center_anchor_text", defaultText: anchor)
        }
    }

    func recordedAnswer(forPurpose purposeUuid: String, productUuid: String? = nil) -> Bool? {
        let lookup = ProductConsent.recordedSelectionLookup(
            purposeSelections: content?.detail.purposeSelections,
            productPurposeSelections: content?.detail.productPurposeSelections
        )
        let recorded = lookup(purposeUuid, productUuid)
        guard PurposePreselectionLogic.hasRecordedState(recorded) else { return nil }
        return recorded?.selected
    }

    /// `confirmFirst` is the view's live reading of `confirmBeforeSubmit`,
    /// which follows the host's current settings.
    func requestAction(_ action: ConfirmAction, confirmFirst: Bool? = nil) {
        if action == .acceptSelected && acceptDisabled {
            return
        }
        if confirmFirst ?? confirmBeforeSubmit {
            pendingConfirmAction = action
            return
        }
        perform(action)
    }

    func confirmPendingAction(_ action: ConfirmAction) {
        pendingConfirmAction = nil
        perform(action)
    }

    func dismissConfirm() {
        pendingConfirmAction = nil
    }

    private func perform(_ action: ConfirmAction) {
        switch action {
        case .acceptAll:
            handleAccept(mode: .all)
        case .acceptSelected:
            handleAccept(mode: .selected)
        case .decline:
            handleDecline()
        }
    }
}
