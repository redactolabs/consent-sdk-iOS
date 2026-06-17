import SwiftUI

public struct PCFooter: View {
    @Environment(\.privacyCenterTheme) private var theme

    public init() {}

    public var body: some View {
        Text(PCStrings.poweredBy)
            .font(.system(size: 11))
            .foregroundColor(theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}
