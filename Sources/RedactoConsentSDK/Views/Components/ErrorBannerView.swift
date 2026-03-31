import SwiftUI

/// Dismissible error banner matching the React Native SDK's error display.
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#DC2626"))
                .multilineTextAlignment(.leading)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#DC2626"))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(hex: "#FEE2E2"))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "#FECACA"), lineWidth: 1)
        )
    }
}
