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

public enum SenderRole: String, Codable, Sendable {
    case dataFiduciary = "data_fiduciary"
    case dataPrincipal = "data_principal"
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
