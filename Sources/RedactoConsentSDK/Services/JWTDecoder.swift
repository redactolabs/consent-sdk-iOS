import Foundation

public enum JWTDecoder {
    /// Decodes the payload of a JWT token without verifying the signature.
    /// Matches the behavior of the `jwt-decode` npm package.
    public static func decode(_ token: String) -> RedactoJwtPayload? {
        let segments = token.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = segments[1]
        guard let data = base64UrlDecode(payloadSegment) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(RedactoJwtPayload.self, from: data)
    }

    private static func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad with '=' to make length a multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
