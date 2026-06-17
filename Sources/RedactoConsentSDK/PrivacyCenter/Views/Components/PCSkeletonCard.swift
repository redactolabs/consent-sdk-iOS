import SwiftUI

public struct PCSkeletonCard: View {
    @Environment(\.privacyCenterTheme) private var theme
    @State private var isAnimating: Bool = false
    let height: CGFloat

    public init(height: CGFloat = 96) {
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(theme.surface)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceElevated)
                    .opacity(isAnimating ? 0.4 : 0.85)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
