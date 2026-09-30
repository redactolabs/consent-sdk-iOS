import Foundation

struct CategorizedPurposes {
    let alreadyConsented: [ActiveConfigPurpose]
    let needsConsent: [ActiveConfigPurpose]
}

enum ProductConsent {
    static func isBlockingRequiredElement(_ element: ActiveConfigDataElement) -> Bool {
        element.required && element.enabled
    }

    static func hasRequiredDataElement(_ purpose: ActiveConfigPurpose) -> Bool {
        purpose.dataElements.contains(where: isBlockingRequiredElement)
    }

    static func rowKey(_ row: NoticePurposeRow) -> String {
        ProductMatrix.productPurposeKey(row.productUuid, row.purpose.uuid)
    }

    static func recordedSelectionLookup(
        purposeSelections: [String: PurposeSelection]?,
        productPurposeSelections: [String: [String: PurposeSelection]]?
    ) -> RecordedLookup {
        { purposeUuid, productUuid in
            if let productUuid, let perProduct = productPurposeSelections?[productUuid]?[purposeUuid] {
                return perProduct
            }
            return purposeSelections?[purposeUuid]
        }
    }

    static func seedSelection(rows: [NoticePurposeRow], recordedFor: @escaping RecordedLookup) -> SelectionState {
        var selectedPurposes: [String: Bool] = [:]
        var selectedDataElements: [String: Bool] = [:]
        for row in rows {
            let recorded = recordedFor(row.purpose.uuid, row.productUuid)
            selectedPurposes[rowKey(row)] = recorded?.selected ?? false
            for element in row.purpose.dataElements {
                let key = dataElementKey(purposeUuid: row.purpose.uuid, elementUuid: element.uuid, productUuid: row.productUuid)
                selectedDataElements[key] = recorded?.dataElements[element.uuid]?.selected ?? false
            }
        }
        return SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
    }

    static func collapseEveryRow(_ rows: [NoticePurposeRow]) -> [String: Bool] {
        Dictionary(rows.map { (rowKey($0), true) }, uniquingKeysWith: { first, _ in first })
    }

    static func initialCollapsedProducts(
        groups: [ProductPurposeGroup],
        defaultOpenProducts: [String]?
    ) -> [String: Bool] {
        let openByDefault = Set(defaultOpenProducts ?? [])
        let soleSection = groups.count == 1
        var collapsed: [String: Bool] = [:]
        for group in groups {
            collapsed[group.product.uuid] = !soleSection && !openByDefault.contains(group.product.uuid)
        }
        return collapsed
    }

    static func recordedBaseline(rows: [NoticePurposeRow], recordedFor: @escaping RecordedLookup) -> [String: Bool] {
        var baseline: [String: Bool] = [:]
        for row in rows {
            guard let recorded = recordedFor(row.purpose.uuid, row.productUuid) else {
                baseline[rowKey(row)] = false
                continue
            }
            baseline[rowKey(row)] = recorded.selected
                && (recorded.status.isEmpty || recorded.status == PurposeStatus.active)
                && !recorded.needsReconsent
        }
        return baseline
    }

    static func settleProducts(
        rows: [NoticePurposeRow],
        products: [NoticeProduct]?,
        recordedFor: @escaping RecordedLookup
    ) -> SettledProducts {
        func isSettled(_ row: NoticePurposeRow) -> Bool {
            guard let recorded = recordedFor(row.purpose.uuid, row.productUuid) else { return false }
            return recorded.selected && !recorded.needsReconsent
        }

        var consentedPurposes: [String: Bool] = [:]
        var productOrder: [String] = []
        var rowsByProduct: [String: [NoticePurposeRow]] = [:]
        for row in rows {
            guard let resolved = ProductMatrix.rowProductUuid(row.productUuid, products) else { continue }
            consentedPurposes[rowKey(row)] = isSettled(row)
            if rowsByProduct[resolved] == nil { productOrder.append(resolved) }
            rowsByProduct[resolved, default: []].append(row)
        }

        var consentedProducts: [String: Bool] = [:]
        for productUuid in productOrder {
            let group = rowsByProduct[productUuid] ?? []
            let mandatory = group.filter { hasRequiredDataElement($0.purpose) }
            let deciding = mandatory.isEmpty ? group : mandatory
            consentedProducts[productUuid] = deciding.allSatisfy(isSettled)
        }

        return SettledProducts(consentedProducts: consentedProducts, consentedPurposes: consentedPurposes)
    }

