import Foundation

/// A JSON value exactly as the server sent it, so a published payload can be
/// checked field by field: a number is never read as a boolean, nor the
/// reverse, and a field of the wrong type falls back instead of failing the
/// whole decode.
enum PCJSONValue: Equatable, Sendable, Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([PCJSONValue])
    case object([String: PCJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PCJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: PCJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    var objectValue: [String: PCJSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    var arrayValue: [PCJSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var isNull: Bool {
        self == .null
    }
}
