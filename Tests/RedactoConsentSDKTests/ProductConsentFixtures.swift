import Foundation
@testable import RedactoConsentSDK

enum ProductFixtures {
    static let a = "prod-a"
    static let b = "prod-b"

    static func element(_ uuid: String, required: Bool, enabled: Bool = true) -> ActiveConfigDataElement {
        ActiveConfigDataElement(uuid: uuid, name: uuid, description: nil, industries: nil, enabled: enabled, required: required)
    }

    static func purpose(_ uuid: String, _ productUuids: [String]?, elements: [ActiveConfigDataElement]) -> ActiveConfigPurpose {
        ActiveConfigPurpose(uuid: uuid, name: uuid, description: "", industries: nil, dataElements: elements, productUuids: productUuids)
    }

    static func mandatoryPurpose(_ uuid: String, _ productUuids: [String]) -> ActiveConfigPurpose {
        purpose(uuid, productUuids, elements: [element("\(uuid)-req", required: true), element("\(uuid)-opt", required: false)])
    }

    static func optionalPurpose(_ uuid: String, _ productUuids: [String]) -> ActiveConfigPurpose {
        purpose(uuid, productUuids, elements: [element("\(uuid)-opt", required: false)])
    }

    static func products(_ aMandatory: Bool? = nil, _ bMandatory: Bool? = nil) -> [NoticeProduct] {
        [
            NoticeProduct(uuid: a, name: "Product A", mandatory: aMandatory),
            NoticeProduct(uuid: b, name: "Product B", mandatory: bMandatory),
        ]
    }

    static func sole(_ mandatory: Bool? = nil) -> [NoticeProduct] {
        [NoticeProduct(uuid: a, name: "Product A", mandatory: mandatory)]
    }

    static let shared = mandatoryPurpose("shared-req", [a, b])
    static let aReq = mandatoryPurpose("a-req", [a])
    static let aOpt = optionalPurpose("a-opt", [a])
    static let bOpt = optionalPurpose("b-opt", [b])
    static let bReq = mandatoryPurpose("b-req", [b])
    static let wideReq = mandatoryPurpose("wide-req", [])
    static let wideOpt = optionalPurpose("wide-opt", [])

    static func key(_ productUuid: String?, _ purpose: ActiveConfigPurpose) -> String {
        ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
    }

    static func selection(
        selected: Bool = true,
        status: String = "ACTIVE",
        needsReconsent: Bool = false,
        dataElements: [String: DataElementSelection] = [:]
    ) -> PurposeSelection {
        PurposeSelection(selected: selected, status: status, needsReconsent: needsReconsent, dataElements: dataElements)
    }

    static func verdict(
        _ productList: [NoticeProduct]?,
        _ purposes: [ActiveConfigPurpose],
        ticked: [String] = [],
        recorded: [String: Bool] = [:]
    ) -> ConfirmVerdict {
        ProductConsent.confirmVerdict(
            products: productList,
            purposes: purposes,
            rows: ProductMatrix.noticePurposeRows(productList, purposes),
            selectedPurposes: Dictionary(ticked.map { ($0, true) }, uniquingKeysWith: { first, _ in first }),
            recordedPurposeSelections: recorded
        )
    }
}