    /// Whether a review-mode notice has nothing left to offer: every rendered
    /// row recorded as selected. Deliberately not the per-product settled
    /// rule, which also asks that nothing needs reconsent.
    static func isFullyConsented(rows: [NoticePurposeRow], recordedFor: @escaping RecordedLookup) -> Bool {
        !rows.isEmpty && rows.allSatisfy { recordedFor($0.purpose.uuid, $0.productUuid)?.selected == true }
    }

    static let expiredStatus = "EXPIRED"

    /// The reconsent split, over the flat per-purpose record, in render order.
    /// A purpose can land in both lists (an EXPIRED grant the server is not
    /// asking back), and then renders in both.
    static func categorize(
        purposes: [ActiveConfigPurpose],
        purposeSelections: [String: PurposeSelection]?
    ) -> CategorizedPurposes {
        CategorizedPurposes(
            alreadyConsented: purposes.filter { purpose in
                guard let selection = purposeSelections?[purpose.uuid] else { return false }
                return (selection.status == PurposeStatus.active || selection.status == expiredStatus)
                    && !selection.needsReconsent
            },
            needsConsent: purposes.filter { purpose in
                guard let selection = purposeSelections?[purpose.uuid] else { return true }
                return selection.status != PurposeStatus.active || selection.needsReconsent
            }
        )
    }

    /// The recorded data-element state of the rows `include` admits: what a
    /// locked row's ticks and a reconsent edit are read against.
    static func recordedElementSelections(
        rows: [NoticePurposeRow],
        recordedFor: @escaping RecordedLookup,
        include: (NoticePurposeRow) -> Bool
    ) -> [String: Bool] {
        var selections: [String: Bool] = [:]
        for row in rows where include(row) {
            let recorded = recordedFor(row.purpose.uuid, row.productUuid)
            for element in row.purpose.dataElements {
                selections["\(rowKey(row))-\(element.uuid)"] = recorded?.dataElements[element.uuid]?.selected ?? false
            }
        }
        return selections
    }

    /// The rows whose edited data elements submit them as selected: only an
    /// already-consented purpose on a reconsent, narrowed by the pair-keyed
    /// record so one product's grant does not reach another's row.
    static func modificationBaseline(
        rows: [NoticePurposeRow],
        categorized: CategorizedPurposes?,
        recordedPurposeSelections: [String: Bool]
    ) -> [String: Bool] {
        guard let categorized else { return [:] }
        let consented = Set(categorized.alreadyConsented.map(\.uuid))
        var baseline: [String: Bool] = [:]
        for row in rows {
            baseline[rowKey(row)] = consented.contains(row.purpose.uuid) && recordedPurposeSelections[rowKey(row)] == true
        }
        return baseline
    }

    static func productBoxPurposes(_ purposes: [ActiveConfigPurpose]) -> [ActiveConfigPurpose] {
        let required = purposes.filter(hasRequiredDataElement)
        return required.isEmpty ? purposes : required
    }

    static func sectionSummary(
        purposes: [ActiveConfigPurpose],
        keyProductUuid: String?,
        selectedPurposes: [String: Bool]
    ) -> ProductSectionSummary {
        let boxPurposes = productBoxPurposes(purposes)
        let selectedCount = boxPurposes.filter {
            selectedPurposes[ProductMatrix.productPurposeKey(keyProductUuid, $0.uuid)] == true
        }.count
        return ProductSectionSummary(
            purposeCount: boxPurposes.count,
            requiredOnly: boxPurposes.count < purposes.count,
            allSelected: !boxPurposes.isEmpty && selectedCount == boxPurposes.count,
            someSelected: selectedCount > 0
        )
    }

