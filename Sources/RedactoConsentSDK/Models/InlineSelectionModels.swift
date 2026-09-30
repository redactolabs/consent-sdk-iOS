import Foundation

struct DataElementToggle: Equatable {
    let selectedDataElements: [String: Bool]
    let purposeSelected: Bool
}

/// What an inline notice is asking about. A change to any of it is a new read.
public struct InlineNoticeIdentity: Equatable {
    let orgUuid: String
    let workspaceUuid: String
    let noticeUuid: String
    let language: String
    let applicationId: String?
}
