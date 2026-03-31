import Foundation

public struct DpoInfo: Codable {
    public let grievanceText: String
    public let grievanceAnchorText: String
    public let grievanceUrl: String
    public let grievanceEmail: String
    public let grievanceEmailConnectorText: String?
    public let dpBoardText: String
    public let dpBoardAnchorText: String
    public let dpBoardUrl: String
    public let dpoText: String
    public let dpoAnchorText: String
    public let dpoUrl: String

    enum CodingKeys: String, CodingKey {
        case grievanceText = "grievance_text"
        case grievanceAnchorText = "grievance_anchor_text"
        case grievanceUrl = "grievance_url"
        case grievanceEmail = "grievance_email"
        case grievanceEmailConnectorText = "grievance_email_connector_text"
        case dpBoardText = "dp_board_text"
        case dpBoardAnchorText = "dp_board_anchor_text"
        case dpBoardUrl = "dp_board_url"
        case dpoText = "dpo_text"
        case dpoAnchorText = "dpo_anchor_text"
        case dpoUrl = "dpo_url"
    }
}

public struct DpoInfoTranslation: Codable {
    public let grievanceText: String?
    public let grievanceAnchorText: String?
    public let grievanceEmailConnectorText: String?
    public let dpBoardText: String?
    public let dpBoardAnchorText: String?
    public let dpoText: String?
    public let dpoAnchorText: String?

    enum CodingKeys: String, CodingKey {
        case grievanceText = "grievance_text"
        case grievanceAnchorText = "grievance_anchor_text"
        case grievanceEmailConnectorText = "grievance_email_connector_text"
        case dpBoardText = "dp_board_text"
        case dpBoardAnchorText = "dp_board_anchor_text"
        case dpoText = "dpo_text"
        case dpoAnchorText = "dpo_anchor_text"
    }
}
