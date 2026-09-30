import SwiftUI

struct NoticeLogoRow: View {
    let url: URL
    let position: LogoPosition
    var height: CGFloat = 32
    var maxWidth: CGFloat?

    var body: some View {
        RemoteLogoView(url: url, size: height, maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: NoticeLayout.alignment(for: position))
    }
}
