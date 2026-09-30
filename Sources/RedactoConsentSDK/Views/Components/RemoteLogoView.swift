import SwiftUI
import WebKit

/// Displays a remote logo image, supporting both raster formats and SVG.
/// SwiftUI's AsyncImage does not support SVG, so this view downloads the data
/// and renders SVGs via a lightweight WKWebView wrapper.
struct RemoteLogoView: View {
    let url: URL
    let size: CGFloat
    /// Set, a raster logo keeps its aspect ratio at `size` tall, up to this wide.
    var maxWidth: CGFloat?

    @State private var logoImage: UIImage?
    @State private var isSVG = false
    @State private var svgData: Data?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image = logoImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isSVG, let data = svgData {
                SVGWebView(svgData: data, size: size)
            } else if !loaded {
                Color.clear
            }
        }
        .frame(width: frameWidth, height: size)
        .task(id: url) {
            await loadImage()
        }
    }

    /// The logo's own width at `size` tall, capped at `maxWidth`. A box wider
    /// than the image would centre it inside, pushing a left-aligned logo inward.
    private var frameWidth: CGFloat {
        guard let maxWidth, !isSVG else { return size }
        guard let image = logoImage, image.size.height > 0 else { return size }
        return min(maxWidth, size * image.size.width / image.size.height)
    }

    private func loadImage() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let mimeType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
            let urlPath = url.pathExtension.lowercased()

            if mimeType.contains("svg") || urlPath == "svg" {
                await MainActor.run {
                    self.isSVG = true
                    self.svgData = data
                    self.loaded = true
                }
            } else if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.logoImage = uiImage
                    self.loaded = true
                }
            } else {
                await MainActor.run { self.loaded = true }
            }
        } catch {
            await MainActor.run { self.loaded = true }
        }
    }
}

/// A minimal WKWebView wrapper that renders SVG data inline.
private struct SVGWebView: UIViewRepresentable {
    let svgData: Data
    let size: CGFloat
    /// Set, a raster logo keeps its aspect ratio at `size` tall, up to this wide.
    var maxWidth: CGFloat?

    func makeUIView(context: Context) -> WKWebView {
        // iPad web views default to desktop mode, which ignores the viewport tag
        // and lays the page out ~980pt wide: the SVG then draws outside its box.
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        loadSVG(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadSVG(in: webView)
    }

    private func loadSVG(in webView: WKWebView) {
        guard let svgString = String(data: svgData, encoding: .utf8) else { return }
        let html = """
        <!DOCTYPE html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        * { margin: 0; padding: 0; }
        html, body { width: 100%; height: 100%; background: transparent; overflow: hidden; }
        svg { width: 100%; height: 100%; object-fit: contain; }
        img { width: 100%; height: 100%; object-fit: contain; }
        </style></head>
        <body>\(svgString)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
