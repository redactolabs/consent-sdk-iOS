import SwiftUI
import UIKit

/// A centred dialog card (Android PCModal): title and close button, a body
/// that scrolls when it is taller than the screen allows, and a footer row.
struct PCModal<Content: View, Footer: View>: View {
    @Environment(\.privacyCenterTheme) private var theme
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(theme.font(size: 18, weight: .semibold))
                    .foregroundColor(theme.text)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(theme.font(size: 16, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PCStrings.close)
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
            ViewThatFits(in: .vertical) {
                bodyContent
                ScrollView { bodyContent }
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                footer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.surface)
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private var bodyContent: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }
}

extension View {
    /// Presents `dialog` as a centred card over a dimmed screen while `item`
    /// is set; tapping outside the card clears `item`.
    func pcDialog<Item: Identifiable, Dialog: View>(
        item: Binding<Item?>,
        @ViewBuilder dialog: @escaping (Item) -> Dialog
    ) -> some View {
        modifier(PCDialogPresenter(item: item, dialog: dialog))
    }
}

private final class PCDialogHostBox {
    var host: UIHostingController<AnyView>?
}

private struct PCDialogPresenter<Item: Identifiable, Dialog: View>: ViewModifier {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Binding var item: Item?
    let dialog: (Item) -> Dialog
    @State private var anchor = PCPresentationAnchor()
    @State private var box = PCDialogHostBox()

    func body(content: Content) -> some View {
        content
            .background(PCPresentationAnchorView(anchor: anchor))
            .onChange(of: item?.id) { _ in sync() }
            .onAppear {
                guard item != nil else { return }
                DispatchQueue.main.async { sync() }
            }
            .onDisappear(perform: dismissHost)
    }

    private func sync() {
        if let current = item {
            PCOverlayHost.dismiss(box.host)
            let itemBinding = $item
            let box = box
            let overlay = PCOverlayEnvironment(theme: theme, layoutDirection: layoutDirection, colorScheme: colorScheme)
            box.host = PCOverlayHost.present(from: anchor.view) { _, _ in
                AnyView(
                    PCDialogLayer(onDismiss: {
                        PCOverlayHost.dismiss(box.host)
                        box.host = nil
                        itemBinding.wrappedValue = nil
                    }) { dialog(current) }
                        .pcOverlayEnvironment(overlay)
                )
            }
        } else {
            dismissHost()
        }
    }

    private func dismissHost() {
        PCOverlayHost.dismiss(box.host)
        box.host = nil
    }
}

private struct PCDialogLayer<Dialog: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let dialog: () -> Dialog

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)
                dialog()
                    .frame(maxWidth: min(480, proxy.size.width - 32))
                    .frame(maxHeight: proxy.size.height * 0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityAction(.escape, onDismiss)
    }
}
