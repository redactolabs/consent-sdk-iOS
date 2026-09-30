import SwiftUI

/// A purpose row of the inline and assisted notices: chevron, name and
/// description, the purpose control, and the data elements when expanded.
struct PairPurposeRowView: View {
    let purpose: ActiveConfigPurpose
    let dataElements: [ActiveConfigDataElement]
    let isCollapsed: Bool
    let isSelected: Bool
    let isElementSelected: (String) -> Bool
    let translate: (String, String, String?) -> String
    let headingColor: Color
    let textColor: Color
    let accentColor: String
    var locked: Bool = false
    let onToggleCollapse: () -> Void
    let onTogglePurpose: () -> Void
    let onToggleElement: (String) -> Void
    var style = PairRowStyle()
    var motion = true

    private var purposeName: String {
        translate("purposes.name", purpose.name, purpose.uuid)
    }

    private var purposeDescription: String {
        translate("purposes.description", purpose.description, purpose.uuid)
    }

    private var accent: Color {
        AppearanceColor.color(accentColor) ?? Color(hex: accentColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Button(action: onToggleCollapse) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(style.chevronColor ?? headingColor)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .animation(motion ? .easeInOut(duration: 0.3) : nil, value: isCollapsed)
                            .frame(width: 12, height: 16)
                            .padding(.leading, 5)

                        VStack(alignment: .leading, spacing: 0) {
                            highlighted(
                                requiredMarked(Text(purposeName), marked: ProductConsent.hasRequiredDataElement(purpose))
                                    .noticeFont(size: style.titleSize, weight: .medium)
                                    .foregroundColor(textColor(headingColor, id: style.purposeNameId(purpose.uuid)))
                                    .multilineTextAlignment(.leading),
                                id: style.purposeNameId(purpose.uuid)
                            )

                            if !(style.hidesEmptyDescription && purposeDescription.isEmpty) {
                                highlighted(
                                    Text(purposeDescription)
                                        .noticeFont(size: style.descriptionSize)
                                        .foregroundColor(textColor(style.descriptionColor ?? textColor, id: style.purposeDescriptionId(purpose.uuid)))
                                        .multilineTextAlignment(.leading),
                                    id: style.purposeDescriptionId(purpose.uuid)
                                )
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.collapseLabel(isCollapsed, purposeName))
                .accessibilityAddTraits(.isButton)

                Spacer(minLength: 8)

                purposeControl
                    .disabled(locked)
            }
            .padding(style.rowPadding)
            .background(
                RoundedRectangle(cornerRadius: style.rowCornerRadius)
                    .fill(style.rowBackground ?? Color.clear)
            )
            .overlay(alignment: .bottom) {
                if let divider = style.rowDivider {
                    Rectangle().fill(divider).frame(height: 1)
                }
            }

            if !isCollapsed && !dataElements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(dataElements, id: \.uuid) { element in
                        elementRow(element)
                    }
                }
                .padding(.leading, 22)
            }
        }
        .opacity(locked ? style.lockedOpacity : 1)
    }

    @ViewBuilder
    private var purposeControl: some View {
        let label = style.purposeControlLabel(purposeName)
        if style.selectionControl == .checkbox {
            Group {
                if style.switchControl {
                    PairSwitch(
                        isOn: isSelected,
                        width: style.purposeBoxSize >= 20 ? 44 : 40,
                        height: style.purposeBoxSize >= 20 ? 26 : 24,
                        thumb: style.purposeBoxSize >= 20 ? 20 : 18,
                        accent: accent,
                        track: style.controlOffColor,
                        knob: style.knobColor,
                        animates: motion,
                        action: onTogglePurpose
                    )
                } else {
                    PairCheckbox(
                        checked: isSelected,
                        size: style.purposeBoxSize,
                        accent: accent,
                        offColor: style.controlOffColor,
                        action: onTogglePurpose
                    )
                }
            }
            .accessibilityLabel(label)
            .accessibilityValue(isSelected ? SelectionControlCopy.yes : SelectionControlCopy.no)
        } else {
            SelectionControlView(
                control: style.selectionControl,
                checked: isSelected,
                label: label,
                lockedLabel: SelectionControlCopy.settled(purposeName),
                onSelect: { _ in onTogglePurpose() }
            )
        }
    }

    private func elementRow(_ element: ActiveConfigDataElement) -> some View {
        let name = translate("data_elements.name", element.name, element.uuid)
        let id = style.elementId(purpose.uuid, element.uuid)
        return HStack(spacing: 10) {
            highlighted(
                requiredMarked(Text(name), marked: ProductConsent.isBlockingRequiredElement(element))
                    .noticeFont(size: style.elementSize)
                    .foregroundColor(textColor(textColor, id: id)),
                id: id
            )

            Spacer(minLength: 8)

            Group {
                if style.switchControl && style.selectionControl == .checkbox {
                    PairRoundCheck(
                        checked: isElementSelected(element.uuid),
                        accent: accent,
                        outline: style.controlOffColor,
                        action: { onToggleElement(element.uuid) }
                    )
                } else {
                    PairCheckbox(
                        checked: isElementSelected(element.uuid),
                        size: style.elementBoxSize,
                        accent: accent,
                        offColor: style.controlOffColor,
                        action: { onToggleElement(element.uuid) }
                    )
                }
            }
            .disabled(locked)
            .accessibilityLabel(style.elementLabel(name, element.required))
        }
        .frame(minHeight: 24)
    }

    private func textColor(_ base: Color, id: String) -> Color {
        style.isHighlighted(id) ? (style.highlightText ?? base) : base
    }

    private func highlighted<Content: View>(_ content: Content, id: String) -> some View {
        content
            .modifier(PairHighlight(isOn: style.isHighlighted(id), background: style.highlightBackground))
            .id(id)
    }

    private func requiredMarked(_ text: Text, marked: Bool) -> Text {
        guard marked else { return text }
        return text + Text(" *").foregroundColor(.red)
    }
}