    static func purposeToggle(
        purpose: ActiveConfigPurpose,
        productUuid: String?,
        selectedPurposes: [String: Bool]
    ) -> SelectionState {
        let key = ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
        let nextState = !(selectedPurposes[key] ?? false)
        var selectedDataElements: [String: Bool] = [:]
        for element in purpose.dataElements {
            selectedDataElements["\(key)-\(element.uuid)"] = element.enabled ? nextState : false
        }
        return SelectionState(selectedPurposes: [key: nextState], selectedDataElements: selectedDataElements)
    }

    static func sectionToggle(
        sectionPurposes: [ActiveConfigPurpose],
        keyProductUuid: String?,
        selectedPurposes: [String: Bool],
        target: Bool? = nil
    ) -> SelectionState {
        let nextState = target ?? !sectionPurposes.allSatisfy {
            selectedPurposes[ProductMatrix.productPurposeKey(keyProductUuid, $0.uuid)] == true
        }
        var purposeOverrides: [String: Bool] = [:]
        var elementOverrides: [String: Bool] = [:]
        for purpose in sectionPurposes {
            let key = ProductMatrix.productPurposeKey(keyProductUuid, purpose.uuid)
            purposeOverrides[key] = nextState
            for element in purpose.dataElements {
                elementOverrides["\(key)-\(element.uuid)"] = element.enabled ? nextState : false
            }
        }
        return SelectionState(selectedPurposes: purposeOverrides, selectedDataElements: elementOverrides)
    }

    static func purposeCheckedFromElements(
        purpose: ActiveConfigPurpose,
        productUuid: String?,
        selectedDataElements: [String: Bool]
    ) -> Bool {
        let key = ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
        let isTicked: (ActiveConfigDataElement) -> Bool = { selectedDataElements["\(key)-\($0.uuid)"] == true }
        let requiredElements = purpose.dataElements.filter(isBlockingRequiredElement)
        return requiredElements.isEmpty
            ? purpose.dataElements.contains(where: isTicked)
            : requiredElements.allSatisfy(isTicked)
    }

    static func confirmVerdict(
        products: [NoticeProduct]?,
        purposes: [ActiveConfigPurpose],
        rows: [NoticePurposeRow],
        selectedPurposes: [String: Bool],
        recordedPurposeSelections: [String: Bool]
    ) -> ConfirmVerdict {
        if rows.isEmpty { return ConfirmVerdict(ok: true, reason: .ok) }

        let isSelected: (NoticePurposeRow) -> Bool = { selectedPurposes[rowKey($0)] == true }
        let wasRecorded: (NoticePurposeRow) -> Bool = { recordedPurposeSelections[rowKey($0)] == true }
        let isMandatory: (NoticePurposeRow) -> Bool = { hasRequiredDataElement($0.purpose) }
        let satisfies: ([NoticePurposeRow]) -> Bool = { group in group.filter(isMandatory).allSatisfy(isSelected) }
        let touched: ([NoticePurposeRow]) -> Bool = { group in
            group.contains(where: isSelected) && group.contains { isSelected($0) != wasRecorded($0) }
        }

        var productOrder: [String] = []
        var rowsByProduct: [String: [NoticePurposeRow]] = [:]
        var unresolved: [NoticePurposeRow] = []
        for row in rows {
            guard let productUuid = ProductMatrix.rowProductUuid(row.productUuid, products) else {
                unresolved.append(row)
                continue
            }
            if rowsByProduct[productUuid] == nil { productOrder.append(productUuid) }
            rowsByProduct[productUuid, default: []].append(row)
        }

        if !ProductMatrix.serverMarksMandatoryProducts(products) {
            var groups = productOrder.map { rowsByProduct[$0] ?? [] }
            if !unresolved.isEmpty { groups.append(unresolved) }
            let everyProductHasMandatory = groups.allSatisfy { $0.contains(where: isMandatory) }
            let baseline = everyProductHasMandatory ? groups.contains(where: satisfies) : satisfies(rows)
            let blocking = productOrder.filter { productUuid in
                let group = rowsByProduct[productUuid] ?? []
                return touched(group) && !satisfies(group)
            }
            let ok = baseline && blocking.isEmpty
            let reason: ConfirmReason = ok ? .ok : (blocking.isEmpty ? .requiredOutstanding : .productIncomplete)
            return ConfirmVerdict(ok: ok, reason: reason, blocking: blocking)
        }

        if !unresolved.isEmpty && productOrder.isEmpty {
            let ok = satisfies(unresolved)
            return ConfirmVerdict(ok: ok, reason: ok ? .ok : .requiredOutstanding)
        }

        let gated = ProductMatrix.gatedProductUuids(products)
        let scoped = ProductMatrix.noticeScopesPurposes(purposes)
        let engagingRows: ([NoticePurposeRow], String) -> [NoticePurposeRow] = { group, productUuid in
            scoped ? group.filter { ProductMatrix.purposeNamesProduct($0.purpose, productUuid) } : group
        }

        let engaged = productOrder.filter { productUuid in
            gated.contains(productUuid) || touched(engagingRows(rowsByProduct[productUuid] ?? [], productUuid))
        }

        if engaged.isEmpty {
            return ConfirmVerdict(ok: false, reason: rows.contains(where: isSelected) ? .nothingEngaged : .nothingChosen)
        }

        let blocking = engaged.filter { !satisfies(rowsByProduct[$0] ?? []) }
        return ConfirmVerdict(ok: blocking.isEmpty, reason: blocking.isEmpty ? .ok : .productIncomplete, blocking: blocking)
    }

