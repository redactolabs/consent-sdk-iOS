import SwiftUI

public struct PCStatusBadge: View {
    let status: ConsentStatus

    public init(status: ConsentStatus) {
        self.status = status
    }

    public var body: some View {
        PCBadge(label, variant: variant)
    }

    private var label: String {
        switch status {
        case .active: return PCStrings.statusActive
        case .withdrawn: return PCStrings.statusWithdrawn
        case .expired: return PCStrings.statusExpired
        case .declined: return PCStrings.statusDeclined
        }
    }

    private var variant: PCBadgeVariant {
        switch status {
        case .active: return .success
        case .withdrawn: return .error
        case .expired: return .warning
        case .declined: return .secondary
        }
    }
}

public struct PCCaseStatusBadge: View {
    let status: String

    public init(status: String) {
        self.status = status
    }

    public var body: some View {
        let s = status.lowercased()
        let variant: PCBadgeVariant
        if s.contains("complete") || s.contains("approved") || s.contains("resolved") {
            variant = .success
        } else if s.contains("reject") || s.contains("denied") {
            variant = .error
        } else if s.contains("process") || s.contains("pending") || s.contains("progress") || s.contains("review") {
            variant = .pending
        } else {
            variant = .secondary
        }
        return PCBadge(PCFormatting.humanize(status), variant: variant)
    }
}
