import Foundation

/// The confirmation dialog's copy as the console set it, for one action. An
/// empty string is not an override: the server serves "" for a translation it
/// does not hold.
public struct ConfirmDialogCopyOverride: Equatable {
    public let title: String?
    public let detail: String?

    public static let none = ConfirmDialogCopyOverride(title: nil, detail: nil)

    public init(title: String?, detail: String?) {
        self.title = title?.nonEmpty
        self.detail = detail?.nonEmpty
    }

    /// The selected language's translation, else the notice's base text, else
    /// nothing, which leaves the dialog on its own translated copy.
    static func resolve(
        _ config: ActiveConfig?,
        language: String,
        action: ConfirmAction
    ) -> ConfirmDialogCopyOverride {
        guard let config else { return .none }
        let titleKey: String
        let detailKey: String
        let baseTitle: String?
        let baseDetail: String?
        switch action {
        case .acceptAll:
            titleKey = "confirm_accept_all_title"
            detailKey = "confirm_accept_all_detail"
            baseTitle = config.confirmAcceptAllTitle
            baseDetail = config.confirmAcceptAllDetail
        case .acceptSelected:
            titleKey = "confirm_accept_selected_title"
            detailKey = "confirm_accept_selected_detail"
            baseTitle = config.confirmAcceptSelectedTitle
            baseDetail = config.confirmAcceptSelectedDetail
        case .decline:
            titleKey = "confirm_decline_title"
            detailKey = "confirm_decline_detail"
            baseTitle = config.confirmDeclineTitle
            baseDetail = config.confirmDeclineDetail
        }
        return ConfirmDialogCopyOverride(
            title: NoticeTranslation.text(
                config, language: language, key: titleKey, defaultText: baseTitle ?? ""
            ),
            detail: NoticeTranslation.text(
                config, language: language, key: detailKey, defaultText: baseDetail ?? ""
            )
        )
    }
}