    static func confirmHint(
        _ verdict: ConfirmVerdict,
        products: [NoticeProduct]?,
        productName: (NoticeProduct) -> String
    ) -> String? {
        if verdict.ok { return nil }
        switch verdict.reason {
        case .ok:
            return nil
        case .nothingChosen:
            return ConfirmHintCopy.nothingChosen
        case .nothingEngaged:
            return ConfirmHintCopy.nothingEngaged
        case .requiredOutstanding:
            return ConfirmHintCopy.requiredOutstanding
        case .productIncomplete:
            let byUuid = Dictionary((products ?? []).map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
            let names = verdict.blocking.map { uuid in byUuid[uuid].map(productName) ?? uuid }
            return ConfirmHintCopy.productsIncomplete(names)
        }
    }

    static func selectionForMode(
        rows: [NoticePurposeRow],
        mode: AcceptMode,
        current: SelectionState
    ) -> SelectionState {
        if mode == .selected { return current }
        var selectedPurposes: [String: Bool] = [:]
        var selectedDataElements: [String: Bool] = [:]
        for row in rows {
            selectedPurposes[rowKey(row)] = true
            for element in row.purpose.dataElements {
                let key = dataElementKey(purposeUuid: row.purpose.uuid, elementUuid: element.uuid, productUuid: row.productUuid)
                selectedDataElements[key] = element.enabled
            }
        }
        return SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
    }

    static func submissionPurposes(
        rows: [NoticePurposeRow],
        selection: SelectionState,
        mode: AcceptMode,
        recordedPurposeSelections: [String: Bool],
        initialDataElementSelections: [String: Bool]
    ) -> [Purpose] {
        rows.map { row in
            let key = rowKey(row)
            let elementKey: (ActiveConfigDataElement) -> String = { "\(key)-\($0.uuid)" }
            var purposeSelected = selection.selectedPurposes[key] ?? false

            if mode == .selected && recordedPurposeSelections[key] == true {
                let wasModified = row.purpose.dataElements.contains { element in
                    (selection.selectedDataElements[elementKey(element)] ?? false)
                        != (initialDataElementSelections[elementKey(element)] ?? false)
                }
                if wasModified { purposeSelected = true }
            }

            return Purpose(
                uuid: row.purpose.uuid,
                name: row.purpose.name,
                description: row.purpose.description,
                industries: row.purpose.industries,
                selected: purposeSelected,
                dataElements: row.purpose.dataElements.map { element in
                    DataElement(
                        uuid: element.uuid,
                        name: element.name,
                        description: element.description,
                        industries: element.industries,
                        enabled: element.enabled,
                        required: element.required,
                        selected: isBlockingRequiredElement(element)
                            ? true
                            : (selection.selectedDataElements[elementKey(element)] ?? false)
                    )
                },
                productUuid: row.productUuid
            )
        }
    }
}
