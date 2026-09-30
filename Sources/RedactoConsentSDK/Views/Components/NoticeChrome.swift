import SwiftUI
import UIKit

/// Where the notice card sits in its container, from the resolved layout.
struct NoticePlacement: Equatable {
    let alignment: Alignment
    /// Pinned to the bottom edge, top corners rounded only.
    let docked: Bool
    /// A fixed width, or nil to fill the container.
    let width: CGFloat?
    /// The tallest the card grows, as a share of the container.
    let maxHeightFraction: CGFloat
    /// Gap to the container edges, for a corner card.
    let edgeInset: CGFloat
    /// A bottom bar holds its content to a readable width.
    let contentMaxWidth: CGFloat?

    static func resolve(layout: ResolvedNoticeLayout, isPhone: Bool, isGlass: Bool, containerWidth: CGFloat, desktopWidth: CGFloat) -> NoticePlacement {
        let floatingHeight: CGFloat = isGlass ? 0.85 : 0.9
        if isPhone {
            if layout.mobileSheet {
                return NoticePlacement(alignment: .bottom, docked: true, width: nil, maxHeightFraction: 0.92, edgeInset: 0, contentMaxWidth: nil)
            }
            let width = isGlass ? containerWidth - 32 : containerWidth * 0.9
            // The web's 90vh counts the status bar and home indicator; measured
            // against the safe area it is nearly all of it.
            return NoticePlacement(alignment: .center, docked: false, width: width, maxHeightFraction: 0.97, edgeInset: 0, contentMaxWidth: nil)
        }
        let cardWidth = min(desktopWidth, max(0, containerWidth - 48))
        switch layout.desktopPosition {
        case .center:
            return NoticePlacement(alignment: .center, docked: false, width: cardWidth, maxHeightFraction: floatingHeight, edgeInset: 0, contentMaxWidth: nil)
        case .bottomRight:
            return NoticePlacement(alignment: .bottomTrailing, docked: false, width: cardWidth, maxHeightFraction: floatingHeight, edgeInset: 24, contentMaxWidth: nil)
        case .bottomLeft:
            return NoticePlacement(alignment: .bottomLeading, docked: false, width: cardWidth, maxHeightFraction: floatingHeight, edgeInset: 24, contentMaxWidth: nil)
        case .bottomBar:
            return NoticePlacement(alignment: .bottom, docked: true, width: nil, maxHeightFraction: 0.7, edgeInset: 0, contentMaxWidth: 1100)
        }
    }
}

/// A rectangle with only some corners rounded, for a docked card on iOS 16.
struct NoticeCardShape: Shape {
    let radius: CGFloat
    let docked: Bool

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner = docked ? [.topLeft, .topRight] : .allCorners
        let clamped = min(radius, rect.height / 2, rect.width / 2)
        return Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: clamped, height: clamped)
        ).cgPath)
    }
}

/// Shown in place of the notice when it cannot be read: retry, or close.
struct NoticeErrorDialogView: View {
    let message: String
    let isPhone: Bool
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(NoticeErrorCopy.title)
                .noticeFont(size: isPhone ? 16 : 18, weight: .semibold)
                .padding(.bottom, isPhone ? 8 : 12)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .noticeFont(size: isPhone ? 12 : 14)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, isPhone ? 12 : 16)
            Button(action: onRetry) {
                Text(NoticeErrorCopy.retry)
                    .noticeFont(size: isPhone ? 12 : 14, weight: .medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, isPhone ? 12 : 16)
                    .padding(.vertical, isPhone ? 6 : 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#DC2626")))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NoticeErrorCopy.retryLabel)
        }
        .foregroundColor(Color(hex: "#DC2626"))
        .padding(isPhone ? 12 : 16)
        .frame(maxWidth: isPhone ? .infinity : 400)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: isPhone ? 12 : 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#DC2626"))
                    .padding(isPhone ? 2 : 4)
            }
            .buttonStyle(.plain)
            .padding(isPhone ? 4 : 8)
            .accessibilityLabel(NoticeErrorCopy.close)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// The host's props are unusable; nothing was read.
struct NoticeConfigurationErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NoticeErrorCopy.configurationTitle)
                .font(.system(size: 17, weight: .bold))
            Text(message)
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
            Text(NoticeErrorCopy.configurationHint)
                .font(.system(size: 15))
        }
        .foregroundColor(Color(hex: "#cc3333"))
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#ffeeee"))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#ffcccc"), lineWidth: 1))
    }
}

/// Glass loads as a compact pill instead of an empty card.
struct NoticeLoaderPill: View {
    let theme: NoticeTheme

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
            Text(NoticeCopy.loading)
                .noticeFont(size: 14, weight: .semibold)
                .foregroundColor(theme.heading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Capsule().fill(.regularMaterial)
                Capsule().fill(theme.glass?.control.color ?? .white)
            }
        )
        .overlay(Capsule().stroke(theme.glass?.panelEdge.color ?? .clear, lineWidth: 1))
        .noticeShadow(theme.glass?.floatShadow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading consent notice")
    }
}

/// As tall as its content, never taller than `cap`. `.frame(maxHeight:)` would
/// take the whole cap whenever there is room, so a short notice drew a
/// full-height card with its content floating in the middle.
struct NoticeHeightCap: Layout {
    let cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let height = min(proposal.height ?? cap, cap)
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: height))
        return CGSize(width: size.width, height: min(size.height, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
