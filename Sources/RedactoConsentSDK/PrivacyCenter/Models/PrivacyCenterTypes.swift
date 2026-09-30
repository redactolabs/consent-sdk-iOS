import Foundation

public enum RequestType: String, Codable, Sendable, CaseIterable {
    case access
    case correction
    case erasure
    case grievance
    case nomination

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        guard let value = RequestType(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unknown request_type \(raw)"
            )
        }
        self = value
    }
}

public enum ConsentStatus: String, Codable, Sendable {
    case active = "ACTIVE"
    case withdrawn = "WITHDRAW"
    case expired = "EXPIRED"
    case declined = "DECLINED"
    /// A status this SDK does not know. It renders without actions rather than
    /// failing the decode of every consent in the response.
    case unknown = "UNKNOWN"

    /// The servers write a revocation as `WITHDRAW`, `WITHDRAWN` or `REVOKED`
    /// (React's `ConsentStatusEnum` carries `REVOKED`); all three are one state.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).uppercased()
        switch raw {
        case "WITHDRAW", "WITHDRAWN", "REVOKED":
            self = .withdrawn
        default:
            self = ConsentStatus(rawValue: raw) ?? .unknown
        }
    }
}

public enum ConsentAction: String, Codable, Sendable {
    case revoke
    case regrant
    case renew
}

public enum GrievanceType: String, Codable, Sendable, CaseIterable {
    case consentViolation = "consent_violation"
    case unlawfulProcessing = "unlawful_processing"
    case dataBreach = "data_breach"
}

public enum MessageType: String, Codable, Sendable {
    case messageSent = "message_sent"
    case documentRequested = "document_requested"
    case documentSubmitted = "document_submitted"
    case documentReplaced = "document_replaced"
    case documentReplacementRequested = "document_replacement_requested"
    case documentApproved = "document_approved"
    case documentRejected = "document_rejected"
}

public enum DocumentRequestStatus: String, Codable, Sendable {
    case pending
    case underReview = "under_review"
    case approved
    case rejected
    case replacementRequested = "replacement_requested"
}

/// A role the server adds after this release stays `.other`, so its messages
/// are never attributed to the principal or the fiduciary.
public enum SenderRole: RawRepresentable, Codable, Sendable, Hashable {
    case dataFiduciary
    case dataPrincipal
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "data_fiduciary": self = .dataFiduciary
        case "data_principal": self = .dataPrincipal
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .dataFiduciary: return "data_fiduciary"
        case .dataPrincipal: return "data_principal"
        case .other(let raw): return raw
        }
    }
}

public enum ActivityBadgeStatus: String, Codable, Sendable {
    case success, warning, error, info, pending
}

public enum CaseStatusVariant: String, Codable, Sendable {
    case success, error, warning, info, secondary
}

public enum CaseRequestStatusFilter: String, Codable, Sendable, CaseIterable {
    case all
    case processing = "Processing"
    case completed = "Completed"
    case rejected = "Rejected"
}
