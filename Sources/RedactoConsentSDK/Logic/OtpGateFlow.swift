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

    mutating func takeDeferredAccept(currentToken: String) -> AcceptMode? {
        guard let mode = deferredMode, currentToken != tokenAtVerify else {
            return nil
        }
        deferredMode = nil
        return mode
    }
}
