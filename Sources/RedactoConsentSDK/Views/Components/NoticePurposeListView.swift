import SwiftUI

/// One purpose row of the single list, keyed so a purpose the reconsent split
/// puts in both lists still renders twice.
private struct ListedPurpose: Identifiable {
    let id: String
    let purpose: ActiveConfigPurpose
}

struct NoticePurposeListView: View {
    @ObservedObject var viewModel: ConsentNoticeViewModel
    var selectionControl: SelectionControlType?

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }

    private var control: SelectionControlType { selectionControl ?? viewModel.selectionControl }

    private var accentColor: String {
        viewModel.settings?.button?.accept?.backgroundColor ?? viewModel.activeConfig?.primaryColor ?? "#4f87ff"
    }

    /// The single-product (or product-less) list: on a reconsent the purposes
    /// already consented to first, then those needing consent.
    private var listedPurposes: [ListedPurpose] {
        if let split = viewModel.categorizedPurposes {
            return split.alreadyConsented.map { ListedPurpose(id: "consented-\($0.uuid)", purpose: $0) }
                + split.needsConsent.map { ListedPurpose(id: "needs-\($0.uuid)", purpose: $0) }
        }
        return viewModel.renderedPurposes.map { ListedPurpose(id: $0.uuid, purpose: $0) }
    }

    private func isListedLocked(_ item: ListedPurpose) -> Bool {
        if viewModel.categorizedPurposes != nil {
            return item.id.hasPrefix("consented-")
        }
        return viewModel.isReviewMode
    }

    var body: some View {
        if let ac = viewModel.activeConfig {
            panel {
                if viewModel.isMultiProduct {
                    ForEach(Array(viewModel.productGroups.enumerated()), id: \.element.product.uuid) { index, group in
                        separated(index) {
                            section(
                                product: group.product,
                                purposes: group.purposes,
                                keyProductUuid: group.product.uuid,
                                locked: viewModel.consentedProducts[group.product.uuid] ?? false,
                                onSelect: { viewModel.handleProductCheckboxChange(group.product.uuid, to: $0) }
                            ) {
                                ForEach(group.purposes, id: \.uuid) { purpose in
                                    row(purpose, productUuid: group.product.uuid, locked: viewModel.isRowLocked(purpose.uuid, productUuid: group.product.uuid))
                                }
                            }
                        }
                    }
                } else if let product = viewModel.soleProduct {
                    section(
                        product: product,
                        purposes: ac.purposes,
                        keyProductUuid: nil,
                        locked: viewModel.soleProductLocked,
                        onSelect: { viewModel.handleSoleProductCheckboxChange(to: $0) }
                    ) {
                        singleList
                    }
                } else {
                    singleList
                }
            }
        }
    }

    @ViewBuilder
    private var singleList: some View {
        ForEach(Array(listedPurposes.enumerated()), id: \.element.id) { index, item in
            separated(index) {
                row(item.purpose, productUuid: nil, locked: isListedLocked(item))
            }
        }
    }

    /// Glass groups the purposes on one panel, rows split by hairlines.
    @ViewBuilder
    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let paint = theme.purposesPanel {
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: paint.radius).fill(paint.fill))
                .overlay(RoundedRectangle(cornerRadius: paint.radius).stroke(paint.edge ?? .clear, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: paint.radius))
        } else {
            VStack(spacing: 10) { content() }
        }
    }

    @ViewBuilder
    private func separated<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        if index > 0, let hairline = theme.rowSeparator {
            VStack(spacing: 0) {
                Rectangle().fill(hairline).frame(height: 1)
                content()
            }
        } else {
            content()
        }
    }

    private func section<Rows: View>(
        product: NoticeProduct,
        purposes: [ActiveConfigPurpose],
        keyProductUuid: String?,
        locked: Bool,
        onSelect: @escaping (Bool) -> Void,
        @ViewBuilder rows: @escaping () -> Rows
    ) -> some View {
        ProductSectionView(
            name: viewModel.productName(product),
            isRequired: viewModel.productIsRequired(product.uuid),
            summary: viewModel.sectionSummary(for: purposes, keyProductUuid: keyProductUuid),
            collapsed: viewModel.collapsedProducts[product.uuid] ?? false,
            locked: locked,
            settings: viewModel.settings,
            accentColor: accentColor,
            selectionControl: control,
            onToggleCollapse: { viewModel.toggleProductCollapse(product.uuid) },
            onSelect: onSelect,
            rows: rows
        )
    }

    private func row(_ purpose: ActiveConfigPurpose, productUuid: String?, locked: Bool) -> some View {
        PurposeItemView(
            purpose: purpose,
            selectedPurposes: viewModel.selectedPurposes,
            collapsedPurposes: viewModel.collapsedPurposes,
            selectedDataElements: viewModel.selectedDataElements,
            settings: viewModel.settings,
            primaryColor: viewModel.activeConfig?.primaryColor,
            onPurposeToggle: { viewModel.handlePurposeToggle($0, productUuid: productUuid) },
            onPurposeCollapse: { viewModel.handlePurposeCollapse($0, productUuid: productUuid) },
            onDataElementToggle: { viewModel.handleDataElementToggle($0, purposeUuid: $1, productUuid: productUuid) },
            getTranslatedText: viewModel.getTranslatedText,
            isAlreadyConsented: locked,
            initialDataElementSelections: viewModel.initialDataElementSelections,
            activeTTSSegmentKey: viewModel.activeTTSSegmentKey,
            productUuid: productUuid,
            selectionControl: control,
            recordedAnswer: viewModel.recordedAnswer(forPurpose: purpose.uuid, productUuid: productUuid)
        )
        .id("\(ProductMatrix.productPurposeKey(productUuid, purpose.uuid))-\(viewModel.selectedLanguage)")
    }
}
