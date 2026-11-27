import SwiftUI

/// Simple wrap-content layout (for uploaded-doc pills, product chips and the
/// footer links, whose rows are centred).
struct FlowLayoutCompat<Content: View>: View {
    let spacing: CGFloat
    var centered = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        FlowLayout(spacing: spacing, centered: centered) { content() }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for size in Self.measure(subviews, maxWidth: maxWidth) {
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = Self.measure(subviews, maxWidth: bounds.width)
        // The same rows `sizeThatFits` measured: a view moves down once the
        // row it would join runs past the width.
        var rows: [Range<Int>] = []
        var rowStart = 0
        var advance: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if advance + size.width > bounds.width, advance > 0 {
                rows.append(rowStart..<index)
                rowStart = index
                advance = 0
            }
            advance += size.width + spacing
        }
        if rowStart < sizes.count {
            rows.append(rowStart..<sizes.count)
        }
        var y = bounds.minY
        for row in rows {
            let rowWidth = sizes[row].reduce(CGFloat(0)) { $0 + $1.width } + spacing * CGFloat(row.count - 1)
            var x = bounds.minX + (centered ? max(0, (bounds.width - rowWidth) / 2) : 0)
            var rowHeight: CGFloat = 0
            for index in row {
                let size = sizes[index]
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }

    private static func measure(_ subviews: Subviews, maxWidth: CGFloat) -> [CGSize] {
        subviews.map { view in
            let ideal = view.sizeThatFits(.unspecified)
            guard ideal.width > maxWidth else { return ideal }
            return view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        }
    }
}
