import Foundation

extension ConsentNoticeViewModel {
    var noticeProducts: [NoticeProduct]? { activeConfig?.products }

    var isMultiProduct: Bool { ProductMatrix.isMultiProduct(noticeProducts) }

    var soleProduct: NoticeProduct? {
        guard let products = noticeProducts, products.count == 1 else { return nil }
        return products[0]
    }

    var purposeRows: [NoticePurposeRow] {
        guard let ac = activeConfig else { return [] }
        return ProductMatrix.noticePurposeRows(ac.products, ac.purposes, order: ac.productPurposeOrder)
    }

    /// Each purpose once, in render order: the single-product list follows it.
    var renderedPurposes: [ActiveConfigPurpose] {
        guard let ac = activeConfig else { return [] }
        return ProductMatrix.purposesInRenderOrder(ac.products, ac.purposes, order: ac.productPurposeOrder)
    }

    var productGroups: [ProductPurposeGroup] {
        guard let ac = activeConfig else { return [] }
        return ProductMatrix.groupPurposesByProduct(ac.products, ac.purposes, order: ac.productPurposeOrder)
    }

    var confirmVerdict: ConfirmVerdict {
        guard let ac = activeConfig else { return ConfirmVerdict(ok: false, reason: .nothingChosen) }
        return ProductConsent.confirmVerdict(
            products: ac.products,
            purposes: ac.purposes,
            rows: purposeRows,
            selectedPurposes: selectedPurposes,
            recordedPurposeSelections: recordedPurposeSelections
        )
    }

    var confirmHintText: String? {
        guard !isSubmitting else { return nil }
        return ProductConsent.confirmHint(confirmVerdict, products: noticeProducts) { self.productName($0) }
    }

    var soleProductLocked: Bool {
        guard let product = soleProduct else { return false }
        return consentedProducts[product.uuid] ?? isReviewMode
    }

    /// The rows an Accept Selected edit to their data elements submits as
    /// selected; empty outside a reconsent.
    var modificationBaseline: [String: Bool] {
        ProductConsent.modificationBaseline(
            rows: purposeRows,
            categorized: categorizedPurposes,
            recordedPurposeSelections: recordedPurposeSelections
        )
    }

    func productName(_ product: NoticeProduct) -> String {
        getTranslatedText("products.name", defaultText: product.name, itemId: product.uuid)
    }

    func productIsRequired(_ productUuid: String) -> Bool {
        ProductMatrix.productIsRequired(productUuid, noticeProducts)
    }

    func sectionSummary(for purposes: [ActiveConfigPurpose], keyProductUuid: String?) -> ProductSectionSummary {
        ProductConsent.sectionSummary(purposes: purposes, keyProductUuid: keyProductUuid, selectedPurposes: selectedPurposes)
    }

    /// A grouped notice locks the rows each product has settled. Otherwise a
    /// reconsent locks the purposes already consented to and leaves the rest
    /// editable, and a fully consented review locks everything.
    func isRowLocked(_ purposeUuid: String, productUuid: String?) -> Bool {
        if isMultiProduct {
            return consentedPurposes[ProductMatrix.productPurposeKey(productUuid, purposeUuid)] ?? false
        }
        if let categorizedPurposes {
            return categorizedPurposes.alreadyConsented.contains { $0.uuid == purposeUuid }
        }
        return isReviewMode
    }

    func rowKeys(forPurpose purposeUuid: String) -> [String] {
        purposeRows.filter { $0.purpose.uuid == purposeUuid }.map(ProductConsent.rowKey)
    }

    func seedSelectionState(from data: ConsentContent) {
        let ac = data.detail.activeConfig
        let rows = ProductMatrix.noticePurposeRows(ac.products, ac.purposes, order: ac.productPurposeOrder)
        let recordedFor = recordedLookup(for: data)
        let seeded = PurposePreselectionLogic.seed(
            rows: rows,
            recordedFor: recordedFor,
            mode: PurposePreselectionLogic.resolve(ac.purposePreselection)
        )
        let hasRecord = data.detail.purposeSelections != nil || data.detail.productPurposeSelections != nil
        let reconsentRequired = data.detail.reconsentRequired ?? false
        let categorized = reconsentRequired
            ? ProductConsent.categorize(
                purposes: ProductMatrix.purposesInRenderOrder(ac.products, ac.purposes, order: ac.productPurposeOrder),
                purposeSelections: data.detail.purposeSelections
            )
            : nil
        let rowIsRecorded: (NoticePurposeRow) -> Bool = {
            recordedFor($0.purpose.uuid, $0.productUuid)?.selected == true
        }

        collapsedPurposes = ProductConsent.collapseEveryRow(rows)
        collapsedProducts = ProductConsent.initialCollapsedProducts(
            groups: ProductMatrix.groupPurposesByProduct(ac.products, ac.purposes, order: ac.productPurposeOrder),
            defaultOpenProducts: defaultOpenProducts
        )
        selectedPurposes = seeded.selectedPurposes
        selectedDataElements = seeded.selectedDataElements
        recordedPurposeSelections = ProductConsent.recordedBaseline(rows: rows, recordedFor: recordedFor)
        if hasRecord {
            let settled = ProductConsent.settleProducts(rows: rows, products: ac.products, recordedFor: recordedFor)
            consentedProducts = settled.consentedProducts
            consentedPurposes = settled.consentedPurposes
        }
        categorizedPurposes = categorized
        isReconsentMode = reconsentRequired

        if let categorized {
            let consented = Set(categorized.alreadyConsented.map(\.uuid))
            isReviewMode = false
            initialDataElementSelections = ProductConsent.recordedElementSelections(rows: rows, recordedFor: recordedFor) {
                consented.contains($0.purpose.uuid) || rowIsRecorded($0)
            }
        } else {
            isReviewMode = includeFullyConsentedData && hasRecord
                && ProductConsent.isFullyConsented(rows: rows, recordedFor: recordedFor)
            initialDataElementSelections = ProductConsent.recordedElementSelections(
                rows: rows,
                recordedFor: recordedFor,
                include: rowIsRecorded
            )
        }
    }

