import Foundation

struct OtpGateFlow {
    private(set) var verified = false
    private(set) var deferredMode: AcceptMode?
    private var tokenAtVerify: String?

    static func shouldHold(required: Bool?, verified: Bool) -> Bool {
        (required ?? false) && !verified
    }

    func holds(required: Bool?) -> Bool {
        Self.shouldHold(required: required, verified: verified)
    }

    mutating func passGate() {
        deferredMode = nil
    }

    mutating func markVerified(mode: AcceptMode, token: String) {
        verified = true
        tokenAtVerify = token
        deferredMode = mode
    }

    /// What the rows show while an accept waits on the gate, and the
    /// visitor's own ticks held aside meanwhile. A shortcut shows its own
    /// selection and holds the ticks it replaced (the first time only, so a
    /// repeat keeps the visitor's); Accept Selected puts them back.
    static func pendingSelection(
        mode: AcceptMode,
        rows: [NoticePurposeRow],
        current: SelectionState,
        held: SelectionState?
    ) -> (shown: SelectionState, held: SelectionState?) {
        if mode == .selected {
            return (held ?? current, nil)
        }
        let shown = ProductConsent.selectionForMode(rows: rows, mode: mode, current: current)
        return (shown, held ?? current)
    }

    mutating func takeDeferredAccept(currentToken: String) -> AcceptMode? {
        guard let mode = deferredMode, currentToken != tokenAtVerify else {
            return nil
        }
        deferredMode = nil
        return mode
    }
}
