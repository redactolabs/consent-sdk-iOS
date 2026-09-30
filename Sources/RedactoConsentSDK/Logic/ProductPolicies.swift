import Foundation

enum ProductPolicies {
    static func links(products: [NoticeProduct]?, policies: [String: String]?) -> [ProductPolicyLink] {
        guard let policies else {
            return []
        }
        return (products ?? []).compactMap { product in
            guard let url = policies[product.uuid]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty else {
                return nil
            }
            return ProductPolicyLink(uuid: product.uuid, name: product.name, url: url)
        }
    }

    static func showsNoticePolicyLink(products: [NoticeProduct]?, links: [ProductPolicyLink]) -> Bool {
        let productCount = products?.count ?? 0
        if links.isEmpty || productCount == 0 {
            return true
        }
        return links.count < productCount
    }

    static func line(label: String, links: [ProductPolicyLink]) -> AttributedString {
        var result = AttributedString(label)
        for (index, link) in links.enumerated() {
            result.append(AttributedString(index == 0 ? " " : ", "))
            var anchor = AttributedString(link.name)
            anchor.link = URL(string: link.url)
            result.append(anchor)
        }
        return result
    }
}
