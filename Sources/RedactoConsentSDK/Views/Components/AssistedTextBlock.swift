import SwiftUI

/// Lines of running text with inline links; the run talkback is reading gets
/// the highlight.
struct AssistedTextBlock: View {
    let lines: [[AssistedTextRun]]
    let size: CGFloat
    let textColor: Color
    let linkColor: Color
    let highlightBackground: Color
    let highlightText: Color?
    let isHighlighted: (String) -> Bool

    @Environment(\.noticeFontFamily) private var fontFamily

    var body: some View {
        Text(attributed)
            .font(NoticeFontResolver.font(family: fontFamily, size: size, weight: .regular))
            .foregroundColor(textColor)
            .tint(linkColor)
            .lineSpacing(size * 0.25)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            for run in line {
                var piece = AttributedString(run.text)
                if let link = run.link {
                    piece.link = link
                    piece.foregroundColor = linkColor
                }
                if let id = run.elementId, isHighlighted(id) {
                    piece.backgroundColor = highlightBackground
                    if let highlightText {
                        piece.foregroundColor = highlightText
                    }
                }
                result.append(piece)
            }
        }
        return result
    }
}
