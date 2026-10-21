import Foundation

extension ConsentNoticeViewModel {
    var otpLocked: Bool {
        otpPanel.isOpen
    }

    var otpPanelTitle: String {
        otpGate?.title ?? chromeCopy.otpTitle
    }

    var otpPanelDescription: String {
        otpGate?.description ?? chromeCopy.otpDescription
    }

    var otpPanelSubmitLabel: String {
        otpPanel.busy ? chromeCopy.otpVerifying : (otpGate?.submitLabel ?? chromeCopy.otpSubmit)
    }

    var otpConfirmEnabled: Bool {
        !otpPanel.busy && OtpCodeEntry.isComplete(otpPanel.digits)
    }

    func holdForOtp(_ mode: AcceptMode) -> Bool {
        if otpFlow.holds(required: otpGate?.required) {
            reflectPendingSelection(mode)
            otpPanel.pendingMode = mode
            otpPanel.error = nil
            return true
        }
        otpFlow.passGate()
        return false
    }

    /// The rows stay visible behind the gate, so they show what will be sent:
    /// a shortcut's selection while it is pending, and the visitor's own ticks
    /// again once Accept Selected takes its place.
    private func reflectPendingSelection(_ mode: AcceptMode) {
        let current = SelectionState(selectedPurposes: selectedPurposes, selectedDataElements: selectedDataElements)
        let next = OtpGateFlow.pendingSelection(
            mode: mode,
            rows: purposeRows,
            current: current,
            held: preGateSelection
        )
        preGateSelection = next.held
        selectedPurposes = next.shown.selectedPurposes
        selectedDataElements = next.shown.selectedDataElements
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
            otpPanel.error = message.isEmpty ? chromeCopy.otpFailed : message
            otpPanel.digits = OtpCodeEntry.empty()
            otpPanel.busy = false
            return
        }

        otpFlow.markVerified(mode: otpPanel.pendingMode ?? pendingMode, token: accessToken)
        otpPanel = OtpPanelState()
        preGateSelection = nil
    }

    func handleAccessTokenChange(_ token: String) {
        guard token != accessToken else { return }
        accessToken = token
        if let mode = otpFlow.takeDeferredAccept(currentToken: token) {
            handleAccept(mode: mode)
        }
    }
}
