import Foundation

extension ConsentInlineViewModel {
    nonisolated static func runsLedgerConsentCheck(ledgerBaseUrl: String?, applicationId: String?) -> Bool {
        NoticeBaseUrl.configured(ledgerBaseUrl) != nil && NoticeBaseUrl.configured(applicationId) == nil
    }

    /// The ledger the consent check reads: the one under the API host, or the
    /// `ledgerBaseUrl` passed.
    nonisolated static func consentCheckLedger(baseUrl: String?, ledgerBaseUrl: String?) -> String? {
        NoticeBaseUrl.resolve(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl).ledgerBaseUrl
    }

    var consentCheckLedgerBaseUrl: String? {
        Self.consentCheckLedger(baseUrl: baseUrl, ledgerBaseUrl: ledgerBaseUrl)
    }

    func checkLedgerConsent() async {
        guard Self.runsLedgerConsentCheck(ledgerBaseUrl: consentCheckLedgerBaseUrl, applicationId: applicationId),
              let token = accessToken, !token.isEmpty,
              activeConfig != nil else { return }

        let status = await ConsentAPI.fetchNoticeConsentStatus(NoticeConsentStatusParams(
            accessToken: token,
            ledgerBaseUrl: consentCheckLedgerBaseUrl,
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
