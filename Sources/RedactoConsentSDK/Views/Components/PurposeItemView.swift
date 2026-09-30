import SwiftUI

/// Collapsible purpose row with data elements.
/// Port of the PurposeItem sub-component from RedactoNoticeConsent.tsx.
struct PurposeItemView: View {
    let purpose: ActiveConfigPurpose
    let selectedPurposes: [String: Bool]
    let collapsedPurposes: [String: Bool]
    let selectedDataElements: [String: Bool]
    let settings: ConsentSettings?
    let primaryColor: String?
    let onPurposeToggle: (String) -> Void
    let onPurposeCollapse: (String) -> Void
    let onDataElementToggle: (String, String) -> Void
    let getTranslatedText: (String, String, String?) -> String
    let isAlreadyConsented: Bool
    var initialDataElementSelections: [String: Bool] = [:]
    var activeTTSSegmentKey: String?
    var productUuid: String?
    var selectionControl: SelectionControlType = .checkbox
    var recordedAnswer: Bool?

    @Environment(\.noticeTheme) private var environmentTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    private var stateKey: String {
        ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
    }

    private var purposeName: String {
        getTranslatedText("purposes.name", purpose.name, purpose.uuid)
    }

    /// An unseeded row reads open, as the web's `!collapsed[key]` does.
    private var isCollapsed: Bool {
        collapsedPurposes[stateKey] ?? false
    }

    private var accentColor: String {
        settings?.button?.accept?.backgroundColor ?? primaryColor ?? "#4f87ff"
    }

    var body: some View {
        let row = theme.optionRow
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    onPurposeCollapse(purpose.uuid)
                } label: {
                    HStack(alignment: .center, spacing: theme.isGlass ? 10 : 12) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.heading)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .frame(width: 12, height: 16)
                            .padding(.leading, 5)

                        VStack(alignment: .leading, spacing: theme.isGlass ? 2 : 0) {
                            let nameHighlighted = activeTTSSegmentKey == "purpose_name_\(purpose.uuid)"
                            (Text(purposeName)
                                + (ProductConsent.hasRequiredDataElement(purpose) ? Text(" *").foregroundColor(.red) : Text("")))
                                .noticeFont(size: theme.size(.optionTitle), weight: theme.weight(.optionTitle))
                                .foregroundColor(theme.ttsColor(theme.heading, highlighted: nameHighlighted))
                                .multilineTextAlignment(.leading)
                                .ttsSegmentHighlighted(nameHighlighted)
                                .id("purpose_name_\(purpose.uuid)")

                            let descHighlighted = activeTTSSegmentKey == "purpose_desc_\(purpose.uuid)"
                            Text(getTranslatedText("purposes.description", purpose.description, purpose.uuid))
                                .noticeFont(size: theme.size(.optionDescription))
                                .foregroundColor(theme.ttsColor(theme.text, highlighted: descHighlighted))
                                .opacity(theme.isGlass ? 0.85 : 1)
                                .multilineTextAlignment(.leading)
                                .ttsSegmentHighlighted(descHighlighted)
                                .id("purpose_desc_\(purpose.uuid)")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(isCollapsed ? "Expand" : "Collapse") \(purposeName) details")

                Spacer(minLength: 0)

                SelectionControlView(
                    control: selectionControl,
                    checked: selectedPurposes[stateKey] ?? false,
                    locked: isAlreadyConsented,
                    recordedAnswer: recordedAnswer,
                    label: "Select all data elements for \(purposeName)",
                    lockedLabel: SelectionControlCopy.settled(purposeName),
                    accentColor: accentColor,
                    onSelect: { _ in onPurposeToggle(purpose.uuid) }
                )
            }
            .padding(row.insets)
            .background(row.fill.map { RoundedRectangle(cornerRadius: row.radius).fill($0) })
            .overlay(alignment: .bottom) {
                if let rule = row.bottomRule {
                    Rectangle().fill(rule).frame(height: 1)
                }
            }

            if !isCollapsed && !purpose.dataElements.isEmpty {
                dataElements
                    .transition(.opacity)
            }
        }
        .animation(
            theme.layout.collapsibleSections
                ? NoticeMotion.animation(NoticeMotion.collapse, enabled: NoticeMotion.isEnabled(theme.layout, reduceMotion: reduceMotion))
                : nil,
            value: isCollapsed
        )
    }

    private var dataElements: some View {
        VStack(spacing: theme.isGlass ? 4 : 0) {
            ForEach(purpose.dataElements, id: \.uuid) { dataElement in
                dataElementRow(dataElement)
            }
        }
        .padding(theme.isGlass
            ? (theme.isPhone ? EdgeInsets(top: 0, leading: 30, bottom: 12, trailing: 14)
                : EdgeInsets(top: 0, leading: 34, bottom: 14, trailing: 16))
            : EdgeInsets(top: 2, leading: 22, bottom: 2, trailing: 0))
    }

    private func dataElementRow(_ dataElement: ActiveConfigDataElement) -> some View {
        let inset = theme.dataElementRow
        let name = getTranslatedText("data_elements.name", dataElement.name, dataElement.uuid)
        let highlighted = activeTTSSegmentKey == "element_\(dataElement.uuid)"
        return HStack(spacing: 10) {
            (Text(name)
                + (ProductConsent.isBlockingRequiredElement(dataElement) ? Text(" *").foregroundColor(.red) : Text("")))
                .noticeFont(size: theme.size(.dataElement), weight: theme.weight(.dataElement))
                .foregroundColor(theme.ttsColor(theme.text, highlighted: highlighted))
                .ttsSegmentHighlighted(highlighted)
                .id("element_\(dataElement.uuid)")

            Spacer(minLength: 0)

            if isAlreadyConsented {
                let wasSelected = initialDataElementSelections["\(stateKey)-\(dataElement.uuid)"] ?? false
                if wasSelected {
                    consentedCheckmark(size: 16)
                        .accessibilityLabel("Consented to \(name)")
                } else {
                    Circle()
                        .stroke(Color(hex: "#d0d5dd"), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .accessibilityLabel("Not consented to \(name)")
                }
            } else if theme.layout.switchControl && environmentTheme != nil {
                NoticeRoundCheckView(
                    checked: selectedDataElements["\(stateKey)-\(dataElement.uuid)"] ?? false,
                    theme: theme,
                    onChange: { onDataElementToggle(dataElement.uuid, purpose.uuid) }
                )
                .accessibilityLabel("Select \(name)\(dataElement.required ? " (required)" : "")")
            } else {
                CheckboxView(
                    checked: selectedDataElements["\(stateKey)-\(dataElement.uuid)"] ?? false,
                    onChange: { onDataElementToggle(dataElement.uuid, purpose.uuid) },
                    size: .small,
                    accentColor: accentColor
                )
                .accessibilityLabel("Select \(name)\(dataElement.required ? " (required)" : "")")
            }
        }
        .frame(minHeight: inset == nil ? 24 : 36)
        .padding(.horizontal, inset == nil ? 0 : 10)
        .padding(.vertical, inset == nil ? 2 : 8)
        .background(inset.map { RoundedRectangle(cornerRadius: $0.radius).fill($0.fill) })
    }

    @ViewBuilder
    private func consentedCheckmark(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#10B981"))
                .frame(width: size, height: size)

            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
