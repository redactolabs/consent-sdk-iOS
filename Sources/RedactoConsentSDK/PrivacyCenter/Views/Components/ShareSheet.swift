import SwiftUI
import UIKit

/// Thin wrapper over `UIActivityViewController` so a downloaded receipt PDF can be
/// saved/opened/shared via the system share sheet.
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
