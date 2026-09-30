import XCTest
@testable import RedactoConsentSDK

final class ProductPoliciesTests: XCTestCase {
    private let savings = "3f0b6c1e-8a52-4d0e-9a57-0d1f2c3b4a51"
    private let loans = "9c2d7e4a-1b36-4f8c-8e21-5a6b7c8d9e02"
    private let insurance = "e41a9b7c-6d25-4c3e-b1f0-2a3b4c5d6e73"
    private let unlisted = "5b8e2f1d-0c47-4a9b-9d3e-7f6a5b4c3d24"

    private let savingsPolicy = "https://savings.example.test/privacy"
    private let loansPolicy = "https://loans.example.test/privacy"
    private let insurancePolicy = "https://insurance.example.test/privacy"
    private let noticePolicy = "https://group.example.test/privacy"

    private var productsJSON: [[String: Any]] {
        [
            ["uuid": savings, "name": "Savings Account"],
            ["uuid": loans, "name": "Home Loans"],
            ["uuid": insurance, "name": "Life Insurance"],
        ]
    }

    private var purposeScopes: [String: [String]] {
        ["purpose-marketing": [savings, loans], "purpose-kyc": [insurance], "purpose-analytics": []]
    }

    private var products: [NoticeProduct] {
        [
            NoticeProduct(uuid: savings, name: "Savings Account"),
            NoticeProduct(uuid: loans, name: "Home Loans"),
            NoticeProduct(uuid: insurance, name: "Life Insurance"),
        ]
    }

    private func derive(_ policies: [String: String]?, products: [NoticeProduct]? = nil) -> (links: [ProductPolicyLink], showNoticeLink: Bool) {
        let products = products ?? self.products
        let links = ProductPolicies.links(products: products, policies: policies)
        return (links, ProductPolicies.showsNoticePolicyLink(products: products, links: links))
    }

    @MainActor
    private func notice(policies: Any?, config: [String: Any] = [:]) -> ConsentNoticeViewModel {
        var merged: [String: Any] = ["products": productsJSON, "privacy_policy_url": noticePolicy]
        if let policies {
            merged["product_privacy_policies"] = policies
        }
        for (key, value) in config {
            merged[key] = value
        }
        return makeNotice(content: NoticeFixtures.content(config: merged)).vm
    }

    func testTheFixtureHasASharedPurposeSpanningAProductWithAPolicyAndOneWithout() {
        let policies = [savings: savingsPolicy, insurance: insurancePolicy]
        XCTAssertEqual(purposeScopes["purpose-marketing"], [savings, loans])
        XCTAssertNotNil(policies[savings])
        XCTAssertNil(policies[loans])
    }

    func testLinksOnlyProductsNamingAPolicyByNameInProductOrder() {
        let (links, _) = derive([insurance: insurancePolicy, savings: savingsPolicy])

        XCTAssertEqual(links, [
            ProductPolicyLink(uuid: savings, name: "Savings Account", url: savingsPolicy),
            ProductPolicyLink(uuid: insurance, name: "Life Insurance", url: insurancePolicy),
        ])
    }

    func testNeverPointsAProductWithoutAPolicyAtTheNoticeLevelOne() {
        let (links, _) = derive([savings: savingsPolicy, insurance: insurancePolicy])

        XCTAssertFalse(links.map(\.uuid).contains(loans))
        XCTAssertFalse(links.map(\.url).contains(noticePolicy))
    }

    func testOmitsAProductWhosePolicyIsBlank() {
        let (links, _) = derive([savings: savingsPolicy, loans: "", insurance: "  "])

        XCTAssertEqual(links.map(\.uuid), [savings])
    }

    func testIgnoresAPolicyKeyedByAnUnlistedProduct() {
        let (links, _) = derive([savings: savingsPolicy, unlisted: "https://unlisted.example.test/privacy"])

        XCTAssertEqual(links.map(\.uuid), [savings])
    }

    func testRendersNoLinksForAnEmptyOrAbsentMap() {
        XCTAssertEqual(derive([:]).links, [])
        XCTAssertEqual(derive(nil).links, [])
    }

    func testRendersNoLinksWhenTheNoticeListsNoProducts() {
        XCTAssertEqual(ProductPolicies.links(products: nil, policies: [savings: savingsPolicy]), [])
        XCTAssertEqual(ProductPolicies.links(products: [], policies: [savings: savingsPolicy]), [])
    }

    func testKeepsTheNoticeLinkWhileAProductHasNone() {
        let (links, showNoticeLink) = derive([savings: savingsPolicy, insurance: insurancePolicy])

        XCTAssertEqual(links.count, 2)
        XCTAssertTrue(showNoticeLink)
    }

    func testDropsTheNoticeLinkOnceEveryProductNamesItsOwn() {
        let (links, showNoticeLink) = derive([savings: savingsPolicy, loans: loansPolicy, insurance: insurancePolicy])

        XCTAssertEqual(links.count, 3)
        XCTAssertFalse(showNoticeLink)
    }

    func testKeepsTheNoticeLinkWhenABlankPolicyLeavesAProductUncovered() {
        XCTAssertTrue(derive([savings: savingsPolicy, loans: "", insurance: insurancePolicy]).showNoticeLink)
    }

    func testAnUnlistedProductPolicyDoesNotCountTowardCoveringEveryProduct() {
        let policies = [savings: savingsPolicy, insurance: insurancePolicy, unlisted: loansPolicy]
        XCTAssertEqual(policies.count, products.count)
        XCTAssertTrue(derive(policies).showNoticeLink)
    }

