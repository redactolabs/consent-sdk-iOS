import XCTest
@testable import RedactoConsentSDK

final class InlineSubmitPayloadTests: XCTestCase {
    private typealias F = InlineFixtures
    private let python = "https://api.example.test/consent"

    private let todaysSingleProductBody =
        #"{"declined":false,"meta_data":{"specific_uuid":"app-1"},"notice_uuid":"ntc-1","purposes":[{"data_elements":[{"selected":true,"uuid":"el-email"},{"selected":true,"uuid":"el-phone"}],"purpose_uuid":"pur-1","selected":true},{"data_elements":[{"selected":false,"uuid":"el-device"}],"purpose_uuid":"pur-2","selected":false},{"purpose_uuid":"pur-3","selected":true}],"select_all_mandatory":false,"source":"MOBILE"}"#

    private let singleProductPurposes = [
        InlineFixtures.purpose("pur-1", ["prod-only"], [
            InlineFixtures.element("el-email", required: true),
            InlineFixtures.element("el-phone"),
            InlineFixtures.element("el-fax", enabled: false),
        ]),
        InlineFixtures.purpose("pur-2", nil, [InlineFixtures.element("el-device")]),
        InlineFixtures.purpose("pur-3", nil, []),
    ]

    override func setUp() {
        super.setUp()
        RouteStub.install(["submit-consent": [.text(201, "{}")]])
    }

    override func tearDown() {
        TransportStubProtocol.uninstall()
        super.tearDown()
    }

    private func send(_ config: ActiveConfig, _ state: SelectionState) async throws -> TransportStubRequest? {
        try await ConsentAPI.submitConsentEvent(.init(
            accessToken: "tok",
            baseUrl: python,
            noticeUuid: "ntc-1",
            purposes: InlineSelection.buildInlineSubmitPurposes(InlineSelection.inlinePurposeRows(config), state),
            declined: false,
            metaData: MetaData(specificUuid: "app-1"),
            orgUuid: "org-1",
            workspaceUuid: "ws-1"
        ))
        return RouteStub.requests(matching: "submit-consent").last
    }

    private func tickElement(
        _ state: SelectionState,
        _ purpose: ActiveConfigPurpose,
        _ elementUuid: String,
        _ productUuid: String? = nil
    ) -> SelectionState {
        let toggled = InlineSelection.toggleDataElement(purpose, elementUuid, productUuid, state.selectedDataElements)
        var purposes = state.selectedPurposes
        purposes[ProductMatrix.productPurposeKey(productUuid, purpose.uuid)] = toggled.purposeSelected
        return SelectionState(selectedPurposes: purposes, selectedDataElements: toggled.selectedDataElements)
    }

    func testSendsTodaysBytesForASingleProductNotice() async throws {
        for products in [nil, [NoticeProduct(uuid: "prod-only", name: "Only product")]] as [[NoticeProduct]?] {
            let config = F.config(products: products, purposes: singleProductPurposes)
            var state = InlineSelection.initialSelection(InlineSelection.inlinePurposeRows(config))
            state = tickElement(state, singleProductPurposes[0], "el-phone")
            var purposes = state.selectedPurposes
            purposes["pur-3"] = true
            state = SelectionState(selectedPurposes: purposes, selectedDataElements: state.selectedDataElements)

            let request = try await send(config, state)
            let body = try XCTUnwrap(try XCTUnwrap(request).body)
            XCTAssertEqual(sortedJSON(body), todaysSingleProductBody)
            XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("product_uuid"))
        }
    }

    func testCarriesEachRowsProductOnAMultiProductNotice() async throws {
        let shared = F.purpose("pur-shared", [F.productA, F.productB], [F.element("el-email", required: true)])
        let scoped = F.purpose("pur-scoped-a", [F.productA], [F.element("el-address")])
        let config = F.config(products: F.twoProducts, purposes: [shared, scoped])
        var state = InlineSelection.initialSelection(InlineSelection.inlinePurposeRows(config))
        state = tickElement(state, shared, "el-email", F.productB)

        let sent = try await send(config, state)
        let request = try XCTUnwrap(sent)
        XCTAssertEqual(request.url.absoluteString, "\(python)/public/organisations/org-1/workspaces/ws-1/submit-consent")
        let purposes = try XCTUnwrap(request.json["purposes"])
        XCTAssertEqual(
            sortedJSONObject(purposes),
            #"[{"data_elements":[{"selected":true,"uuid":"el-email"}],"product_uuid":"prod-a","purpose_uuid":"pur-shared","selected":false},{"data_elements":[{"selected":false,"uuid":"el-address"}],"product_uuid":"prod-a","purpose_uuid":"pur-scoped-a","selected":false},{"data_elements":[{"selected":true,"uuid":"el-email"}],"product_uuid":"prod-b","purpose_uuid":"pur-shared","selected":true}]"#
        )
    }
}
