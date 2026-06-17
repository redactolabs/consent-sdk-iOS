import Foundation

public struct OtpRefreshResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: String?
    public let success: Bool?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case success, message
    }
}
