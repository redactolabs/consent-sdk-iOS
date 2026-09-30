import Foundation

/// Strings React hardcodes in English (upload validation, fallbacks passed to
/// `t(key, fallback)`); they read the same here and stay English everywhere.
extension PCStrings {
    public static var uploadFailedGeneric: String { t("uploadFailedGeneric") }
    public static var fileEmpty: String { t("fileEmpty") }
    public static var fileTooLarge: String { t("fileTooLarge") }
    public static var fileTypeUnknown: String { t("fileTypeUnknown") }
    public static var fileTypeNotSupported: String { t("fileTypeNotSupported") }
    public static var uploadDuplicate: String { t("uploadDuplicate") }
    public static var uploadFormatRejected: String { t("uploadFormatRejected") }
    public static var uploadEmptyOrInvalid: String { t("uploadEmptyOrInvalid") }
    public static var uploadServerError: String { t("uploadServerError") }
    public static func fileUploadedNamed(_ fileName: String) -> String { t("fileUploadedNamed", vars: ["fileName": fileName]) }
    public static var failedToSubmitDocument: String { t("failedToSubmitDocument") }
    public static var noActionsAvailable: String { t("noActionsAvailable") }
    public static var selectDataElementsForRegrant: String { t("selectDataElementsForRegrant") }
    public static var mandatory: String { t("mandatory") }

    public static func activePurposes(_ count: Int) -> String { plural("activePurposes", count: count) }
    public static func consentCount(_ count: Int) -> String { plural("consentCount", count: count) }
}
