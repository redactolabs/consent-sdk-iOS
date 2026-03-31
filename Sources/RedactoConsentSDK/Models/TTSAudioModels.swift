import Foundation

public struct TTSAudioUrlsResponse: Codable {
    public let code: Int
    public let status: String
    public let detail: TTSAudioDetail
}

public struct TTSAudioDetail: Codable {
    public let uuid: String
    public let language: String
    public let noticeTextAudioUrl: String?
    public let additionalTextAudioUrl: String?
    public let noticeSummaryAudioUrl: String?
    public let confirmButtonTextAudioUrl: String?
    public let declineButtonTextAudioUrl: String?
    public let privacyPolicyPrefixTextAudioUrl: String?
    public let privacyPolicyAnchorTextAudioUrl: String?
    public let privacyCenterAnchorTextAudioUrl: String?
    public let purposeSectionHeadingAudioUrl: String?
    public let noticeBannerHeadingAudioUrl: String?
    public let purposesAudio: [String: PurposeAudioUrls]
    public let dataElementsAudio: [String: DataElementAudioUrls]
    public let dpoInfoAudio: DpoInfoAudio?

    enum CodingKeys: String, CodingKey {
        case uuid, language
        case noticeTextAudioUrl = "notice_text_audio_url"
        case additionalTextAudioUrl = "additional_text_audio_url"
        case noticeSummaryAudioUrl = "notice_summary_audio_url"
        case confirmButtonTextAudioUrl = "confirm_button_text_audio_url"
        case declineButtonTextAudioUrl = "decline_button_text_audio_url"
        case privacyPolicyPrefixTextAudioUrl = "privacy_policy_prefix_text_audio_url"
        case privacyPolicyAnchorTextAudioUrl = "privacy_policy_anchor_text_audio_url"
        case privacyCenterAnchorTextAudioUrl = "privacy_center_anchor_text_audio_url"
        case purposeSectionHeadingAudioUrl = "purpose_section_heading_audio_url"
        case noticeBannerHeadingAudioUrl = "notice_banner_heading_audio_url"
        case purposesAudio = "purposes_audio"
        case dataElementsAudio = "data_elements_audio"
        case dpoInfoAudio = "dpo_info_audio"
    }
}

public struct PurposeAudioUrls: Codable {
    public let nameAudioUrl: String?
    public let descriptionAudioUrl: String?

    enum CodingKeys: String, CodingKey {
        case nameAudioUrl = "name_audio_url"
        case descriptionAudioUrl = "description_audio_url"
    }
}

public struct DataElementAudioUrls: Codable {
    public let nameAudioUrl: String?

    enum CodingKeys: String, CodingKey {
        case nameAudioUrl = "name_audio_url"
    }
}

public struct DpoInfoAudio: Codable {
    public let grievanceTextAudioUrl: String?
    public let grievanceAnchorTextAudioUrl: String?
    public let dpBoardTextAudioUrl: String?
    public let dpBoardAnchorTextAudioUrl: String?
    public let dpoTextAudioUrl: String?
    public let dpoAnchorTextAudioUrl: String?
    public let grievanceEmailConnectorTextAudioUrl: String?
    public let grievanceEmailAudioUrl: String?

    enum CodingKeys: String, CodingKey {
        case grievanceTextAudioUrl = "grievance_text_audio_url"
        case grievanceAnchorTextAudioUrl = "grievance_anchor_text_audio_url"
        case dpBoardTextAudioUrl = "dp_board_text_audio_url"
        case dpBoardAnchorTextAudioUrl = "dp_board_anchor_text_audio_url"
        case dpoTextAudioUrl = "dpo_text_audio_url"
        case dpoAnchorTextAudioUrl = "dpo_anchor_text_audio_url"
        case grievanceEmailConnectorTextAudioUrl = "grievance_email_connector_text_audio_url"
        case grievanceEmailAudioUrl = "grievance_email_audio_url"
    }
}
