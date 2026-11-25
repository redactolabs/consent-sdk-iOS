import SwiftUI
import UIKit

/// Decoded brand images kept for the life of the process, so the top bar's
/// logo and icon paint at once when the bar is rebuilt instead of refetching.
final class PCImageCache {
    static let shared = PCImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// A remote raster image backed by `PCImageCache`. Unlike `AsyncImage`, a view
/// rebuilt for a URL it has already loaded starts with the image, not the
/// placeholder, so the logo does not flash on every re-render.
struct PCRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loaded: (url: URL, image: UIImage)?

    var body: some View {
        if let image = currentImage {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .task(id: url) { await load() }
        }
    }

    private var currentImage: UIImage? {
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return PCImageCache.shared.image(for: url)
    }

    private func load() async {
        let target = url
        if let cached = PCImageCache.shared.image(for: target) {
            await MainActor.run { loaded = (target, cached) }
            return
        }
        guard let data = try? await URLSession.shared.data(from: target).0,
              let image = UIImage(data: data) else { return }
        PCImageCache.shared.store(image, for: target)
        await MainActor.run { loaded = (target, image) }
    }
}
