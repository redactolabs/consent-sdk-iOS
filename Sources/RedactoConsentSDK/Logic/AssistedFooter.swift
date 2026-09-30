import Foundation

/// A piece of the assisted notice's running text: plain, or a link, and the id
/// talkback highlights it by.
struct AssistedTextRun: Equatable {
    let text: String
    var link: URL?
    var elementId: String?
}

/// The notice paragraph and the footer lines of React's assisted notice
/// (`renderNoticeScreen` and `renderDpoFooter`), as runs the view draws.
enum AssistedFooter {
    typealias Translate = (_ key: String, _ fallback: String) -> String

    /// `notice_text`, then the notice's privacy policy on its own line unless
    /// every product links its own. An unset policy URL still shows the anchor.
    static func noticeLines(
        _ config: ActiveConfig,
        showsPolicyLink: Bool,
        translate: Translate
    ) -> [[AssistedTextRun]] {
        var lines = [[AssistedTextRun(text: translate("notice_text", config.noticeText), elementId: AssistedElementId.noticeText)]]
        if showsPolicyLink {
            lines.append([
                AssistedTextRun(
                    text: translate("privacy_policy_prefix_text", config.privacyPolicyPrefixText),
                    elementId: AssistedElementId.privacyPolicyText
                ),
                AssistedTextRun(text: " "),
                AssistedTextRun(
                    text: translate(
                        "privacy_policy_anchor_text",
                        config.privacyPolicyAnchorText.isEmpty ? AssistedDefaults.privacyPolicyAnchor : config.privacyPolicyAnchorText
                    ),
                    link: url(config.privacyPolicyUrl),
                    elementId: AssistedElementId.privacyPolicyLink
                ),
            ])
        }
        return lines
    }

    static func hasPrivacyCenterLine(_ config: ActiveConfig) -> Bool {
        !config.privacyCenterUrl.isEmpty || !config.additionalText.isEmpty
    }

    /// Empty when there is nothing to show, so the divider is not drawn either.
    static func footerLines(
        _ config: ActiveConfig,
        policyLinks: [ProductPolicyLink],
        translate: Translate,
        dpoText: Translate
    ) -> [[AssistedTextRun]] {
        var lines: [[AssistedTextRun]] = []

        if hasPrivacyCenterLine(config) {
            var line = [AssistedTextRun(
                text: translate("additional_text", config.additionalText.isEmpty ? AssistedDefaults.additionalText : config.additionalText),
                elementId: AssistedElementId.additionalText
            )]
            if !config.privacyCenterUrl.isEmpty {
                line.append(AssistedTextRun(text: " "))
                line.append(AssistedTextRun(
                    text: translate("privacy_center_anchor_text", nonEmpty(config.privacyCenterAnchorText) ?? AssistedDefaults.privacyCenterAnchor),
                    link: url(config.privacyCenterUrl),
                    elementId: AssistedElementId.privacyCenterLink
                ))
                line.append(AssistedTextRun(text: "."))
            }
            lines.append(line)
        }

        if !policyLinks.isEmpty {
            var line = [
                AssistedTextRun(text: translate(ProductPolicyCopy.translationKey, ProductPolicyCopy.label)),
                AssistedTextRun(text: " "),
            ]
            for (index, entry) in policyLinks.enumerated() {
                if index > 0 {
                    line.append(AssistedTextRun(text: ", "))
                }
                line.append(AssistedTextRun(text: entry.name, link: url(entry.url)))
            }
            lines.append(line)
        }

        if let dpo = config.dpoInfo {
            var grievance = [
                AssistedTextRun(text: dpoText("grievance_text", dpo.grievanceText), elementId: AssistedElementId.dpoGrievanceText),
                AssistedTextRun(text: " "),
            ]
            if !dpo.grievanceUrl.isEmpty {
                grievance.append(AssistedTextRun(
                    text: dpoText("grievance_anchor_text", nonEmpty(dpo.grievanceAnchorText) ?? AssistedDefaults.grievanceAnchor),
                    link: url(dpo.grievanceUrl),
                    elementId: AssistedElementId.dpoGrievanceLink
                ))
            }
            grievance.append(AssistedTextRun(text: " "))
            if !dpo.grievanceEmail.isEmpty {
                grievance.append(AssistedTextRun(
                    text: dpoText(
                        "grievance_email_connector_text",
                        nonEmpty(dpo.grievanceEmailConnectorText) ?? AssistedDefaults.grievanceEmailConnector
                    ),
                    elementId: AssistedElementId.dpoGrievanceEmailConnector
                ))
                grievance.append(AssistedTextRun(text: " "))
                grievance.append(AssistedTextRun(
                    text: dpo.grievanceEmail,
                    link: url("mailto:\(dpo.grievanceEmail)"),
                    elementId: AssistedElementId.dpoGrievanceEmail
                ))
            }
            lines.append(grievance)

            var board = [
                AssistedTextRun(text: dpoText("dp_board_text", dpo.dpBoardText), elementId: AssistedElementId.dpoBoardText),
                AssistedTextRun(text: " "),
            ]
            if !dpo.dpBoardUrl.isEmpty {
                board.append(AssistedTextRun(
                    text: dpoText("dp_board_anchor_text", nonEmpty(dpo.dpBoardAnchorText) ?? AssistedDefaults.dpBoardAnchor),
                    link: url(dpo.dpBoardUrl),
                    elementId: AssistedElementId.dpoBoardLink
                ))
            }
            lines.append(board)

            var officer = [
                AssistedTextRun(text: dpoText("dpo_text", dpo.dpoText), elementId: AssistedElementId.dpoText),
                AssistedTextRun(text: " "),
            ]
            if let email = nonEmpty(dpo.dpoEmail) {
                officer.append(AssistedTextRun(
                    text: dpoText("dpo_anchor_text", nonEmpty(dpo.dpoAnchorText) ?? AssistedDefaults.dpoAnchor),
                    link: url("mailto:\(email)"),
                    elementId: AssistedElementId.dpoLink
                ))
            }
            lines.append(officer)
        }

        return lines
    }

    static func plainText(_ lines: [[AssistedTextRun]]) -> String {
        lines.map { $0.map(\.text).joined() }.joined(separator: "\n")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func url(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
