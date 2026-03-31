import SwiftUI

/// Loading spinner matching the React Native SDK's loading state.
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4f87ff")))
                .scaleEffect(1.2)

            Text("Loading...")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#667085"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