    func testKeepsTheNoticeLinkForAnEmptyOrAbsentMap() {
        XCTAssertTrue(derive([:]).showNoticeLink)
        XCTAssertTrue(derive(nil).showNoticeLink)
    }

    func testKeepsTheNoticeLinkWhenThePayloadCarriesNoProducts() {
        let links = [ProductPolicyLink(uuid: savings, name: "Savings Account", url: savingsPolicy)]
        XCTAssertTrue(ProductPolicies.showsNoticePolicyLink(products: nil, links: links))
        XCTAssertTrue(ProductPolicies.showsNoticePolicyLink(products: [], links: links))
    }

    func testASingleProductNoticeRendersAsBeforeWithoutAPolicy() {
        let single = [NoticeProduct(uuid: savings, name: "Savings Account")]
        for policies in [nil, [:]] as [[String: String]?] {
            let derived = derive(policies, products: single)
            XCTAssertEqual(derived.links, [])
            XCTAssertTrue(derived.showNoticeLink)
        }
    }

    func testASingleProductNoticeSwapsTheNoticeLinkForItsOwn() {
        let single = [NoticeProduct(uuid: savings, name: "Savings Account")]
        let derived = derive([savings: savingsPolicy], products: single)

        XCTAssertEqual(derived.links, [ProductPolicyLink(uuid: savings, name: "Savings Account", url: savingsPolicy)])
        XCTAssertFalse(derived.showNoticeLink)
    }

    func testTheLineReadsLabelThenCommaSeparatedNamesEachLinkingItsOwnPolicy() {
        let (links, _) = derive([insurance: insurancePolicy, savings: savingsPolicy])
        let line = ProductPolicies.line(label: ProductPolicyCopy.label, links: links)

        XCTAssertEqual(String(line.characters), "Privacy policies: Savings Account, Life Insurance")
        let linked = line.runs.compactMap { run -> (String, URL)? in
            guard let url = run.link else { return nil }
            return (String(line[run.range].characters), url)
        }
        XCTAssertEqual(linked.map { $0.0 }, ["Savings Account", "Life Insurance"])
        XCTAssertEqual(linked.map { $0.1.absoluteString }, [savingsPolicy, insurancePolicy])
    }

    func testTheMapDecodesWhenAbsentNullOrEmpty() {
        XCTAssertNil(NoticeFixtures.content(config: [:]).detail.activeConfig.productPrivacyPolicies)
        XCTAssertNil(NoticeFixtures.content(config: ["product_privacy_policies": NSNull()]).detail.activeConfig.productPrivacyPolicies)
        XCTAssertEqual(NoticeFixtures.content(config: ["product_privacy_policies": [String: String]()]).detail.activeConfig.productPrivacyPolicies, [:])
    }

    @MainActor
    func testChangesNothingWhenTheMapIsAbsentNullOrEmpty() {
        for policies in [nil, NSNull(), [String: String]()] as [Any?] {
            let vm = notice(policies: policies)
            XCTAssertTrue(vm.productPolicyLinks.isEmpty)
            XCTAssertTrue(vm.showsNoticePolicyLink)
            XCTAssertFalse(vm.showsNoticeFooter)
        }
    }

    @MainActor
    func testMountsTheFooterForThePoliciesAloneWithNoPrivacyCenterOrDpo() {
        let vm = notice(policies: [savings: savingsPolicy, insurance: insurancePolicy], config: ["privacy_center_url": ""])

        XCTAssertTrue(vm.showsNoticeFooter)
        XCTAssertEqual(vm.productPolicyLinks.map(\.name), ["Savings Account", "Life Insurance"])
        XCTAssertTrue(vm.showsNoticePolicyLink)
    }

    @MainActor
    func testKeepsTheFooterForAPrivacyCenterWithoutPolicies() {
        let vm = notice(policies: nil, config: ["privacy_center_url": "https://example.test/privacy-center"])

        XCTAssertTrue(vm.showsNoticeFooter)
        XCTAssertTrue(vm.productPolicyLinks.isEmpty)
    }

    @MainActor
    func testDropsTheNoticeLinkOnTheNoticeOnceEveryProductHasAPolicy() {
        let vm = notice(policies: [savings: savingsPolicy, loans: loansPolicy, insurance: insurancePolicy])

        XCTAssertFalse(vm.showsNoticePolicyLink)
        XCTAssertEqual(vm.productPolicyLinks.count, 3)
    }

    @MainActor
    func testRendersNothingForPoliciesKeyedOnlyByUnknownProducts() {
        let vm = notice(policies: [unlisted: loansPolicy])

        XCTAssertTrue(vm.productPolicyLinks.isEmpty)
        XCTAssertTrue(vm.showsNoticePolicyLink)
        XCTAssertFalse(vm.showsNoticeFooter)
    }

    @MainActor
    func testTranslatesTheLabelAndFallsBackToEnglish() {
        let translations: [String: Any] = ["Hindi": ["product_privacy_policies_label": "गोपनीयता नीतियाँ:"]]
        let vm = notice(policies: [savings: savingsPolicy], config: ["supported_languages_and_translations": translations])

        XCTAssertEqual(vm.getTranslatedText(ProductPolicyCopy.translationKey, defaultText: ProductPolicyCopy.label), "Privacy policies:")
        vm.selectedLanguage = "Hindi"
        XCTAssertEqual(vm.getTranslatedText(ProductPolicyCopy.translationKey, defaultText: ProductPolicyCopy.label), "गोपनीयता नीतियाँ:")
        vm.selectedLanguage = "Tamil"
        XCTAssertEqual(vm.getTranslatedText(ProductPolicyCopy.translationKey, defaultText: ProductPolicyCopy.label), "Privacy policies:")
    }
}
