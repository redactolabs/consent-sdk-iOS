import Foundation

/// Accessors for the keys shared with the React SDK, named after the key.
extension PCStrings {
    public static var yourRightsOverDataSimplified: String { t("yourRightsOverDataSimplified") }
    public static var descriptionLabel: String { t("descriptionLabel") }
    public static var privacyPolicy: String { t("privacyPolicy") }
    public static var raiseDataRequest: String { t("raiseDataRequest") }
    public static var exerciseYourRights: String { t("exerciseYourRights") }
    public static var fullName: String { t("fullName") }
    public static var supportingDocumentation: String { t("supportingDocumentation") }
    public static var timePeriod: String { t("timePeriod") }
    public static var captchaVerification: String { t("captchaVerification") }
    public static var uploading: String { t("uploading") }
    public static var uploadFileButton: String { t("uploadFileButton") }
    public static var confirmCheckBox: String { t("confirmCheckBox") }
    public static var revokeConsentModalTitle: String { t("revokeConsentModalTitle") }
    public static var revokeConsentModalQuestion: String { t("revokeConsentModalQuestion") }
    public static var revokeConsentModalPurposesLabel: String { t("revokeConsentModalPurposesLabel") }
    public static var revokeConsentModalConsentActive: String { t("revokeConsentModalConsentActive") }
    public static var revokeConsentModalIfYesLabel: String { t("revokeConsentModalIfYesLabel") }
    public static var revokeConsentModalIfYesBody: String { t("revokeConsentModalIfYesBody") }
    public static var revokeConsentModalYourPurposes: String { t("revokeConsentModalYourPurposes") }
    public static func revokeConsentModalAndMore(_ count: Int) -> String { t("revokeConsentModalAndMore", vars: ["count": String(count)]) }
    public static var revokeConsentYes: String { t("revokeConsentYes") }
    public static var revokeConsentNo: String { t("revokeConsentNo") }
    public static func erasureConsentRevokeNotice(_ purposes: String) -> String { t("erasureConsentRevokeNotice", vars: ["purposes": purposes]) }
    public static var requestSubmittedSuccessfully: String { t("requestSubmittedSuccessfully") }
    public static var thankYouForSubmittingYourRequest: String { t("thankYouForSubmittingYourRequest") }
    public static var caseID: String { t("caseID") }
    public static var saveThisID: String { t("saveThisID") }
    public static var someRequestsFailed: String { t("someRequestsFailed") }
    public static var retrying: String { t("retrying") }
    public static var confirmationSentTo: String { t("confirmationSentTo") }
    public static var processRequest: String { t("processRequest") }
    public static var yourDataIsSafeWithUs: String { t("yourDataIsSafeWithUs") }
    public static var enterYourEmail: String { t("enterYourEmail") }
    public static var letsConfirm: String { t("letsConfirm") }
    public static var getOtp: String { t("getOtp") }
    public static var otpVerify: String { t("otpVerify") }
    public static var enterOtp: String { t("enterOtp") }
    public static var didntReceiveCode: String { t("didntReceiveCode") }
    public static var verifyOtp: String { t("verifyOtp") }
    public static var resendOtp: String { t("resendOtp") }
    public static var deletion: String { t("deletion") }
    public static var objection: String { t("objection") }
    public static var modify: String { t("modify") }
    public static var selectAll: String { t("selectAll") }
    public static var enterCorrectValue: String { t("enterCorrectValue") }
    public static var whatDataToAccess: String { t("whatDataToAccess") }
    public static var whatDataToDelete: String { t("whatDataToDelete") }
    public static var objectingProcessingActivities: String { t("objectingProcessingActivities") }
    public static var whatDataToModify: String { t("whatDataToModify") }
    public static var enterSixDigitOtp: String { t("enterSixDigitOtp") }
    public static var invalidOtp: String { t("invalidOtp") }
    public static var enterEmailAddress: String { t("enterEmailAddress") }
    public static var enterValidEmail: String { t("enterValidEmail") }
    public static var mustBeRegisteredUserWithOrg: String { t("mustBeRegisteredUserWithOrg") }
    public static var errorSendingOtp: String { t("errorSendingOtp") }
    public static var otpSentEmail: String { t("otpSentEmail") }
    public static var signedInSuccess: String { t("signedInSuccess") }
    public static var reasonOptional: String { t("reasonOptional") }
    public static var backToHome: String { t("backToHome") }
    public static var selectGrievance: String { t("selectGrievance") }
    public static var consentViolation: String { t("consentViolation") }
    public static var unlawfulProcessing: String { t("unlawfulProcessing") }
    public static var dataBreach: String { t("dataBreach") }
    public static var export: String { t("export") }
    public static var searchConsentsProductsPurposes: String { t("searchConsentsProductsPurposes") }
    public static var exportConsentData: String { t("exportConsentData") }
    public static var exportConsentDataSubtitle: String { t("exportConsentDataSubtitle") }
    public static var exportingIncludesFilters: String { t("exportingIncludesFilters") }
    public static var failedToFetchConsentData: String { t("failedToFetchConsentData") }
    public static var missingInfoToManage: String { t("missingInfoToManage") }
    public static var missingInfoToRevoke: String { t("missingInfoToRevoke") }
    public static var errorRevokingConsent: String { t("errorRevokingConsent") }
    public static var nominatorNotFound: String { t("nominatorNotFound") }
    public static var nomineeMustSpecifyNominator: String { t("nomineeMustSpecifyNominator") }
    public static var purpose: String { t("purpose") }
    public static var givenDate: String { t("givenDate") }
    public static var untilWithdrawalNoExpiry: String { t("untilWithdrawalNoExpiry") }
    public static var method: String { t("method") }
    public static var action: String { t("action") }
    public static var modifyButton: String { t("modifyButton") }
    public static var statusRevoked: String { t("statusRevoked") }
    public static var aboutToModifyConsent: String { t("aboutToModifyConsent") }
    public static func aboutToModifyConsentOnBehalf(_ nominator: String) -> String { t("aboutToModifyConsentOnBehalf", vars: ["nominator": nominator]) }
    public static var noDataElementsAvailable: String { t("noDataElementsAvailable") }
    public static var revokeConsent: String { t("revokeConsent") }
    public static var regrantConsent: String { t("regrantConsent") }
    public static var regrantConsentWarning: String { t("regrantConsentWarning") }
    public static var aboutToRegrantConsent: String { t("aboutToRegrantConsent") }
    public static func aboutToRegrantConsentOnBehalf(_ nominator: String) -> String { t("aboutToRegrantConsentOnBehalf", vars: ["nominator": nominator]) }
    public static var renewConsent: String { t("renewConsent") }
    public static var renewConsentWarning: String { t("renewConsentWarning") }
    public static var aboutToRenewConsent: String { t("aboutToRenewConsent") }
    public static func aboutToRenewConsentOnBehalf(_ nominator: String) -> String { t("aboutToRenewConsentOnBehalf", vars: ["nominator": nominator]) }
    public static var activity: String { t("activity") }
    public static var allCaughtUp: String { t("allCaughtUp") }
    public static var noActivitiesYet: String { t("noActivitiesYet") }
    public static var noActivitiesDescription: String { t("noActivitiesDescription") }
    public static var filterReceipts: String { t("filterReceipts") }
    public static var receiptFiltersHint: String { t("receiptFiltersHint") }
    public static var filtersApplied: String { t("filtersApplied") }
    public static var receiptDateRangeInvalid: String { t("receiptDateRangeInvalid") }
    public static var activityType: String { t("activityType") }
    public static var activityDescription: String { t("activityDescription") }
    public static var timestamp: String { t("timestamp") }
    public static var searchCasesByID: String { t("searchCasesByID") }
    public static var allRequests: String { t("allRequests") }
    public static var filterByType: String { t("filterByType") }
    public static var errorLoadingCaseHistory: String { t("errorLoadingCaseHistory") }
    public static var unknownError: String { t("unknownError") }
    public static var pleaseSignInToViewGrievance: String { t("pleaseSignInToViewGrievance") }
    public static var emailNotFoundInSession: String { t("emailNotFoundInSession") }
    public static var submittedOn: String { t("submittedOn") }
    public static var viewDetails: String { t("viewDetails") }
    public static var downloadResponse: String { t("downloadResponse") }
    public static var createdAt: String { t("createdAt") }
    public static var completedAt: String { t("completedAt") }
    public static var requestSpecifics: String { t("requestSpecifics") }
    public static var purposesInvolved: String { t("purposesInvolved") }
    public static var dataToCorrect: String { t("dataToCorrect") }
    public static var field: String { t("field") }
    public static var grievanceTypes: String { t("grievanceTypes") }
    public static var sessionExpiredTitle: String { t("sessionExpiredTitle") }
    public static var sessionExpiredDescription: String { t("sessionExpiredDescription") }
    public static var rowsPerPage: String { t("rowsPerPage") }
    public static func pageOf(_ current: Int, total: Int) -> String { t("pageOf", vars: ["current": String(current), "total": String(total)]) }
    public static func rowsSelected(_ count: Int, total: Int) -> String { t("rowsSelected", vars: ["count": String(count), "total": String(total)]) }
    public static var consentManager: String { t("consentManager") }
    public static var badgeNew: String { t("badgeNew") }
    public static var translationNotAvailable: String { t("translationNotAvailable") }
    public static var failedToFetchFormData: String { t("failedToFetchFormData") }
    public static var requestSubmittedSuccess: String { t("requestSubmittedSuccess") }
    public static var requestSubmissionFailed: String { t("requestSubmissionFailed") }
    public static var submissionFailed: String { t("submissionFailed") }
    public static func failedToUploadFile(_ fileName: String) -> String { t("failedToUploadFile", vars: ["fileName": fileName]) }
    public static var fileUploadedSuccess: String { t("fileUploadedSuccess") }
    public static func uploadError(_ error: String) -> String { t("uploadError", vars: ["error": error]) }
    public static var pleaseEnterContactToVerify: String { t("pleaseEnterContactToVerify") }
    public static var missingOrgOrWorkspace: String { t("missingOrgOrWorkspace") }
    public static var contactVerifiedSuccess: String { t("contactVerifiedSuccess") }
    public static var unableToVerifyContact: String { t("unableToVerifyContact") }
    public static func noUserFoundForContact(_ contact: String) -> String { t("noUserFoundForContact", vars: ["contact": contact]) }
    public static var failedToVerifyContact: String { t("failedToVerifyContact") }
    public static var verify: String { t("verify") }
    public static var verifying: String { t("verifying") }
    public static var contactPlaceholder: String { t("contactPlaceholder") }
    public static var myConsents: String { t("myConsents") }
    public static var managing: String { t("managing") }
    public static var consentVisibility: String { t("consentVisibility") }
    public static var managingConsentsFor: String { t("managingConsentsFor") }
    public static var nominatedBy: String { t("nominatedBy") }
    public static var loadMorePurposes: String { t("loadMorePurposes") }
    public static var statusTransferred: String { t("statusTransferred") }
    public static var nomineeEmailPlaceholder: String { t("nomineeEmailPlaceholder") }
    public static var nomineeMobilePlaceholder: String { t("nomineeMobilePlaceholder") }
    public static var myDocuments: String { t("myDocuments") }
    public static var submitted: String { t("submitted") }
    public static var responseDue: String { t("responseDue") }
    public static var secureMessagesNotice: String { t("secureMessagesNotice") }
    public static var caseFinalizedMessagesTooltip: String { t("caseFinalizedMessagesTooltip") }
    public static var noMessagesYet: String { t("noMessagesYet") }
    public static var writeMessagePlaceholder: String { t("writeMessagePlaceholder") }
    public static var send: String { t("send") }
    public static var messagesSecureFooter: String { t("messagesSecureFooter") }
    public static var noDocumentsYet: String { t("noDocumentsYet") }
    public static var errorLoadingMessages: String { t("errorLoadingMessages") }
    public static var refreshMessages: String { t("refreshMessages") }
    public static var senderYou: String { t("senderYou") }
    public static var senderPrivacyTeam: String { t("senderPrivacyTeam") }
    public static var documentAccepted: String { t("documentAccepted") }
    public static var documentRejected: String { t("documentRejected") }
    public static var replacementRequested: String { t("replacementRequested") }
    public static func documentRequestedLabel(_ title: String) -> String { t("documentRequestedLabel", vars: ["title": title]) }
    public static func acceptedLabel(_ accepted: String) -> String { t("acceptedLabel", vars: ["accepted": accepted]) }
    public static var uploadAndSubmit: String { t("uploadAndSubmit") }
    public static func rejectionReasonLabel(_ reason: String) -> String { t("rejectionReasonLabel", vars: ["reason": reason]) }
    public static var docStatusPending: String { t("docStatusPending") }
    public static var docStatusUnderReview: String { t("docStatusUnderReview") }
    public static var docStatusApproved: String { t("docStatusApproved") }
    public static var docStatusRejected: String { t("docStatusRejected") }
    public static var docStatusReplacementRequested: String { t("docStatusReplacementRequested") }
    public static var redactoLogoAlt: String { t("redactoLogoAlt") }
    public static var switchToDarkMode: String { t("switchToDarkMode") }
    public static var switchToLightMode: String { t("switchToLightMode") }
    public static var loadingEllipsis: String { t("loadingEllipsis") }
    public static var clearInput: String { t("clearInput") }
    public static var selectPlaceholder: String { t("selectPlaceholder") }
    public static var searchPlaceholder: String { t("searchPlaceholder") }
    public static var noOptionsFound: String { t("noOptionsFound") }
    public static var clearSelection: String { t("clearSelection") }
    public static var closeModal: String { t("closeModal") }
    public static func totalRecords(_ count: Int) -> String { t("totalRecords", vars: ["count": String(count)]) }
    public static var goToFirstPage: String { t("goToFirstPage") }
    public static var goToPreviousPage: String { t("goToPreviousPage") }
    public static var goToNextPage: String { t("goToNextPage") }
    public static var goToLastPage: String { t("goToLastPage") }
    public static var openSidebarMenu: String { t("openSidebarMenu") }
    public static var closeSidebarMenu: String { t("closeSidebarMenu") }
    public static var expandSidebar: String { t("expandSidebar") }
    public static var collapseSidebar: String { t("collapseSidebar") }
    public static var currentValuePlaceholder: String { t("currentValuePlaceholder") }
    public static var updatedValuePlaceholder: String { t("updatedValuePlaceholder") }
    public static var removeAttachment: String { t("removeAttachment") }
    public static var document: String { t("document") }
    public static func downloadAttachment(_ fileName: String) -> String { t("downloadAttachment", vars: ["fileName": fileName]) }
    public static var sortByColumn: String { t("sortByColumn") }
    public static var failedToFetchActivityData: String { t("failedToFetchActivityData") }
    public static var acknowledged: String { t("acknowledged") }
    public static var actionNeeded: String { t("actionNeeded") }
    public static var backToManageConsent: String { t("backToManageConsent") }
    public static var consent: String { t("consent") }
    public static func daysAgo(_ count: Int) -> String { t("daysAgo", vars: ["count": String(count)]) }
    public static func hoursAgo(_ count: Int) -> String { t("hoursAgo", vars: ["count": String(count)]) }
    public static var justNow: String { t("justNow") }
    public static var loadingNotifications: String { t("loadingNotifications") }
    public static var markAllAsRead: String { t("markAllAsRead") }
    public static func minutesAgo(_ count: Int) -> String { t("minutesAgo", vars: ["count": String(count)]) }
    public static var next: String { t("next") }
    public static var noNotificationsInCategory: String { t("noNotificationsInCategory") }
    public static var noNotificationsYet: String { t("noNotificationsYet") }
    public static var notificationHub: String { t("notificationHub") }
    public static var notificationHubSubtitle: String { t("notificationHubSubtitle") }
    public static var notifications: String { t("notifications") }
    public static func paginationRange(_ start: Int, end: Int, total: Int) -> String { t("paginationRange", vars: ["start": String(start), "end": String(end), "total": String(total)]) }
    public static var previous: String { t("previous") }
    public static var refreshNotifications: String { t("refreshNotifications") }
    public static var system: String { t("system") }
    public static var total: String { t("total") }
    public static var unread: String { t("unread") }
    public static var viewAllNotifications: String { t("viewAllNotifications") }
    public static func weeksAgo(_ count: Int) -> String { t("weeksAgo", vars: ["count": String(count)]) }
    public static var manage: String { t("manage") }
    public static var purposes: String { t("purposes") }
    public static var latestActivity: String { t("latestActivity") }
    public static func activeWithCount(_ count: Int) -> String { t("activeWithCount", vars: ["count": String(count)]) }
    public static func withdrawnWithCount(_ count: Int) -> String { t("withdrawnWithCount", vars: ["count": String(count)]) }
    public static func expiredWithCount(_ count: Int) -> String { t("expiredWithCount", vars: ["count": String(count)]) }
    public static func declinedWithCount(_ count: Int) -> String { t("declinedWithCount", vars: ["count": String(count)]) }
    public static func productsAndConsentsSummary(_ products: Int, consents: Int) -> String { t("productsAndConsentsSummary", vars: ["products": String(products), "consents": String(consents)]) }
    public static func selectProductsForRequest(_ requestType: String) -> String { t("selectProductsForRequest", vars: ["requestType": requestType]) }
    public static var selectProductsForRequestGeneric: String { t("selectProductsForRequestGeneric") }
    public static var yourData: String { t("yourData") }
    public static func actingOnBehalfOf(_ nominator: String) -> String { t("actingOnBehalfOf", vars: ["nominator": nominator]) }
    public static var autoSelected: String { t("autoSelected") }
    public static var noProductsAvailable: String { t("noProductsAvailable") }
    public static var noProductsAvailableDescription: String { t("noProductsAvailableDescription") }
    public static func forProduct(_ productName: String) -> String { t("forProduct", vars: ["productName": productName]) }
    public static func actingOnBehalfOfShort(_ nominator: String) -> String { t("actingOnBehalfOfShort", vars: ["nominator": nominator]) }
    public static func nominationChipSuffix(_ nominator: String) -> String { t("nominationChipSuffix", vars: ["nominator": nominator]) }
    public static var selectPurposesForThisProduct: String { t("selectPurposesForThisProduct") }
    public static var accountMenu: String { t("accountMenu") }
}
