import SwiftUI

struct ProductPolicyLineView: View {
    let label: String
    let links: [ProductPolicyLink]
    let linkColor: Color

    var body: some View {
        Text(ProductPolicies.line(label: label, links: links))
            .tint(linkColor)
            .fixedSize(horizontal: false, vertical: true)
            .id("product_privacy_policies")
    }
}
