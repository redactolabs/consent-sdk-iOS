import Foundation

public struct APIEnvelope<T: Decodable>: Decodable {
    public let code: Int?
    public let status: String?
    public let detail: T?
}

enum EnvelopeDecoder {
    /// Decodes the response, unwrapping the `{code,status,detail}` envelope when
    /// the JSON shape matches. Mirrors the RN `apiFetch` behaviour: only unwrap
    /// when all three of `code`, `status`, `detail` exist at the root.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["code"] != nil, json["status"] != nil, json.keys.contains("detail") {
            // Envelope shape detected. Decode the detail strictly.
            if let detailObj = json["detail"] {
                let detailData = try JSONSerialization.data(withJSONObject: detailObj, options: [])
                return try decoder.decode(T.self, from: detailData)
            }
        }
        return try decoder.decode(T.self, from: data)
    }
}
