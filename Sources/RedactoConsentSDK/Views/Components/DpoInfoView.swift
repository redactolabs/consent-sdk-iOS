import SwiftUI

/// Data Protection Officer information display with links.
/// Port of the DPO info section from RedactoNoticeConsent.tsx.
/// Supports localization via the `getTranslatedDpoText` function.
struct DpoInfoView: View {
    let dpoInfo: DpoInfo
    let settings: ConsentSettings?
    let getTranslatedDpoText: (String, String) -> String
    let activeTTSSegmentKey: String?
    let linkColor: Color

    private var textColor: Color {
        Color(hex: settings?.textColor ?? "#344054")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grievanceAndEmailRow
            dpBoardRow
            dpoRow
        }
    }

    private var grievanceAndEmailRow: some View {
        Text(grievanceAndEmailText)
            .foregroundColor(textColor)
            .tint(linkColor)
            .fixedSize(horizontal: false, vertical: true)
            .ttsSegmentHighlighted(
                activeTTSSegmentKey == "dpo_grievance_text" ||
                activeTTSSegmentKey == "dpo_grievance_anchor_text" ||
                activeTTSSegmentKey == "dpo_grievance_email_connector_text" ||
                activeTTSSegmentKey == "dpo_grievance_email"
            )
            .id("dpo_grievance_text")
    }

    private var dpBoardRow: some View {
        Text(linkedSentenceText(
            text: getTranslatedDpoText("dp_board_text", dpoInfo.dpBoardText),
            anchor: getTranslatedDpoText("dp_board_anchor_text", dpoInfo.dpBoardAnchorText),
            urlString: dpoInfo.dpBoardUrl
        ))
        .foregroundColor(textColor)
        .tint(linkColor)
        .fixedSize(horizontal: false, vertical: true)
        .ttsSegmentHighlighted(
            activeTTSSegmentKey == "dpo_dp_board_text" ||
            activeTTSSegmentKey == "dpo_dp_board_anchor_text"
        )
        .id("dpo_dp_board_text")
    }

    private var dpoRow: some View {
        Text(linkedSentenceText(
            text: getTranslatedDpoText("dpo_text", dpoInfo.dpoText),
            anchor: getTranslatedDpoText("dpo_anchor_text", dpoInfo.dpoAnchorText),
            urlString: dpoInfo.dpoUrl
        ))
        .foregroundColor(textColor)
        .tint(linkColor)
        .fixedSize(horizontal: false, vertical: true)
        .ttsSegmentHighlighted(
            activeTTSSegmentKey == "dpo_dpo_text" ||
            activeTTSSegmentKey == "dpo_dpo_anchor_text"
        )
        .id("dpo_dpo_text")
    }

    private var grievanceAndEmailText: AttributedString {
        var result = linkedSentenceText(
            text: getTranslatedDpoText("grievance_text", dpoInfo.grievanceText),
            anchor: getTranslatedDpoText("grievance_anchor_text", dpoInfo.grievanceAnchorText),
            urlString: dpoInfo.grievanceUrl
        )

        if !dpoInfo.grievanceEmail.isEmpty {
            let connector = getTranslatedDpoText(
                "grievance_email_connector_text",
                dpoInfo.grievanceEmailConnectorText ?? "or email to"
            )

            result.append(AttributedString(" "))
            result.append(AttributedString(connector))
            result.append(AttributedString(" "))

            var email = AttributedString(dpoInfo.grievanceEmail)
            if let url = URL(string: "mailto:\(dpoInfo.grievanceEmail)") {
                email.link = url
            }
            result.append(email)
        }

        return result
    }

    private func linkedSentenceText(text: String, anchor: String, urlString: String) -> AttributedString {
        var result = AttributedString(text)
        guard !anchor.isEmpty else { return result }

        result.append(AttributedString(" "))
        var anchorText = AttributedString(anchor)
        if let url = URL(string: urlString), !urlString.isEmpty {
            anchorText.link = url
        }
        result.append(anchorText)

        return result
    }
}
