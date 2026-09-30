import SwiftUI

struct ConfirmHintView: View {
    let text: String
    let color: Color
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .noticeFont(size: size)
            .foregroundColor(color)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
