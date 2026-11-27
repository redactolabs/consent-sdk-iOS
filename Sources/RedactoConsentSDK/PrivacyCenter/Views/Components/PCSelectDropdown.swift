import SwiftUI
import UIKit

struct PCSelectDropdownRow: Identifiable {
    let id: String
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
}

struct PCOverlayEnvironment {
    let theme: PrivacyCenterTheme
    let layoutDirection: LayoutDirection
    let colorScheme: ColorScheme
}

extension View {
    func pcOverlayEnvironment(_ overlay: PCOverlayEnvironment) -> some View {
        environment(\.privacyCenterTheme, overlay.theme)
            .environment(\.layoutDirection, overlay.layoutDirection)
            .environment(\.colorScheme, overlay.colorScheme)
    }
}

final class PCPresentationAnchor {
    weak var view: UIView?
}

/// A non-interactive view behind a control, used to find its frame in the
/// window and the controller to present from.
struct PCPresentationAnchorView: UIViewRepresentable {
    let anchor: PCPresentationAnchor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        anchor.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        anchor.view = uiView
    }
}

/// Presents SwiftUI content in a transparent layer the size of the window,
/// over everything on screen, from the controller showing `anchorView`.
enum PCOverlayHost {
    static func present(from anchorView: UIView?, animated: Bool = true, _ makeRoot: (UIHostingController<AnyView>, CGRect) -> AnyView) -> UIHostingController<AnyView>? {
        guard let anchorView, let window = anchorView.window, var top = window.rootViewController else { return nil }
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        let frame = anchorView.convert(anchorView.bounds, to: window)
        let host = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
        host.rootView = makeRoot(host, frame)
        host.view.backgroundColor = .clear
        host.view.accessibilityViewIsModal = true
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        top.present(host, animated: animated)
        return host
    }

    static func dismiss(_ host: UIHostingController<AnyView>?, completion: (() -> Void)? = nil) {
        guard let host, host.presentingViewController != nil, !host.isBeingDismissed else { return }
        host.dismiss(animated: true, completion: completion)
    }
}

/// The option list, pinned under the field (above it when there is no room
/// below), the way Android's DropdownMenu draws in a popup of its own. Being
/// above the whole screen, it is never covered by the views after the select.
enum PCSelectDropdownPresenter {
    static func present(
        from anchorView: UIView?,
        rows: [PCSelectDropdownRow],
        overlay: PCOverlayEnvironment,
        onDismiss: @escaping () -> Void
    ) -> Bool {
        let host = PCOverlayHost.present(from: anchorView) { host, frame in
            let close: () -> Void = { [weak host] in
                PCOverlayHost.dismiss(host, completion: onDismiss)
            }
            return AnyView(
                PCSelectDropdownLayer(
                    anchor: frame,
                    rows: rows,
                    onSelect: { row in
                        row.onSelect()
                        close()
                    },
                    onDismiss: close
                )
                .pcOverlayEnvironment(overlay)
            )
        }
        return host != nil
    }
}

private struct PCSelectDropdownLayer: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.layoutDirection) private var contentDirection
    let anchor: CGRect
    let rows: [PCSelectDropdownRow]
    let onSelect: (PCSelectDropdownRow) -> Void
    let onDismiss: () -> Void

    private static var rowHeight: CGFloat { 44 }
    private static var maxListHeight: CGFloat { 300 }
    private static var gap: CGFloat { 4 }
    private static var margin: CGFloat { 16 }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let wanted = min(CGFloat(max(rows.count, 1)) * Self.rowHeight, Self.maxListHeight)
            let below = size.height - anchor.maxY - Self.gap - Self.margin
            let above = anchor.minY - Self.gap - Self.margin
            let opensUp = below < wanted && above > below
            let height = max(Self.rowHeight, min(wanted, opensUp ? above : below))
            let y = opensUp ? anchor.minY - Self.gap - height : anchor.maxY + Self.gap
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityLabel(PCStrings.close)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onDismiss)
                list(height: height)
                    .environment(\.layoutDirection, contentDirection)
                    .frame(width: anchor.width)
                    .offset(x: anchor.minX, y: y)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .ignoresSafeArea()
        .accessibilityAction(.escape, onDismiss)
    }

    private func list(height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Button(action: { onSelect(row) }) {
                        HStack(spacing: 8) {
                            Text(row.label)
                                .font(theme.font(size: 14))
                                .foregroundColor(row.isSelected ? theme.primary : theme.text)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if row.isSelected {
                                Image(systemName: "checkmark")
                                    .font(theme.font(size: 13, weight: .semibold))
                                    .foregroundColor(theme.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: Self.rowHeight)
                        .background(row.isSelected ? theme.surface : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(row.isSelected ? .isSelected : [])
                }
            }
        }
        .scrollDisabled(CGFloat(rows.count) * Self.rowHeight <= height)
        .frame(height: height)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
