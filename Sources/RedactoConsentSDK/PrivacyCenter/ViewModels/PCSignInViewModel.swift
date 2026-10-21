import Foundation
import SwiftUI

/// The built-in sign-in shown when the Privacy Center has no token (React
/// `PrivacyCenterSignIn`): a contact, a one-time code, and then the tokens go
/// to the token store, which takes the visitor straight into the centre.
@MainActor
final class PCSignInViewModel: ObservableObject {
    enum Step: Equatable {
        case contact
        case otp
    }

    struct SentCode: Equatable {
        let contact: String
        let channel: PrivacyCenterSignInContact.Channel
        let countryCode: String
        let otpId: String
    }

    /// The wait the hosted sign-in uses before a code can be sent again.
    static let resendSeconds = 50
    static let codeLength = 6
    /// Where "Contact support" writes when the organisation has no DPO email.
    static let supportEmailFallback = "support@redacto.ai"

    @Published var step: Step = .contact
    @Published var contactInput = ""
    @Published var countryCode: String
    @Published var digits: [String]
    @Published var error: String?
    @Published var busy = false
    @Published var resending = false
    @Published var resendIn = 0
    @Published private(set) var sent: SentCode?

    private let store: PrivacyCenterStore
    private var countdownTask: Task<Void, Never>?
    /// Seams for tests.
    var sendCode: (String, String, String, PrivacyCenterSignInContact.Channel) async throws -> String
    var verifyCode: (String, String, String, String) async throws -> PrivacyCenterSignInTokens

    init(store: PrivacyCenterStore) {
        self.store = store
        self.countryCode = store.settings.signIn.defaultCountryCode
        self.digits = OtpCodeEntry.empty(length: Self.codeLength)
        let baseUrl = store.baseUrl
        let session = store.urlSession
        self.sendCode = { org, workspace, contact, channel in
            try await PrivacyCenterPublicAPI.createOtp(
                baseUrl: baseUrl, organisationUuid: org, workspaceUuid: workspace, to: contact, channel: channel, urlSession: session
            )
        }
        self.verifyCode = { org, workspace, otpId, code in
            try await PrivacyCenterPublicAPI.verifyOtp(
                baseUrl: baseUrl, organisationUuid: org, workspaceUuid: workspace, otpId: otpId, code: code, urlSession: session
            )
        }
    }

    deinit {
        countdownTask?.cancel()
    }

    var settings: PrivacyCenterSignInSettings { store.settings.signIn }

    var detectedChannel: PrivacyCenterSignInContact.Channel? {
        PrivacyCenterSignInContact.detectChannel(contactInput, channels: settings.channels)
    }

    /// The country code picker shows for a phone number typed without one.
    var showsCountryCode: Bool {
        switch settings.channels {
        case .sms: return true
        case .email: return false
        case .both:
            return detectedChannel == .sms && !contactInput.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        }
    }

    var organisationUnavailable: Bool { store.organisationLookupFailed }
    var organisationPending: Bool { store.isResolvingOrganisation }

    /// What the contact step shows under its field: the error, the
    /// organisation problem, or the help text.
    var contactError: String? {
        error ?? (organisationUnavailable ? PCStrings.signInOrgUnavailable : nil)
    }

    var fieldLabel: String {
        settings.fieldLabel.map { store.copy($0) } ?? PCStrings.t(channelKey("signInFieldLabel"))
    }

    var placeholder: String {
        settings.placeholder.map { store.copy($0) } ?? PCStrings.t(channelKey("signInPlaceholder"))
    }

    var helpText: String {
        settings.helpText.map { store.copy($0) } ?? PCStrings.t(channelKey("signInHelpText"))
    }

    var noticeLine: String {
        settings.showNoticeLine ? store.copy(settings.noticeLine) : ""
    }

    var supportEmail: String {
        store.branding?.dpoEmail.pcTrimmedNonEmpty ?? Self.supportEmailFallback
    }

