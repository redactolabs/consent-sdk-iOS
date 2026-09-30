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
    /// The modal notice's rules: an empty link label takes the SDK default, and
    /// a link shows only when it has somewhere to go.
    var linksNeedTargets = false
    var textColorOverride: Color?
    /// Space between the stacked lines, so they sit as far apart as wrapped ones.
    var lineGap: CGFloat = 0

    private var textColor: Color {
        textColorOverride ?? Color(hex: settings?.textColor ?? "#344054")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineGap) {
            grievanceAndEmailRow
            dpBoardRow
            dpoRow
        }
    }

    private func label(_ key: String, _ value: String, fallback: String) -> String {
        guard linksNeedTargets else { return getTranslatedDpoText(key, value) }
        return getTranslatedDpoText(key, value.isEmpty ? fallback : value)
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
            anchor: label("dp_board_anchor_text", dpoInfo.dpBoardAnchorText, fallback: DpoCopy.dpBoardAnchor),
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
        let target = linksNeedTargets
            ? (dpoInfo.dpoEmail.flatMap { $0.isEmpty ? nil : "mailto:\($0)" } ?? "")
            : (dpoInfo.dpoContactUrl ?? "")
        return Text(linkedSentenceText(
            text: getTranslatedDpoText("dpo_text", dpoInfo.dpoText),
            anchor: label("dpo_anchor_text", dpoInfo.dpoAnchorText, fallback: DpoCopy.dpoAnchor),
            urlString: target
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
            anchor: label("grievance_anchor_text", dpoInfo.grievanceAnchorText, fallback: DpoCopy.grievanceAnchor),
            urlString: dpoInfo.grievanceUrl
        )

        if !dpoInfo.grievanceEmail.isEmpty {
            let connector = getTranslatedDpoText(
                "grievance_email_connector_text",
                dpoInfo.grievanceEmailConnectorText.flatMap { $0.isEmpty ? nil : $0 } ?? DpoCopy.emailConnector
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
        if linksNeedTargets && urlString.isEmpty { return result }

        result.append(AttributedString(" "))
        var anchorText = AttributedString(anchor)
        if let url = URL(string: urlString), !urlString.isEmpty {
            anchorText.link = url
        }
        result.append(anchorText)

        return result
    }
}
