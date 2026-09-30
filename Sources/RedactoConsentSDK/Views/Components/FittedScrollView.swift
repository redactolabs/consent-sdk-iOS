import SwiftUI

private struct FittedContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A vertical scroll view as tall as its content, scrolling only once the
/// card's height cap is reached. A bare `ScrollView` takes every point offered,
/// which stretches a short card (the age check, the guardian form) to the cap.
struct FittedScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            content.background(GeometryReader { geo in
                Color.clear.preference(key: FittedContentHeightKey.self, value: geo.size.height)
            })
        }
        .frame(maxHeight: contentHeight > 0 ? contentHeight : nil)
        .onPreferenceChange(FittedContentHeightKey.self) { contentHeight = $0 }
    }
}
