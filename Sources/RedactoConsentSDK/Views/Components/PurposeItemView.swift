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

    private var headingColor: Color {
        Color(hex: settings?.headingColor ?? "#323B4B")
    }

    private var textColor: Color {
        Color(hex: settings?.textColor ?? "#344054")
    }

    private var isCollapsed: Bool {
        collapsedPurposes[purpose.uuid] ?? true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Purpose row
            HStack(alignment: .top, spacing: 8) {
                // Chevron + text (tappable to collapse)
                Button {
                    onPurposeCollapse(purpose.uuid)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: settings?.headingColor ?? "#323B4B"))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .frame(width: 16, height: 16)
                            .padding(.top, 4)

                        // Purpose name and description
                        VStack(alignment: .leading, spacing: 2) {
                            Text(getTranslatedText("purposes.name", purpose.name, purpose.uuid))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(headingColor)
                                .multilineTextAlignment(.leading)
                                .ttsSegmentHighlighted(activeTTSSegmentKey == "purpose_name_\(purpose.uuid)")
                                .id("purpose_name_\(purpose.uuid)")

                            Text(getTranslatedText("purposes.description", purpose.description, purpose.uuid))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(textColor)
                                .multilineTextAlignment(.leading)
                                .ttsSegmentHighlighted(activeTTSSegmentKey == "purpose_desc_\(purpose.uuid)")
                                .id("purpose_desc_\(purpose.uuid)")
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Checkbox or consented checkmark
                if isAlreadyConsented {
                    consentedCheckmark(size: 20)
                } else {
                    CheckboxView(
                        checked: selectedPurposes[purpose.uuid] ?? false,
                        onChange: { onPurposeToggle(purpose.uuid) },
                        size: .large,
                        accentColor: settings?.button?.accept?.backgroundColor ?? primaryColor ?? "#4f87ff"
                    )
                }
            }
            .padding(.vertical, 0)

            // Data elements (expanded)
            if !isCollapsed && !purpose.dataElements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(purpose.dataElements, id: \.uuid) { dataElement in
                        HStack {
                            HStack(spacing: 4) {
                                Text(getTranslatedText("data_elements.name", dataElement.name, dataElement.uuid))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(textColor)
                                    .ttsSegmentHighlighted(activeTTSSegmentKey == "element_\(dataElement.uuid)")
                                    .id("element_\(dataElement.uuid)")

                                if dataElement.required {
                                    Text("*")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.red)
                                }
                            }

                            Spacer()

                            if isAlreadyConsented {
                                let wasSelected = initialDataElementSelections["\(purpose.uuid)-\(dataElement.uuid)"] ?? false
                                if wasSelected {
                                    consentedCheckmark(size: 16)
                                } else {
                                    Circle()
                                        .stroke(Color(hex: "#d0d5dd"), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            } else {
                                CheckboxView(
                                    checked: selectedDataElements["\(purpose.uuid)-\(dataElement.uuid)"] ?? false,
                                    onChange: { onDataElementToggle(dataElement.uuid, purpose.uuid) },
                                    size: .small,
                                    accentColor: settings?.button?.accept?.backgroundColor ?? primaryColor ?? "#4f87ff"
                                )
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.leading, 26)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
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
