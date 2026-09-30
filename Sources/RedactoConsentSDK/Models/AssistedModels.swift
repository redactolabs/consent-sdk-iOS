import Foundation

enum AssistedStep: Equatable {
    case notice
    case verify
}

enum AssistedVerifyMethod: Equatable {
    case mobile
    case email
}

enum AssistedPrimaryAction: Equatable {
    case acceptSelected
    case sendOtp
    case confirmOtp
}

struct AssistedAPIError: LocalizedError, Equatable {
    let status: Int?
    let code: String?
    let message: String
    let shouldRequestNew: Bool

    var errorDescription: String? { message }
}

struct AssistedEnvelope<Detail: Decodable>: Decodable {
    let detail: Detail?
}

struct CreateOtpDetail: Decodable, Equatable {
    let uuid: String
    let to: String?
    let channel: String?
    let expireAt: String?

    enum CodingKeys: String, CodingKey {
        case uuid, to, channel
        case expireAt = "expire_at"
    }
}

struct VerifyOtpDetail: Decodable, Equatable {
    let accessToken: String?
    let refreshToken: String?
    let needsSelection: Bool?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case needsSelection = "needs_selection"
    }
}

struct CreateOtpBody: Encodable {
    let to: String
    let channel: String
}

struct VerifyOtpBody: Encodable {
    let uuid: String
    let otp: String
    let purpose: String
}

struct VerifiedOtpSession: Equatable {
    let uuid: String
    let token: String
}
