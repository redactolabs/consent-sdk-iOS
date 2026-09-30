import Foundation

public struct OtpVerifyResult: Equatable {
    public let ok: Bool
    public let message: String?

    public init(ok: Bool, message: String? = nil) {
        self.ok = ok
        self.message = message
    }
}

public struct OtpGate {
    public var required: Bool
    public var onVerify: (String) async throws -> OtpVerifyResult
    public var title: String?
    public var description: String?
    public var submitLabel: String?

    public init(
        required: Bool,
        onVerify: @escaping (String) async throws -> OtpVerifyResult,
        title: String? = nil,
        description: String? = nil,
        submitLabel: String? = nil
    ) {
        self.required = required
        self.onVerify = onVerify
        self.title = title
        self.description = description
        self.submitLabel = submitLabel
    }
}

struct OtpEntry: Equatable {
    let digits: [String]
    let focus: Int?
}

struct OtpPanelState: Equatable {
    var pendingMode: AcceptMode?
    var digits: [String] = OtpCodeEntry.empty()
    var error: String?
    var busy = false

    var isOpen: Bool { pendingMode != nil }
}
