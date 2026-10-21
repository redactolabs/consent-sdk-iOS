import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Counts activity for the inactivity sign-out the way React listens for
/// pointer, keyboard and scroll events on the window: every touch in the
/// Privacy Center's window, sheets it presents included, and every edit in a
/// text field there (the keyboard draws in a window of its own).
///
/// The touches are seen by a recognizer on the window that never takes one:
/// it fails as soon as it has seen a touch, recognises alongside every other
/// recognizer and delays nothing, so taps, drags and scrolls reach the views
/// exactly as before. The view itself is a non-interactive anchor that finds
/// the window, and takes the recognizer and observers away when it leaves.
struct PCActivityTracker: UIViewRepresentable {
    let onActivity: () -> Void

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onActivity = onActivity
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.onActivity = onActivity
    }

    static func dismantleUIView(_ uiView: AnchorView, coordinator: ()) {
        uiView.stopObserving()
    }

    final class AnchorView: UIView, UIGestureRecognizerDelegate {
        var onActivity: (() -> Void)?
        private let recognizer: TouchObservingRecognizer
        private weak var observedWindow: UIWindow?

        override init(frame: CGRect) {
            recognizer = TouchObservingRecognizer(target: nil, action: nil)
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            recognizer.onTouch = { [weak self] in
                self?.onActivity?()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow !== observedWindow {
                stopObserving()
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, window !== observedWindow else { return }
            window.addGestureRecognizer(recognizer)
            observedWindow = window
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
            center.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextView.textDidChangeNotification, object: nil)
        }

        func stopObserving() {
            observedWindow?.removeGestureRecognizer(recognizer)
            observedWindow = nil
            let center = NotificationCenter.default
            center.removeObserver(self, name: UITextField.textDidChangeNotification, object: nil)
            center.removeObserver(self, name: UITextView.textDidChangeNotification, object: nil)
        }

        /// Typing in a field of this window; the host's own fields elsewhere
        /// do not count.
        @objc private func textDidChange(_ notification: Notification) {
            guard let field = notification.object as? UIView, field.window === observedWindow else { return }
            onActivity?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    /// Reports a touch as it begins, then fails so it never claims it.
    final class TouchObservingRecognizer: UIGestureRecognizer {
        var onTouch: (() -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            onTouch?()
            state = .failed
        }
    }
}