    /// The contact as the OTP step names it: a phone masked, an email as typed.
    var contactDisplay: String {
        guard let sent else { return "" }
        return sent.channel == .sms ? PrivacyCenterSignInContact.maskPhone(sent.contact) : sent.contact
    }

    var otpDescription: String {
        if let custom = settings.otpDescription {
            return store.copy(custom, contact: contactDisplay)
        }
        return PCStrings.t(sent?.channel == .sms ? "otpDescriptionSms" : "otpDescriptionEmail")
    }

    var resendLabel: String {
        store.copy(settings.otpResendText)
    }

    private func channelKey(_ prefix: String) -> String {
        switch settings.channels {
        case .both: return "\(prefix)Both"
        case .email: return "\(prefix)Email"
        case .sms: return "\(prefix)Sms"
        }
    }

    private var invalidContactMessage: String {
        PCStrings.t(channelKey("signInInvalidContact"))
    }

    private func message(for error: Error) -> String {
        let failure = error as? PrivacyCenterSignInError
        return PCStrings.t(PrivacyCenterSignInContact.errorKey(code: failure?.code, status: failure?.status))
    }

    // MARK: - Steps

    func submitContact() async {
        error = nil
        guard let channel = detectedChannel else {
            error = invalidContactMessage
            return
        }
        let contact = PrivacyCenterSignInContact.normalize(contactInput, channel: channel, countryCode: countryCode)
        guard PrivacyCenterSignInContact.isValid(contact, channel: channel) else {
            error = invalidContactMessage
            return
        }
        guard let org = store.organisationUuid, let workspace = store.workspaceUuid else {
            error = PCStrings.signInOrgUnavailable
            return
        }
        busy = true
        defer { busy = false }
        do {
            let otpId = try await sendCode(org, workspace, contact, channel)
            sent = SentCode(contact: contact, channel: channel, countryCode: countryCode, otpId: otpId)
            digits = OtpCodeEntry.empty(length: Self.codeLength)
            step = .otp
            startCountdown()
            store.showToast(channel == .sms ? PCStrings.otpSentPhone : PCStrings.otpSentEmail, kind: .success)
        } catch {
            self.error = message(for: error)
        }
    }

    func verify() async {
        guard let sent, let org = store.organisationUuid, let workspace = store.workspaceUuid else { return }
        let code = OtpCodeEntry.code(of: digits)
        guard code.count == Self.codeLength, OtpCodeEntry.isComplete(digits) else {
            error = PCStrings.otpEnterAllDigits
            return
        }
        busy = true
        error = nil
        defer { busy = false }
        do {
            let tokens = try await verifyCode(org, workspace, sent.otpId, code)
            countdownTask?.cancel()
            await store.completeSignIn(tokens, contact: sent.channel == .email ? sent.contact : nil)
        } catch {
            self.error = message(for: error)
        }
    }

    func resend() async {
        guard let sent, resendIn == 0, !resending else { return }
        guard let org = store.organisationUuid, let workspace = store.workspaceUuid else {
            error = PCStrings.signInOrgUnavailable
            return
        }
        digits = OtpCodeEntry.empty(length: Self.codeLength)
        resending = true
        error = nil
        defer { resending = false }
        do {
            let otpId = try await sendCode(org, workspace, sent.contact, sent.channel)
            self.sent = SentCode(contact: sent.contact, channel: sent.channel, countryCode: sent.countryCode, otpId: otpId)
            startCountdown()
            store.showToast(sent.channel == .sms ? PCStrings.otpSentPhone : PCStrings.otpSentEmail, kind: .success)
        } catch {
            self.error = message(for: error)
        }
    }

    func backToContact() {
        error = nil
        step = .contact
    }

    func updateDigits(_ next: [String]) {
        digits = next
        clearError()
    }

    func clearError() {
        if error != nil { error = nil }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        resendIn = Self.resendSeconds
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.resendIn = max(0, self.resendIn - 1)
                if self.resendIn == 0 { return }
            }
        }
    }
}