    func isFullyConsented(_ data: ConsentContent) -> Bool {
        let ac = data.detail.activeConfig
        let rows = ProductMatrix.noticePurposeRows(ac.products, ac.purposes, order: ac.productPurposeOrder)
        return ProductConsent.isFullyConsented(rows: rows, recordedFor: recordedLookup(for: data))
    }

    func handlePurposeToggle(_ purposeUuid: String, productUuid: String? = nil) {
        guard !otpLocked else { return }
        guard let purpose = activeConfig?.purposes.first(where: { $0.uuid == purposeUuid }) else { return }
        apply(ProductConsent.purposeToggle(purpose: purpose, productUuid: productUuid, selectedPurposes: selectedPurposes))
    }

    func handlePurposeCollapse(_ purposeUuid: String, productUuid: String? = nil) {
        let key = ProductMatrix.productPurposeKey(productUuid, purposeUuid)
        collapsedPurposes[key] = !(collapsedPurposes[key] ?? false)
    }

    func handleDataElementToggle(_ elementUuid: String, purposeUuid: String, productUuid: String? = nil) {
        guard !otpLocked else { return }
        guard let purpose = activeConfig?.purposes.first(where: { $0.uuid == purposeUuid }) else { return }
        let key = ProductMatrix.productPurposeKey(productUuid, purposeUuid)
        let elementKey = "\(key)-\(elementUuid)"
        selectedDataElements[elementKey] = !(selectedDataElements[elementKey] ?? false)
        selectedPurposes[key] = ProductConsent.purposeCheckedFromElements(
            purpose: purpose,
            productUuid: productUuid,
            selectedDataElements: selectedDataElements
        )
    }

    func toggleProductCollapse(_ productUuid: String) {
        collapsedProducts[productUuid] = !(collapsedProducts[productUuid] ?? false)
    }

    func handleProductCheckboxChange(_ productUuid: String, to target: Bool? = nil) {
        guard !otpLocked else { return }
        guard let group = productGroups.first(where: { $0.product.uuid == productUuid }) else { return }
        applySectionToggle(group.purposes, keyProductUuid: productUuid, target: target)
    }

    func handleSoleProductCheckboxChange(to target: Bool? = nil) {
        guard !otpLocked else { return }
        guard let purposes = activeConfig?.purposes else { return }
        apply(ProductConsent.sectionToggle(
            sectionPurposes: ProductConsent.productBoxPurposes(purposes),
            keyProductUuid: nil,
            selectedPurposes: selectedPurposes,
            target: target
        ))
    }

    private func applySectionToggle(_ sectionPurposes: [ActiveConfigPurpose], keyProductUuid: String?, target: Bool?) {
        let editable = ProductConsent.productBoxPurposes(sectionPurposes).filter {
            !isRowLocked($0.uuid, productUuid: keyProductUuid)
        }
        guard !editable.isEmpty else { return }
        apply(ProductConsent.sectionToggle(
            sectionPurposes: editable,
            keyProductUuid: keyProductUuid,
            selectedPurposes: selectedPurposes,
            target: target
        ))
    }

    private func apply(_ overrides: SelectionState) {
        selectedPurposes.merge(overrides.selectedPurposes) { _, next in next }
        selectedDataElements.merge(overrides.selectedDataElements) { _, next in next }
    }

    private func recordedLookup(for data: ConsentContent) -> RecordedLookup {
        ProductConsent.recordedSelectionLookup(
            purposeSelections: data.detail.purposeSelections,
            productPurposeSelections: data.detail.productPurposeSelections
        )
    }
}
