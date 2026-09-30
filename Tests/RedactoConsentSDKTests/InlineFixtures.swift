import Foundation
@testable import RedactoConsentSDK

enum InlineFixtures {
    static let productA = "prod-a"
    static let productB = "prod-b"

    static func element(_ uuid: String, required: Bool = false, enabled: Bool = true) -> ActiveConfigDataElement {
        ActiveConfigDataElement(uuid: uuid, name: uuid, description: nil, industries: nil, enabled: enabled, required: required)
    }

    static func purpose(_ uuid: String, _ productUuids: [String]?, _ elements: [ActiveConfigDataElement]) -> ActiveConfigPurpose {
        ActiveConfigPurpose(
            uuid: uuid,
            name: uuid,
            description: "\(uuid) description",
            industries: nil,
            dataElements: elements,
            productUuids: productUuids
        )
    }

    static let shared = purpose("pur-shared", [productA, productB], [
        element("el-email", required: true),
        element("el-phone"),
    ])
    static let scopedA = purpose("pur-scoped-a", [productA], [element("el-address", required: true)])
    static let onlyB = purpose("pur-only-b", [productB], [element("el-device")])
    static let wide = purpose("pur-wide", nil, [
        element("el-cookie"),
        element("el-legacy", required: true, enabled: false),
    ])

    static let twoProducts = [
        NoticeProduct(uuid: productA, name: "Product A"),
        NoticeProduct(uuid: productB, name: "Product B"),
    ]

    static func config(
        products: [NoticeProduct]?,
        purposes: [ActiveConfigPurpose],
        order: [String: [String]]? = nil,
        uuid: String = "cfg-1",
        defaultLanguage: String = "en",
        translations: [String: LanguageTranslation] = [:]
    ) -> ActiveConfig {
        ActiveConfig(
            uuid: uuid,
            noticeUuid: "ntc-1",
            organisationUuid: "org-1",
            workspaceUuid: "ws-1",
            version: 1,
            status: "active",
            noticeText: "Notice",
            additionalText: "",
            acceptAllButtonText: nil,
            confirmButtonText: "Accept",
            declineButtonText: "Decline",
            logoUrl: "",
            privacyPolicyUrl: "",
            privacyCenterUrl: "",
            primaryColor: "#000000",
            secondaryColor: "#ffffff",
            fontPreference: "default",
            purposes: purposes,
            defaultLanguage: defaultLanguage,
            supportedLanguagesAndTranslations: translations,
            createdAt: "2024-01-01T00:00:00.000Z",
            updatedAt: "2024-01-01T00:00:00.000Z",
            deployedAt: "2024-01-01T00:00:00.000Z",
            privacyPolicyPrefixText: "Read",
            privacyPolicyAnchorText: "Policy",
            privacyCenterAnchorText: nil,
            purposeSectionHeading: "Purposes",
            noticeBannerHeading: "Privacy Notice",
            dpoInfo: nil,
            products: products,
            productPurposeOrder: order
        )
    }

    static let multiProduct = config(products: twoProducts, purposes: [shared, scopedA, onlyB, wide])

    static func content(_ config: ActiveConfig) -> ConsentContent {
        ConsentContent(
            code: 200,
            status: "success",
            detail: ConsentDetail(
                uuid: "ntc-1",
                name: "Notice",
                organisationUuid: "org-1",
                workspaceUuid: "ws-1",
                collectionPointUuids: [],
                collectionPoints: [],
                activeConfig: config,
                noticeType: nil,
                complianceRequirement: nil,
                isMinor: false,
                purposeSelections: nil,
                reconsentRequired: false,
                createdAt: "2024-01-01T00:00:00.000Z",
                updatedAt: "2024-01-01T00:00:00.000Z"
            )
        )
    }

    static func noticeResponse(_ config: ActiveConfig) -> TransportStubResponse {
        let data = (try? JSONEncoder().encode(content(config))) ?? Data()
        return TransportStubResponse(status: 200, body: data, failure: nil)
    }
}

final class RouteStub {
    private let lock = NSLock()
    private var routes: [String: [TransportStubResponse]]

    init(_ routes: [String: [TransportStubResponse]]) {
        self.routes = routes
    }

    static func install(_ routes: [String: [TransportStubResponse]]) {
        let stub = RouteStub(routes)
        TransportStubProtocol.install { stub.respond(to: $0) }
    }

    static func requests(matching fragment: String) -> [TransportStubRequest] {
        TransportStubProtocol.requests.filter { $0.url.absoluteString.contains(fragment) }
    }

    func respond(to request: TransportStubRequest) -> TransportStubResponse {
        lock.lock()
        defer { lock.unlock() }
        let url = request.url.absoluteString
        let keys = routes.keys.sorted { $0.count > $1.count }
        guard let key = keys.first(where: { url.contains($0) }), var queue = routes[key], !queue.isEmpty else {
            return .empty(404)
        }
        let next = queue[0]
        if queue.count > 1 {
            queue.removeFirst()
            routes[key] = queue
        }
        return next
    }
}

extension TransportStubRequest {
    var json: [String: Any] {
        jsonBody ?? [:]
    }
}

func sortedJSON(_ data: Data?) -> String {
    guard let data,
          let object = try? JSONSerialization.jsonObject(with: data),
          let sorted = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "" }
    return String(data: sorted, encoding: .utf8) ?? ""
}

func sortedJSONObject(_ object: Any) -> String {
    guard let sorted = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "" }
    return String(data: sorted, encoding: .utf8) ?? ""
}

final class FlowCounter {
    var accepts = 0
    var completes = 0
    var declines = 0
    var errors = 0
}
