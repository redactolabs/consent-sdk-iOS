import SwiftUI

/// "Powered by Redacto" (React ui/Footer); hidden by the store when the
/// workspace sets `hide_platform_branding`.
public struct PCFooter: View {
    @Environment(\.privacyCenterTheme) private var theme

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text(PCStrings.poweredBy)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary)
            Text("Redacto")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
