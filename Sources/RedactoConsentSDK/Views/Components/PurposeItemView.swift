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
    var lockedReason: String?
    var initialDataElementSelections: [String: Bool] = [:]
    var activeTTSSegmentKey: String?
    var productUuid: String?
    var selectionControl: SelectionControlType = .checkbox
    var recordedAnswer: Bool?
    var showsDataElements: Bool = true
    /// Whether each data element carries its own tick. Turned off, they are
    /// listed with nothing to answer, and the purpose's tick takes them all.
    var showsDataElementControls: Bool = true
    var descriptionPlacement: PurposeDescriptionPlacement = .always
    var controlPosition: NoticeControlPosition = .right

    @Environment(\.noticeTheme) private var environmentTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    private var stateKey: String {
        ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
    }

    private var purposeName: String {
        getTranslatedText("purposes.name", purpose.name, purpose.uuid)
    }

    private var purposeDescriptionText: String {
        getTranslatedText("purposes.description", purpose.description, purpose.uuid)
    }

    /// An unseeded row reads open, as the web's `!collapsed[key]` does.
    private var isCollapsed: Bool {
        collapsedPurposes[stateKey] ?? false
    }

    private var hasDataElements: Bool {
        showsDataElements && !purpose.dataElements.isEmpty
    }

    /// The description can sit behind the chevron too, so the disclosure holds
    /// more than the data elements. An empty description is nothing.
    private var disclosesDescription: Bool {
        descriptionPlacement == .expanded
            && !purposeDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A row with the data elements drawn keeps its chevron even when the
    /// purpose carries none, the way every notice published before these
    /// fields did; only hiding them empties the disclosure.
    private var drawsChevron: Bool {
        showsDataElements || disclosesDescription
    }

    private var accentColor: String {
        settings?.button?.accept?.backgroundColor ?? primaryColor ?? "#4f87ff"
    }

    var body: some View {
        let row = theme.optionRow
        let leadsWithControl = controlPosition == .left
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                if leadsWithControl {
                    purposeControl
                }

                if drawsChevron {
                    Button {
                        onPurposeCollapse(purpose.uuid)
                    } label: {
                        rowLabel(leadsWithControl: leadsWithControl)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(isCollapsed ? "Expand" : "Collapse") \(purposeName) details")
                } else {
                    rowLabel(leadsWithControl: leadsWithControl)
                }

                Spacer(minLength: 0)

                if !leadsWithControl {
                    purposeControl
                }
            }
            .padding(row.insets)
            .background(row.fill.map { RoundedRectangle(cornerRadius: row.radius).fill($0) })
            .overlay(alignment: .bottom) {
                if let rule = row.bottomRule {
                    Rectangle().fill(rule).frame(height: 1)
                }
            }

            if let lockedReason {
                Text(lockedReason)
                    .noticeFont(size: theme.size(.optionDescription))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(disclosureInsets)
            }

            if !isCollapsed {
                if disclosesDescription {
                    descriptionText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(disclosureInsets)
                        .transition(.opacity)
                }

                if hasDataElements {
                    dataElements
                        .transition(.opacity)
                }
            }
        }
        .animation(
            theme.layout.collapsibleSections
                ? NoticeMotion.animation(NoticeMotion.collapse, enabled: NoticeMotion.isEnabled(theme.layout, reduceMotion: reduceMotion))
                : nil,
            value: isCollapsed
        )
    }

    private func rowLabel(leadsWithControl: Bool) -> some View {
        HStack(alignment: .center, spacing: theme.isGlass ? 10 : 12) {
            if !leadsWithControl && drawsChevron {
                chevron
            }

            VStack(alignment: .leading, spacing: theme.isGlass ? 2 : 0) {
                let nameHighlighted = activeTTSSegmentKey == "purpose_name_\(purpose.uuid)"
                (Text(purposeName)
                    + (ProductConsent.hasRequiredDataElement(purpose) ? Text(" *").foregroundColor(.red) : Text("")))
                    .noticeFont(size: theme.size(.optionTitle), weight: theme.weight(.optionTitle))
                    .foregroundColor(theme.ttsColor(theme.heading, highlighted: nameHighlighted))
                    .multilineTextAlignment(.leading)
                    .ttsSegmentHighlighted(nameHighlighted)
                    .id("purpose_name_\(purpose.uuid)")

                if descriptionPlacement == .always {
                    descriptionText
                }
            }

            if leadsWithControl && drawsChevron {
                chevron
            }
        }
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(theme.heading)
            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            .frame(width: 12, height: 16)
            .padding(.leading, 5)
    }

    private var descriptionText: some View {
        let highlighted = activeTTSSegmentKey == "purpose_desc_\(purpose.uuid)"
        return Text(purposeDescriptionText)
            .noticeFont(size: theme.size(.optionDescription))
            .foregroundColor(theme.ttsColor(theme.text, highlighted: highlighted))
            .opacity(theme.isGlass ? 0.85 : 1)
            .multilineTextAlignment(.leading)
            .ttsSegmentHighlighted(highlighted)
            .id("purpose_desc_\(purpose.uuid)")
    }

    private var purposeControl: some View {
        SelectionControlView(
            control: selectionControl,
            checked: selectedPurposes[stateKey] ?? false,
            locked: isAlreadyConsented,
            recordedAnswer: recordedAnswer,
            label: "Select all data elements for \(purposeName)",
            lockedLabel: SelectionControlCopy.settled(purposeName),
            lockedHint: lockedReason,
            accentColor: accentColor,
            onSelect: { _ in onPurposeToggle(purpose.uuid) }
        )
    }

    private var disclosureInsets: EdgeInsets {
        theme.isGlass
            ? (theme.isPhone ? EdgeInsets(top: 0, leading: 30, bottom: 12, trailing: 14)
                : EdgeInsets(top: 0, leading: 34, bottom: 14, trailing: 16))
            : EdgeInsets(top: 2, leading: 22, bottom: 2, trailing: 0)
    }

    private var dataElements: some View {
        VStack(spacing: theme.isGlass ? 4 : 0) {
            if showsDataElementControls {
                ForEach(purpose.dataElements, id: \.uuid) { dataElement in
                    dataElementRow(dataElement)
                }
            } else {
                dataElementList
            }
        }
        .padding(disclosureInsets)
    }

    /// Listed only: with no tick of their own the data elements follow their
    /// purpose, so there is no answer, given or settled, to draw beside one,
    /// and they read as one comma-separated line that wraps like prose.
    private var dataElementList: some View {
        let name = { (element: ActiveConfigDataElement) in
            getTranslatedText("data_elements.name", element.name, element.uuid)
        }
        return dataElementInset(
            Text(DataElementList.line(
                purpose.dataElements,
                name: name,
                isHighlighted: { activeTTSSegmentKey == "element_\($0.uuid)" },
                highlightBackground: theme.ttsHighlight,
                highlightText: theme.ttsText
            ))
            .noticeFont(size: theme.size(.dataElement), weight: theme.weight(.dataElement))
            .foregroundColor(theme.text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(DataElementList.accessibilityLabel(purpose.dataElements, name: name))
            // Talkback scrolls to each element it reads by its own id.
            .background {
                ForEach(purpose.dataElements, id: \.uuid) { element in
                    Color.clear.id("element_\(element.uuid)")
                }
            }
        )
    }

    /// The padding and fill a data element row sits in.
    private func dataElementInset<Content: View>(_ content: Content) -> some View {
        let inset = theme.dataElementRow
        return content
            .frame(minHeight: inset == nil ? 24 : 36)
            .padding(.horizontal, inset == nil ? 0 : 10)
            .padding(.vertical, inset == nil ? 2 : 8)
            .background(inset.map { RoundedRectangle(cornerRadius: $0.radius).fill($0.fill) })
    }

    private func dataElementRow(_ dataElement: ActiveConfigDataElement) -> some View {
        let name = getTranslatedText("data_elements.name", dataElement.name, dataElement.uuid)
        let highlighted = activeTTSSegmentKey == "element_\(dataElement.uuid)"
        let leadsWithControl = controlPosition == .left
        return dataElementInset(HStack(spacing: 10) {
            if leadsWithControl {
                elementControl(dataElement, name: name)
            }

            (Text(name)
                + (ProductConsent.isBlockingRequiredElement(dataElement) ? Text(" *").foregroundColor(.red) : Text("")))
                .noticeFont(size: theme.size(.dataElement), weight: theme.weight(.dataElement))
                .foregroundColor(theme.ttsColor(theme.text, highlighted: highlighted))
                .ttsSegmentHighlighted(highlighted)
                .id("element_\(dataElement.uuid)")

            Spacer(minLength: 0)

            if !leadsWithControl {
                elementControl(dataElement, name: name)
            }
        })
    }

    @ViewBuilder
    private func elementControl(_ dataElement: ActiveConfigDataElement, name: String) -> some View {
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
        } else if selectionControl != .checkbox {
            // The notice's radio or dropdown answers every row, so a
            // purpose and its data elements never ask in two vocabularies.
            SelectionControlView(
                control: selectionControl,
                checked: selectedDataElements["\(stateKey)-\(dataElement.uuid)"] ?? false,
                label: "Select \(name)\(dataElement.required ? " (required)" : "")",
                lockedLabel: SelectionControlCopy.settled(name),
                accentColor: accentColor,
                onSelect: { _ in onDataElementToggle(dataElement.uuid, purpose.uuid) }
            )
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
