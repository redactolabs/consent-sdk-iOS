import Foundation

/// Anchor type used to locate the framework bundle when built as a CocoaPod
/// (where `Bundle.module` is not synthesized).
private final class PCBundleToken {}

public enum PCStrings {
    private static let bundleLock = NSLock()
    private static var bundleCache: [String: Bundle] = [:]
    private static var _currentLanguage: String = "en"

    /// The bundle that holds the shipped `.lproj` resources. SwiftPM synthesizes
    /// `Bundle.module`; CocoaPods ships them in a `RedactoConsentSDK.bundle`
    /// nested in the framework, so resolve that by name there.
    private static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let container = Bundle(for: PCBundleToken.self)
        if let url = container.url(forResource: "RedactoConsentSDK", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return container
        #endif
    }()

    /// The language used by `PCStrings.t(_:)`. Set this from `PrivacyCenterStore`
    /// when the in-app language picker changes — `NSLocalizedString` alone honors
    /// the system locale, not the picker, so we resolve a per-`.lproj` `Bundle`
    /// ourselves. Reads/writes are guarded so this is safe to touch from any thread.
    public static var currentLanguage: String {
        get {
            bundleLock.lock(); defer { bundleLock.unlock() }
            return _currentLanguage
        }
        set {
            bundleLock.lock(); defer { bundleLock.unlock() }
            _currentLanguage = newValue
        }
    }

    /// Look up a localized string from the SDK bundle for `currentLanguage`.
    /// Falls back to English, then to the key itself if neither resolves.
    public static func t(_ key: String) -> String {
        let lang = currentLanguage
        let englishFallback = lookup(key, in: bundle(for: "en")) ?? key
        if lang == "en" { return englishFallback }
        return lookup(key, in: bundle(for: lang)) ?? englishFallback
    }

    /// Format a localized string with positional arguments.
    public static func t(_ key: String, _ args: CVarArg...) -> String {
        return String(format: t(key), arguments: args)
    }

    private static func lookup(_ key: String, in bundle: Bundle?) -> String? {
        guard let bundle else { return nil }
        // Use a sentinel so we can detect "key not found" instead of getting the key back.
        let sentinel = "__pc_missing__"
        let value = NSLocalizedString(key, tableName: nil, bundle: bundle, value: sentinel, comment: "")
        return value == sentinel ? nil : value
    }

    private static func bundle(for language: String) -> Bundle? {
        bundleLock.lock(); defer { bundleLock.unlock() }
        if let cached = bundleCache[language] { return cached }
        if let path = resourceBundle.path(forResource: language, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundleCache[language] = langBundle
            return langBundle
        }
        return nil
    }

    // MARK: - Common
    public static var yourPrivacyCenter: String { t("yourPrivacyCenter") }
    public static var manageConsent: String { t("manageConsent") }
    public static var manageConsentSubtitle: String { t("manageConsentSubtitle") }
    public static var dataRequests: String { t("dataRequests") }
    public static var dataRequestsSubtitle: String { t("dataRequestsSubtitle") }
    public static var dataRequestsSubtitleLong: String { t("dataRequestsSubtitleLong") }
    public static var grievanceRequests: String { t("grievanceRequests") }
    public static var grievanceSubtitle: String { t("grievanceSubtitle") }
    public static var activities: String { t("activities") }
    public static var activitiesSubtitle: String { t("activitiesSubtitle") }
    public static var caseHistory: String { t("caseHistory") }
    public static var consents: String { t("consents") }
    public static var requests: String { t("requests") }
    public static var caseDetails: String { t("caseDetails") }
    public static var requestDetails: String { t("requestDetails") }
    public static var messages: String { t("messages") }
    public static var back: String { t("back") }
    public static var signOut: String { t("signOut") }
    public static var cancel: String { t("cancel") }
    public static var submit: String { t("submit") }
    public static var save: String { t("save") }
    public static var saveDraft: String { t("saveDraft") }
    public static var close: String { t("close") }
    public static var confirm: String { t("confirm") }
    public static var continueAction: String { t("continue") }
    public static var loading: String { t("loading") }
    public static var error: String { t("error") }
    public static var retry: String { t("retry") }
    public static var search: String { t("search") }
    public static var filter: String { t("filter") }
    public static var status: String { t("status") }
    public static var product: String { t("product") }
    public static var all: String { t("all") }
    public static var processing: String { t("processing") }
    public static var completed: String { t("completed") }
    public static var rejected: String { t("rejected") }
    public static var today: String { t("today") }
    public static var yesterday: String { t("yesterday") }
    public static var description: String { t("description") }
    public static var attachment: String { t("attachment") }
    public static var contact: String { t("contact") }

    // MARK: - Statuses
    public static var statusActive: String { t("statusActive") }
    public static var statusWithdrawn: String { t("statusWithdrawn") }
    public static var statusExpired: String { t("statusExpired") }
    public static var statusDeclined: String { t("statusDeclined") }

