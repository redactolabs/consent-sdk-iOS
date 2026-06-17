import Foundation
import SwiftUI

@MainActor
public final class ModifyConsentViewModel: ObservableObject {
    public enum Step {
        case overview, confirmRevoke, regrantSelect
    }

    @Published public var step: Step = .overview
    @Published public var selectedDataElementUuids: Set<String> = []
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?

    public let consent: UserConsent
    public let nominatorContact: String?

    public init(consent: UserConsent, nominatorContact: String? = nil) {
        self.consent = consent
        self.nominatorContact = nominatorContact
        self.selectedDataElementUuids = Set(consent.dataElements.filter { $0.selected }.map { $0.uuid })
    }

    public var canRevoke: Bool { consent.status == .active }
    public var canRegrant: Bool { consent.status == .withdrawn || consent.status == .expired || consent.status == .declined }
    public var canRenew: Bool {
        guard consent.status == .active else { return false }
        return true
    }

    public func toggleDataElement(_ uuid: String) {
        if selectedDataElementUuids.contains(uuid) {
            selectedDataElementUuids.remove(uuid)
        } else {
            selectedDataElementUuids.insert(uuid)
        }
    }

    public func startRevoke() { step = .confirmRevoke }
    public func startRegrant() { step = .regrantSelect }
}
