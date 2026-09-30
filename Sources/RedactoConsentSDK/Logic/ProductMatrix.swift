import Foundation

enum ProductMatrix {
    static func productPurposeKey(_ productUuid: String?, _ purposeUuid: String) -> String {
        guard let productUuid, !productUuid.isEmpty else { return purposeUuid }
        return "\(productUuid):\(purposeUuid)"
    }

    static func purposeCoversProduct(_ purpose: ActiveConfigPurpose, _ productUuid: String) -> Bool {
        guard let scope = purpose.productUuids, !scope.isEmpty else { return true }
        return scope.contains(productUuid)
    }

    static func isMultiProduct(_ products: [NoticeProduct]?) -> Bool {
        (products?.count ?? 0) > 1
    }

    static func purposeNamesProduct(_ purpose: ActiveConfigPurpose, _ productUuid: String) -> Bool {
        purpose.productUuids?.contains(productUuid) == true
    }

    static func noticeScopesPurposes(_ purposes: [ActiveConfigPurpose]) -> Bool {
        purposes.contains { ($0.productUuids?.count ?? 0) > 0 }
    }

    static func serverMarksMandatoryProducts(_ products: [NoticeProduct]?) -> Bool {
        guard let products, !products.isEmpty else { return false }
        return products.allSatisfy { $0.mandatory != nil }
    }

    static func gatedProductUuids(_ products: [NoticeProduct]?) -> Set<String> {
        Set((products ?? []).filter { $0.mandatory == true }.map(\.uuid))
    }

    static func rowProductUuid(_ rowProductUuid: String?, _ products: [NoticeProduct]?) -> String? {
        if let rowProductUuid { return rowProductUuid }
        guard let products, products.count == 1 else { return nil }
        return products[0].uuid
    }

    static func productIsRequired(_ productUuid: String?, _ products: [NoticeProduct]?) -> Bool {
        guard serverMarksMandatoryProducts(products),
              let resolved = rowProductUuid(productUuid, products) else { return false }
        return gatedProductUuids(products).contains(resolved)
    }

    static func rowsUnderGate(_ rows: [NoticePurposeRow], _ products: [NoticeProduct]?) -> [NoticePurposeRow] {
        let gated = gatedProductUuids(products)
        guard !gated.isEmpty else { return [] }
        return rows.filter { row in
            guard let productUuid = rowProductUuid(row.productUuid, products) else { return false }
            return gated.contains(productUuid)
        }
    }

    static func mandatoryProductsFirst(_ products: [NoticeProduct]) -> [NoticeProduct] {
        let mandatory = products.filter { $0.mandatory == true }
        if mandatory.isEmpty || mandatory.count == products.count { return products }
        return mandatory + products.filter { $0.mandatory != true }
    }

    static func groupPurposesByProduct(
        _ products: [NoticeProduct]?,
        _ purposes: [ActiveConfigPurpose],
        order: [String: [String]]? = nil
    ) -> [ProductPurposeGroup] {
        guard let products, !products.isEmpty else { return [] }

        return mandatoryProductsFirst(products)
            .map { product in
                let covered = purposes.filter { purposeCoversProduct($0, product.uuid) }
                return ProductPurposeGroup(product: product, purposes: inSavedOrder(covered, order?[product.uuid]))
            }
            .filter { !$0.purposes.isEmpty }
    }

    /// The saved uuids first, then any purpose the order does not name, in
    /// their own order. No saved order leaves them as they are.
    static func inSavedOrder(_ purposes: [ActiveConfigPurpose], _ saved: [String]?) -> [ActiveConfigPurpose] {
        guard let saved, !saved.isEmpty else { return purposes }
        let byUuid = Dictionary(purposes.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = saved.compactMap { byUuid[$0] }
        let rest = purposes.filter { !saved.contains($0.uuid) }
        return ordered + rest
    }

    static func expandPurposesByProduct(
        _ products: [NoticeProduct]?,
        _ purposes: [ActiveConfigPurpose],
        order: [String: [String]]? = nil
    ) -> [NoticePurposeRow] {
        guard isMultiProduct(products) else { return [] }
        return groupPurposesByProduct(products, purposes, order: order).flatMap { group in
            group.purposes.map { NoticePurposeRow(purpose: $0, productUuid: group.product.uuid) }
        }
    }

    static func noticePurposeRows(
        _ products: [NoticeProduct]?,
        _ purposes: [ActiveConfigPurpose],
        order: [String: [String]]? = nil
    ) -> [NoticePurposeRow] {
        guard isMultiProduct(products) else {
            // Ungrouped, but in the order the admin saved for the sole product.
            let saved = products?.first.flatMap { order?[$0.uuid] }
            return inSavedOrder(purposes, saved).map { NoticePurposeRow(purpose: $0, productUuid: nil) }
        }
        return expandPurposesByProduct(products, purposes, order: order)
    }

    /// Each purpose once, in the order the notice renders them, for everything
    /// that walks purposes rather than rows (the reconsent split, talkback).
    static func purposesInRenderOrder(
        _ products: [NoticeProduct]?,
        _ purposes: [ActiveConfigPurpose],
        order: [String: [String]]? = nil
    ) -> [ActiveConfigPurpose] {
        var seen = Set<String>()
        return noticePurposeRows(products, purposes, order: order).compactMap { row in
            seen.insert(row.purpose.uuid).inserted ? row.purpose : nil
        }
    }
}