    // MARK: - DSR Form
    public static var requestType: String { t("requestType") }
    public static var selectRequestType: String { t("selectRequestType") }
    public static var access: String { t("access") }
    public static var correction: String { t("correction") }
    public static var erasure: String { t("erasure") }
    public static var grievance: String { t("grievance") }
    public static var nomination: String { t("nomination") }
    public static var supportingDocuments: String { t("supportingDocuments") }
    public static var uploadFile: String { t("uploadFile") }
    public static var uploadAnotherFile: String { t("uploadAnotherFile") }
    public static var additionalNote: String { t("additionalNote") }
    public static var additionalNotePlaceholder: String { t("additionalNotePlaceholder") }
    public static var iConfirm: String { t("iConfirm") }
    public static var caseSubmitted: String { t("caseSubmitted") }
    public static var caseId: String { t("caseId") }
    public static var saveCaseIdNotice: String { t("saveCaseIdNotice") }
    public static var purposeQuestionAccess: String { t("purposeQuestionAccess") }
    public static var purposeQuestionErasure: String { t("purposeQuestionErasure") }
    public static var noPurposes: String { t("noPurposes") }
    public static var dataCollected: String { t("dataCollected") }
    public static var revocationNotDeletionNote: String { t("revocationNotDeletionNote") }
    public static var noFieldsAvailable: String { t("noFieldsAvailable") }
    public static var selectFieldsToUpdate: String { t("selectFieldsToUpdate") }
    public static var currentValue: String { t("currentValue") }
    public static var newValue: String { t("newValue") }
    public static var noGrievanceTypes: String { t("noGrievanceTypes") }
    public static var selectGrievanceType: String { t("selectGrievanceType") }
    public static var enterNomineeDetails: String { t("enterNomineeDetails") }
    public static var requestSubmittedTitle: String { t("requestSubmittedTitle") }
    public static var requestSubmittedSubtitle: String { t("requestSubmittedSubtitle") }
    public static var requestSubmittedNotice: String { t("requestSubmittedNotice") }

    // MARK: - Consent Manager
    public static var direct: String { t("direct") }
    public static var nominated: String { t("nominated") }
    public static var modifyConsent: String { t("modifyConsent") }
    public static var revoke: String { t("revoke") }
    public static var regrant: String { t("regrant") }
    public static var renew: String { t("renew") }
    public static var revokeConfirmTitle: String { t("revokeConfirmTitle") }
    public static var revokeConfirmBody: String { t("revokeConfirmBody") }
    public static var consentRevokedSuccess: String { t("consentRevokedSuccess") }
    public static var consentRegrantedSuccess: String { t("consentRegrantedSuccess") }
    public static var consentRenewedSuccess: String { t("consentRenewedSuccess") }
    public static var validTill: String { t("validTill") }
    public static var givenOn: String { t("givenOn") }
    public static var dataElementsLabel: String { t("dataElementsLabel") }
    public static var noConsents: String { t("noConsents") }

    // MARK: - Activity
    public static var noActivities: String { t("noActivities") }
    public static var loadMore: String { t("loadMore") }

    // MARK: - Receipts
    public static var noData: String { t("noData") }
    public static var myReceipt: String { t("myReceipt") }
    public static var myReceiptSubtitle: String { t("myReceiptSubtitle") }
    public static var event: String { t("event") }
    public static var date: String { t("date") }
    public static var time: String { t("time") }
    public static var download: String { t("download") }
    public static var consentGranted: String { t("consentGranted") }
    public static var consentRevoked: String { t("consentRevoked") }
    public static var consentDeclined: String { t("consentDeclined") }
    public static var consentExpired: String { t("consentExpired") }
    public static var failedToFetchReceipts: String { t("failedToFetchReceipts") }
    public static var failedToDownloadReceipt: String { t("failedToDownloadReceipt") }
    public static var consented: String { t("consented") }
    public static var declined: String { t("declined") }
    public static var withdrawn: String { t("withdrawn") }
    public static var dateRange: String { t("dateRange") }
    public static var allTime: String { t("allTime") }
    public static var customRange: String { t("customRange") }
    public static var from: String { t("from") }
    public static var to: String { t("to") }
    public static var clearFilters: String { t("clearFilters") }
    public static var last7Days: String { t("last7Days") }
    public static var last30Days: String { t("last30Days") }
    public static var last3Months: String { t("last3Months") }

    // MARK: - Case
    public static var noCases: String { t("noCases") }
    public static var newRequest: String { t("newRequest") }
    public static var caseCreatedAt: String { t("caseCreatedAt") }
    public static var caseDueDate: String { t("caseDueDate") }
    public static var sendMessage: String { t("sendMessage") }
    public static var typeMessage: String { t("typeMessage") }
    public static var attachFile: String { t("attachFile") }
    public static var documentRequest: String { t("documentRequest") }
    public static var uploadDocument: String { t("uploadDocument") }
    public static var rejectionReason: String { t("rejectionReason") }
    public static var secureChannelNotice: String { t("secureChannelNotice") }

    // MARK: - Grievance subtypes
    public static var grievanceConsentViolation: String { t("grievanceConsentViolation") }
    public static var grievanceUnlawfulProcessing: String { t("grievanceUnlawfulProcessing") }
    public static var grievanceDataBreach: String { t("grievanceDataBreach") }

    // MARK: - Nomination
    public static var nomineeEmail: String { t("nomineeEmail") }
    public static var nomineeMobile: String { t("nomineeMobile") }

    // MARK: - No data empty state
    public static var noDataTitle: String { t("noDataTitle") }
    public static var noDataDescription: String { t("noDataDescription") }

    // MARK: - Misc
    public static var poweredBy: String { t("poweredBy") }
    public static var someThingWentWrong: String { t("somethingWentWrong") }
}
