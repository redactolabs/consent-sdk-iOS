import Foundation

extension ConsentInlineViewModel {
    nonisolated static func runsLedgerConsentCheck(ledgerBaseUrl: String?, applicationId: String?) -> Bool {
        NoticeBaseUrl.configured(ledgerBaseUrl) != nil && NoticeBaseUrl.configured(applicationId) == nil
    }

    func checkLedgerConsent() async {
        guard Self.runsLedgerConsentCheck(ledgerBaseUrl: ledgerBaseUrl, applicationId: applicationId),
              let token = accessToken, !token.isEmpty,
              activeConfig != nil else { return }

        let status = await ConsentAPI.fetchNoticeConsentStatus(NoticeConsentStatusParams(
            accessToken: token,
            ledgerBaseUrl: ledgerBaseUrl,
            organisationUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid
        ))
        if Task.isCancelled { return }

        isCheckingConsent = false
        if status?.isFullyConsented == true {
            hasAlreadyConsented = true
            onAccept?()
            return
        }
        if autoSubmitDeferredByConsentCheck {
            autoSubmitDeferredByConsentCheck = false
            checkValidationAndAutoSubmit()
        }
    }
}
