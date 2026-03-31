import Foundation

/// Purpose translation can be either a plain string (name only) or a struct with name + description.
public enum PurposeTranslation: Codable {
    case name(String)
    case full(name: String, description: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .name(str)
            return
        }
        if let obj = try? container.decode(PurposeTranslationFull.self) {
            self = .full(name: obj.name, description: obj.description)
            return
        }
        // Fallback: treat as empty name
        self = .name("")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .name(let str):
            try container.encode(str)
        case .full(let name, let description):
            try container.encode(PurposeTranslationFull(name: name, description: description))
        }
    }

    public var nameValue: String {
        switch self {
        case .name(let str): return str
        case .full(let name, _): return name
        }
    }

    public var descriptionValue: String? {
        switch self {
        case .name: return nil
        case .full(_, let description): return description
        }
    }
}

private struct PurposeTranslationFull: Codable {
    let name: String
    let description: String
}

/// Translation data for a single language.
/// Uses custom decoding to be resilient — if any individual purpose or data element
/// translation fails to decode, it is skipped rather than failing the entire struct.
public struct LanguageTranslation: Codable {
    public let noticeText: String?
    public let additionalText: String?
    public let confirmButtonText: String?
    public let declineButtonText: String?
    public let privacyPolicyPrefixText: String?
    public let privacyPolicyAnchorText: String?
    public let privacyCenterAnchorText: String?
    public let purposeSectionHeading: String?
    public let noticeBannerHeading: String?
    public let dataElements: [String: String]?
    public let purposes: [String: PurposeTranslation]?
    public let dpoInfo: DpoInfoTranslation?

    enum CodingKeys: String, CodingKey {
        case noticeText = "notice_text"
        case additionalText = "additional_text"
        case confirmButtonText = "confirm_button_text"
        case declineButtonText = "decline_button_text"
        case privacyPolicyPrefixText = "privacy_policy_prefix_text"
        case privacyPolicyAnchorText = "privacy_policy_anchor_text"
        case privacyCenterAnchorText = "privacy_center_anchor_text"
        case purposeSectionHeading = "purpose_section_heading"
        case noticeBannerHeading = "notice_banner_heading"
        case dataElements = "data_elements"
        case purposes
        case dpoInfo = "dpo_info"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode simple string fields (all optional, won't fail)
        noticeText = try container.decodeIfPresent(String.self, forKey: .noticeText)
        additionalText = try container.decodeIfPresent(String.self, forKey: .additionalText)
        confirmButtonText = try container.decodeIfPresent(String.self, forKey: .confirmButtonText)
        declineButtonText = try container.decodeIfPresent(String.self, forKey: .declineButtonText)
        privacyPolicyPrefixText = try container.decodeIfPresent(String.self, forKey: .privacyPolicyPrefixText)
        privacyPolicyAnchorText = try container.decodeIfPresent(String.self, forKey: .privacyPolicyAnchorText)
        privacyCenterAnchorText = try container.decodeIfPresent(String.self, forKey: .privacyCenterAnchorText)
        purposeSectionHeading = try container.decodeIfPresent(String.self, forKey: .purposeSectionHeading)
        noticeBannerHeading = try container.decodeIfPresent(String.self, forKey: .noticeBannerHeading)
        dpoInfo = try? container.decodeIfPresent(DpoInfoTranslation.self, forKey: .dpoInfo)

        // Resilient decoding for purposes — decode each entry individually
        if let purposesContainer = try? container.decodeIfPresent([String: PurposeTranslation].self, forKey: .purposes) {
            purposes = purposesContainer
        } else if container.contains(.purposes) {
            // Strict decode failed; try entry-by-entry
            var result: [String: PurposeTranslation] = [:]
            if let rawDict = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .purposes) {
                for (key, value) in rawDict {
                    if let str = value.value as? String {
                        result[key] = .name(str)
                    } else if let dict = value.value as? [String: Any],
                              let name = dict["name"] as? String,
                              let desc = dict["description"] as? String {
                        result[key] = .full(name: name, description: desc)
                    }
                }
            }
            purposes = result.isEmpty ? nil : result
        } else {
            purposes = nil
        }

        // Resilient decoding for dataElements
        if let deContainer = try? container.decodeIfPresent([String: String].self, forKey: .dataElements) {
            dataElements = deContainer
        } else if container.contains(.dataElements) {
            // Try entry-by-entry with lossy string conversion
            var result: [String: String] = [:]
            if let rawDict = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .dataElements) {
                for (key, value) in rawDict {
                    if let str = value.value as? String {
                        result[key] = str
                    }
                }
            }
            dataElements = result.isEmpty ? nil : result
        } else {
            dataElements = nil
        }
    }

    /// Look up a translated text value by key
    public func value(forKey key: String) -> String? {
        switch key {
        case "notice_text": return noticeText
        case "additional_text": return additionalText
        case "confirm_button_text": return confirmButtonText
        case "decline_button_text": return declineButtonText
        case "privacy_policy_prefix_text": return privacyPolicyPrefixText
        case "privacy_policy_anchor_text": return privacyPolicyAnchorText
        case "privacy_center_anchor_text": return privacyCenterAnchorText
        case "purpose_section_heading": return purposeSectionHeading
        case "notice_banner_heading": return noticeBannerHeading
        default: return nil
        }
    }
}

/// Helper for resilient JSON decoding of heterogeneous values.
private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String {
            try container.encode(str)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}
