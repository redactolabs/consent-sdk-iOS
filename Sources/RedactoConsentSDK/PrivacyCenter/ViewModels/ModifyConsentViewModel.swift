import Foundation
import SwiftUI

/// The Modify Consent modal (React ModifyConsentModal.tsx): one action per
/// status. Active revokes, withdrawn regrants, expired renews, and a declined
/// consent (or one this SDK cannot name) has nothing to do.
@MainActor
public final class ModifyConsentViewModel: ObservableObject {
    public enum Step {
        case overview, confirmRevoke, regrantSelect
    }

    @Published public var step: Step = .overview
    @Published public var selectedDataElementUuids: Set<String> = []
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var isAccordionOpen: Bool

    public let consent: UserConsent
    public let nominatorContact: String?

    public init(consent: UserConsent, nominatorContact: String? = nil) {
        self.consent = consent
        self.nominatorContact = nominatorContact
        let action = Self.action(for: consent.status)
        self.isAccordionOpen = action == .regrant
        if action == .regrant {
            self.selectedDataElementUuids = Set(Self.regrantEligible(consent).map(\.uuid))
        }
    }

    public static func action(for status: ConsentStatus) -> ConsentAction? {
        switch status {
        case .active: return .revoke
        case .withdrawn: return .regrant
        case .expired: return .renew
        case .declined, .unknown: return nil
        }
    }

    public var action: ConsentAction? { Self.action(for: consent.status) }

    public var canRevoke: Bool { action == .revoke }
    public var canRegrant: Bool { action == .regrant }
    public var canRenew: Bool { action == .renew }

    /// Elements a regrant can cover: enabled ones with a uuid.
    public static func regrantEligible(_ consent: UserConsent) -> [ConsentDataElement] {
        consent.dataElements.filter { !$0.uuid.isEmpty && $0.enabled }
    }

    public var regrantEligibleElements: [ConsentDataElement] { Self.regrantEligible(consent) }

    public func isRequired(_ uuid: String) -> Bool {
        regrantEligibleElements.contains { $0.uuid == uuid && $0.required }
    }

    public func isChecked(_ uuid: String) -> Bool {
        isRequired(uuid) || selectedDataElementUuids.contains(uuid)
    }

    /// A required element stays selected.
    public func toggleDataElement(_ uuid: String) {
        guard !isRequired(uuid) else { return }
        if selectedDataElementUuids.contains(uuid) {
            selectedDataElementUuids.remove(uuid)
        } else {
            selectedDataElementUuids.insert(uuid)
        }
    }

    public var nominatorLabel: String? {
        consent.nominatorInfo.map(\.displayLabel).flatMap { $0.isEmpty ? nil : $0 }
    }

    public var descriptionText: String {
        switch action {
        case .revoke: return nominatorLabel.map(PCStrings.aboutToModifyConsentOnBehalf) ?? PCStrings.aboutToModifyConsent
        case .regrant: return nominatorLabel.map(PCStrings.aboutToRegrantConsentOnBehalf) ?? PCStrings.aboutToRegrantConsent
        case .renew: return nominatorLabel.map(PCStrings.aboutToRenewConsentOnBehalf) ?? PCStrings.aboutToRenewConsent
        case nil: return ""
        }
    }

    /// The per-purpose revoke warning when the admin set one, else the default.
    public var warningText: String {
        switch action {
        case .revoke:
            if let custom = consent.revokeWarningMessage, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return custom
            }
            return PCStrings.revokeConsentWarning
        case .regrant: return PCStrings.regrantConsentWarning
        case .renew: return PCStrings.renewConsentWarning
        case nil: return ""
        }
    }

    public var buttonLabel: String {
        switch action {
        case .revoke: return PCStrings.revokeConsent
        case .regrant: return PCStrings.regrantConsent
        case .renew: return PCStrings.renewConsent
        case nil: return ""
        }
    }

    public var isConfirmDisabled: Bool {
        (consent.purposeUuid ?? "").isEmpty || (action == .regrant && selectedDataElementUuids.isEmpty)
    }

    /// What goes to the server as `data_element_uuids`: only for a regrant.
    public var dataElementUuidsForAction: [String]? {
        guard action == .regrant else { return nil }
        let required = regrantEligibleElements.filter(\.required).map(\.uuid)
        return regrantEligibleElements.map(\.uuid).filter { selectedDataElementUuids.contains($0) || required.contains($0) }
    }

    public func startRevoke() { step = .confirmRevoke }
    public func startRegrant() { step = .regrantSelect }
}
