import Foundation

extension ConsentNoticeViewModel {
    var otpLocked: Bool {
        otpPanel.isOpen
    }

    var otpPanelTitle: String {
        otpGate?.title ?? OtpGateCopy.title
    }

    var otpPanelDescription: String {
        otpGate?.description ?? OtpGateCopy.description
    }

    var otpPanelSubmitLabel: String {
        otpPanel.busy ? OtpGateCopy.verifying : (otpGate?.submitLabel ?? OtpGateCopy.submit)
    }

    var otpConfirmEnabled: Bool {
        !otpPanel.busy && OtpCodeEntry.isComplete(otpPanel.digits)
    }

    func holdForOtp(_ mode: AcceptMode) -> Bool {
        if otpFlow.holds(required: otpGate?.required) {
            otpPanel.pendingMode = mode
            otpPanel.error = nil
            return true
        }
        otpFlow.passGate()
        return false
    }

    func updateOtpDigits(_ digits: [String]) {
        guard otpPanel.isOpen, !otpPanel.busy else { return }
        otpPanel.digits = digits
    }

    func confirmOtp() async {
        guard let otpGate,
              let pendingMode = otpPanel.pendingMode,
              !otpPanel.busy,
              OtpCodeEntry.isComplete(otpPanel.digits) else { return }

        otpPanel.busy = true
        otpPanel.error = nil

        let result: OtpVerifyResult
        do {
            result = try await otpGate.onVerify(OtpCodeEntry.code(of: otpPanel.digits))
        } catch {
            result = OtpVerifyResult(ok: false)
        }

        guard otpPanel.isOpen, otpPanel.busy else { return }

        guard result.ok else {
            let message = result.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            otpPanel.error = message.isEmpty ? OtpGateCopy.failed : message
            otpPanel.digits = OtpCodeEntry.empty()
            otpPanel.busy = false
            return
        }

        otpFlow.markVerified(mode: otpPanel.pendingMode ?? pendingMode, token: accessToken)
        otpPanel = OtpPanelState()
    }

    func handleAccessTokenChange(_ token: String) {
        guard token != accessToken else { return }
        accessToken = token
        if let mode = otpFlow.takeDeferredAccept(currentToken: token) {
            handleAccept(mode: mode)
        }
    }
}
