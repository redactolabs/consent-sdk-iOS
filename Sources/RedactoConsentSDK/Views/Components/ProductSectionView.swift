import SwiftUI

struct ProductSectionView<Rows: View>: View {
    let name: String
    let isRequired: Bool
    let summary: ProductSectionSummary
    let collapsed: Bool
    let locked: Bool
    let settings: ConsentSettings?
    let accentColor: String
    var selectionControl: SelectionControlType = .checkbox
    let onToggleCollapse: () -> Void
    let onSelect: (Bool) -> Void
    @ViewBuilder let rows: () -> Rows

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    private var selectLabel: String {
        summary.requiredOnly
            ? ProductSectionCopy.toggleRequired(name, summary.purposeCount)
            : ProductSectionCopy.toggleSelection(name, summary.purposeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(theme.isGlass
                    ? (theme.isPhone ? EdgeInsets(top: 14, leading: 10, bottom: 10, trailing: 14)
                        : EdgeInsets(top: 16, leading: 12, bottom: 10, trailing: 16))
                    : EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            if !collapsed {
                VStack(spacing: theme.isGlass ? 0 : 10) {
                    rows()
                }
                .padding(.leading, theme.isGlass ? 12 : 18)
                .padding(.bottom, theme.isGlass ? 0 : 14)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggleCollapse) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.heading)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
                    .frame(width: 17, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsed ? ProductSectionCopy.expand(name) : ProductSectionCopy.collapse(name))

            (Text(name) + (isRequired ? Text(" *").foregroundColor(.red) : Text("")))
                .noticeFont(size: theme.size(.optionTitle), weight: theme.sectionTitleWeight)
                .foregroundColor(theme.heading)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
                .onTapGesture(perform: onToggleCollapse)

            Spacer(minLength: 0)

            SelectionControlView(
                control: selectionControl,
                checked: summary.allSelected,
                indeterminate: summary.mixed,
                locked: locked,
                level: .product,
                label: selectLabel,
                lockedLabel: ProductSectionCopy.settled(name),
                accentColor: accentColor,
                onSelect: onSelect
            )
        }
    }
}
