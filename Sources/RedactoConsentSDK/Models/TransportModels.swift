import Foundation

final class PendingIdempotencyKey {
    let key: String
    var inFlight = 0
    var keep = false

    init(key: String) {
        self.key = key
    }
}

enum APIErrorFallback {
    static let noticeRead = "Could not load the consent notice. Please try again."
    static let submitConsent = "Could not submit your consent. Please try again."
    static let audio = "Could not load audio narration. Please try again."
    static let guardianInfo = "Could not submit guardian details. Please try again."
    static let guardianVerification = "Could not start guardian verification. Please try again."
    static let guardianStatus = "Could not check verification status. Please try again."
    static let request = "The request could not be completed. Please try again."
}

enum APIStatusFallback {
    static let unauthorized = "Your session has expired. Please request a new access link."
    static let forbidden = "You do not have access to this resource."
    static let serverFailure = "Something went wrong on our end. Please try again later."
}
