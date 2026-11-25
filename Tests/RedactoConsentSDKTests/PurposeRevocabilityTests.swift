import XCTest
@testable import RedactoConsentSDK

@MainActor
final class PurposeRevocabilityTests: XCTestCase {
    typealias N = NoticeProductFixtures

    private static let credit = "purpose-credit"
    private static let offers = "purpose-offers"
    private static let warning = "Credit reporting runs for the life of the loan."
    private static let nonRevocableSentence =
        "This consent cannot be withdrawn, so the revoke option is not available."

    override func setUp() {
        super.setUp()
        PCStrings.currentLanguage = "en"
    }

    override func tearDown() {
        PCStrings.currentLanguage = "en"
        super.tearDown()
    }

    private static func noticePurpose(
        _ uuid: String,
        revocable: Bool? = nil,
        warning: String? = nil,
        productUuids: [String] = []
    ) -> [String: Any] {
        var purpose = N.optionalPurpose(uuid, uuid, productUuids)
        if let revocable { purpose["revocable"] = revocable }
        if let warning { purpose["revoke_warning_message"] = warning }
        return purpose
    }

    private static func key(_ purposeUuid: String) -> String {
        ProductMatrix.productPurposeKey(nil, purposeUuid)
    }

    private func decodeConsent(
        status: String,
        revocable: Bool? = nil,
        warning: String? = nil
    ) throws -> UserConsent {
        var payload: [String: Any] = [
            "purpose_uuid": Self.credit,
            "purpose": "Credit Reporting",
            "purpose_description": "Share repayment history with bureaus",
            "status": status,
            "given_date": "2026-01-01",
            "method": "explicit",
            "data_elements": [
                ["uuid": "element-pan", "name": "PAN", "enabled": true, "required": false, "selected": true],
            ],
        ]
        if let revocable { payload["revocable"] = revocable }
        if let warning { payload["revoke_warning_message"] = warning }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(UserConsent.self, from: data)
    }

    func testAnAbsentRevocableKeyDecodesAsRevocableOnANoticePurpose() throws {
        let content = try N.notice(products: nil, purposes: [Self.noticePurpose(Self.credit)])
        let purpose = content.detail.activeConfig.purposes[0]

        XCTAssertNil(purpose.revocable)
        XCTAssertTrue(PurposeRevocability.isRevocable(purpose.revocable))
    }

    func testAnAbsentRevocableKeyDecodesAsRevocableOnAPrivacyCenterConsent() throws {
        let consent = try decodeConsent(status: "ACTIVE")

        XCTAssertNil(consent.revocable)
        XCTAssertTrue(consent.isRevocable)
    }

    func testFalseIsTheOnlyValueThatMakesAPurposeNonRevocable() throws {
        let served = try N.notice(products: nil, purposes: [
            Self.noticePurpose(Self.credit, revocable: false),
            Self.noticePurpose(Self.offers, revocable: true),
        ])
        let purposes = served.detail.activeConfig.purposes

        XCTAssertFalse(PurposeRevocability.isRevocable(purposes[0].revocable))
        XCTAssertTrue(PurposeRevocability.isRevocable(purposes[1].revocable))
        XCTAssertFalse(try decodeConsent(status: "ACTIVE", revocable: false).isRevocable)
    }

    func testANoticeThatOmitsTheKeyEncodesWithoutIt() throws {
        let content = try N.notice(products: nil, purposes: [Self.noticePurpose(Self.credit)])
        let encoded = try JSONEncoder().encode(content.detail.activeConfig.purposes[0])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertFalse(object.keys.contains("revocable"))
        XCTAssertFalse(object.keys.contains("revoke_warning_message"))

        let again = try JSONDecoder().decode(ActiveConfigPurpose.self, from: encoded)
        XCTAssertNil(again.revocable)
        XCTAssertTrue(PurposeRevocability.isRevocable(again.revocable))
    }

    func testANonRevocablePurposeEncodesTheFlagAndTheWarning() throws {
        let content = try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)]
        )
        let encoded = try JSONEncoder().encode(content.detail.activeConfig.purposes[0])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(object["revocable"] as? Bool, false)
        XCTAssertEqual(object["revoke_warning_message"] as? String, Self.warning)
    }

    func testANonRevocableGrantedPurposeLocksWithItsWarningAsTheReason() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)],
            detail: ["purpose_selections": [Self.credit: N.recorded()]]
        ))

        XCTAssertEqual(viewModel.revocationLockReason(Self.credit, productUuid: nil), Self.warning)
        XCTAssertTrue(viewModel.isRowLocked(Self.credit, productUuid: nil))
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)

        viewModel.handlePurposeToggle(Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)

        viewModel.handleDataElementToggle("\(Self.credit)-extra", purposeUuid: Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)
    }

    func testANonRevocablePurposeOnAFirstEncounterStaysFreelyRefusable() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)]
        ))

        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: nil))
        XCTAssertFalse(viewModel.isRowLocked(Self.credit, productUuid: nil))
        XCTAssertNotEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)

        viewModel.handlePurposeToggle(Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)

        viewModel.handlePurposeToggle(Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], false)
    }

    func testANonRevocablePurposeTheVisitorWithdrewEarlierStaysRefusable() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)],
            detail: ["purpose_selections": [
                Self.credit: N.recorded(selected: false, status: "WITHDRAW"),
            ]]
        ))

        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: nil))
        XCTAssertFalse(viewModel.isRowLocked(Self.credit, productUuid: nil))
    }

    func testARevocableGrantedPurposeBehavesAsItDoesToday() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.offers)],
            detail: ["purpose_selections": [Self.offers: N.recorded()]]
        ))

        XCTAssertNil(viewModel.revocationLockReason(Self.offers, productUuid: nil))
        XCTAssertFalse(viewModel.isRowLocked(Self.offers, productUuid: nil))

        viewModel.handlePurposeToggle(Self.offers)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.offers)], false)
    }

    func testTheProductControlCannotWithdrawANonRevocableGrantedPurpose() throws {
        let viewModel = N.viewModel(try N.notice(
            products: [N.product("prod-a", "Product A", mandatory: nil)],
            purposes: [
                Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning),
                Self.noticePurpose(Self.offers),
            ],
            detail: ["purpose_selections": [
                Self.credit: N.recorded(),
                Self.offers: N.recorded(),
            ]]
        ))

        viewModel.handleSoleProductCheckboxChange(to: false)

        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.offers)], false)
    }

    func testTheLockedReasonSaysTheConsentCannotBeWithdrawn() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false)],
            detail: ["purpose_selections": [Self.credit: N.recorded()]]
        ))

        XCTAssertEqual(
            viewModel.revocationLockReason(Self.credit, productUuid: nil),
            Self.nonRevocableSentence
        )
        XCTAssertNotEqual(
            viewModel.revocationLockReason(Self.credit, productUuid: nil),
            PCStrings.revokeConsentWarning
        )
    }

    func testTheLockedReasonFollowsTheNoticesOwnLanguageNotThePrivacyCentres() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false)],
            detail: ["purpose_selections": [Self.credit: N.recorded()]]
        ))
        viewModel.selectedLanguage = "Hindi"
        PCStrings.currentLanguage = "ta"

        let hindi = NoticeChromeCopy.forLanguage("Hindi").nonRevocableReason
        XCTAssertNotEqual(hindi, Self.nonRevocableSentence)
        XCTAssertEqual(viewModel.revocationLockReason(Self.credit, productUuid: nil), hindi)
    }

    func testEveryNoticeLanguageCarriesTheNonRevocableReason() {
        for language in NoticeChromeCopy.languages {
            let reason = NoticeChromeCopy.forLanguage(language).nonRevocableReason
            XCTAssertFalse(reason.trimmingCharacters(in: .whitespaces).isEmpty, language)
            if language != "en" {
                XCTAssertNotEqual(reason, Self.nonRevocableSentence, language)
            }
        }
        XCTAssertEqual(NoticeChromeCopy.english.nonRevocableReason, Self.nonRevocableSentence)
    }

    func testALockedRowAlwaysRendersSelected() throws {
        let shapes: [(String, [String: Any])] = [
            ("active", N.recorded()),
            ("legacy with no status", N.recorded(status: "")),
        ]
        for (name, recorded) in shapes {
            let viewModel = N.viewModel(try N.notice(
                products: nil,
                purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)],
                detail: ["purpose_selections": [Self.credit: recorded]]
            ))

            XCTAssertEqual(viewModel.recordedPurposeSelections[Self.key(Self.credit)], true, name)
            XCTAssertNotNil(viewModel.revocationLockReason(Self.credit, productUuid: nil), name)
            XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true, name)
        }
    }

    func testALegacyGrantWithNoStatusIsRestoredRatherThanPreselected() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.offers)],
            config: ["purpose_preselection": "NONE"],
            detail: ["purpose_selections": [Self.offers: N.recorded(status: "")]]
        ))

        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.offers)], true)
        XCTAssertNil(viewModel.revocationLockReason(Self.offers, productUuid: nil))
    }

    func testTheSeedAndTheBaselineAgreeOnWhatCountsAsAGrant() {
        let shapes: [(String, PurposeSelection, Bool)] = [
            ("active", PurposeSelection(selected: true, status: "ACTIVE", needsReconsent: false, dataElements: [:]), true),
            ("legacy with no status", PurposeSelection(selected: true, status: "", needsReconsent: false, dataElements: [:]), true),
            ("unselected", PurposeSelection(selected: false, status: "", needsReconsent: false, dataElements: [:]), false),
            ("needs reconsent", PurposeSelection(selected: true, status: "ACTIVE", needsReconsent: true, dataElements: [:]), false),
            ("expired", PurposeSelection(selected: true, status: "EXPIRED", needsReconsent: false, dataElements: [:]), false),
            ("inactive", PurposeSelection(selected: true, status: "INACTIVE", needsReconsent: false, dataElements: [:]), false),
        ]
        for (name, selection, isGrant) in shapes {
            XCTAssertEqual(ProductConsent.isRecordedGrant(selection), isGrant, name)
            if isGrant {
                XCTAssertTrue(PurposePreselectionLogic.hasRecordedState(selection), name)
            }
        }
        XCTAssertFalse(ProductConsent.isRecordedGrant(nil))
    }

    func testAnInactiveRecordIsStillNeitherAGrantNorRecordedState() {
        let inactive = PurposeSelection(selected: true, status: "INACTIVE", needsReconsent: false, dataElements: [:])

        XCTAssertFalse(ProductConsent.isRecordedGrant(inactive))
        XCTAssertFalse(PurposePreselectionLogic.hasRecordedState(inactive))
    }

    func testTheLockIsKeyedPerProductNotPerPurpose() throws {
        let viewModel = N.viewModel(try N.notice(
            products: N.twoProducts(),
            purposes: [Self.noticePurpose(
                Self.credit,
                revocable: false,
                warning: Self.warning,
                productUuids: ["prod-a", "prod-b"]
            )],
            detail: ["product_purpose_selections": ["prod-a": [Self.credit: N.recorded()]]]
        ))

        XCTAssertEqual(
            viewModel.revocationLockReason(Self.credit, productUuid: "prod-a"),
            Self.warning
        )
        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: "prod-b"))
        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: nil))
        XCTAssertTrue(viewModel.isRowLocked(Self.credit, productUuid: "prod-a"))
        XCTAssertFalse(viewModel.isRowLocked(Self.credit, productUuid: "prod-b"))

        viewModel.handlePurposeToggle(Self.credit, productUuid: "prod-a")
        XCTAssertEqual(viewModel.selectedPurposes[ProductMatrix.productPurposeKey("prod-a", Self.credit)], true)

        viewModel.handlePurposeToggle(Self.credit, productUuid: "prod-b")
        XCTAssertEqual(viewModel.selectedPurposes[ProductMatrix.productPurposeKey("prod-b", Self.credit)], true)
    }

    func testANonRevocablePurposeNeedingReconsentStaysRefusable() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)],
            detail: [
                "reconsent_required": true,
                "purpose_selections": [Self.credit: N.recorded(needsReconsent: true)],
            ]
        ))

        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: nil))

        viewModel.handlePurposeToggle(Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], false)
    }

    func testANonRevocableExpiredGrantStaysRefusable() throws {
        let viewModel = N.viewModel(try N.notice(
            products: nil,
            purposes: [Self.noticePurpose(Self.credit, revocable: false, warning: Self.warning)],
            detail: ["purpose_selections": [Self.credit: N.recorded(status: "EXPIRED")]]
        ))

        XCTAssertNil(viewModel.revocationLockReason(Self.credit, productUuid: nil))

        viewModel.handlePurposeToggle(Self.credit)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], false)
    }

    func testSelectAllOnASoleProductReconsentLeavesInForceGrantsAlone() throws {
        let viewModel = N.viewModel(try N.notice(
            products: [N.product("prod-a", "Product A", mandatory: nil)],
            purposes: [Self.noticePurpose(Self.credit), Self.noticePurpose(Self.offers)],
            detail: [
                "reconsent_required": true,
                "purpose_selections": [
                    Self.credit: N.recorded(),
                    Self.offers: N.recorded(needsReconsent: true),
                ],
            ]
        ))

        XCTAssertEqual(viewModel.categorizedPurposes?.alreadyConsented.map(\.uuid), [Self.credit])
        XCTAssertTrue(viewModel.isRowLocked(Self.credit, productUuid: nil))
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.offers)], true)

        viewModel.handleSoleProductCheckboxChange()

        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.credit)], true)
        XCTAssertEqual(viewModel.selectedPurposes[Self.key(Self.offers)], false)
    }

    func testRevokeIsDisabledForAnActiveNonRevocablePurpose() throws {
        let viewModel = ModifyConsentViewModel(
            consent: try decodeConsent(status: "ACTIVE", revocable: false, warning: Self.warning)
        )

        XCTAssertEqual(viewModel.action, .revoke)
        XCTAssertTrue(viewModel.isRevokeBlockedByPurpose)
        XCTAssertTrue(viewModel.isConfirmDisabled)
        XCTAssertEqual(viewModel.revokeBlockedReason, Self.warning)
        XCTAssertEqual(viewModel.warningText, Self.warning)

        viewModel.startRevoke()
        if case .overview = viewModel.step {} else {
            XCTFail("a blocked revoke must not advance past the overview")
        }
    }

    func testTheBlockedReasonSaysTheRevokeOptionIsNotAvailable() throws {
        let viewModel = ModifyConsentViewModel(
            consent: try decodeConsent(status: "ACTIVE", revocable: false)
        )

        XCTAssertEqual(viewModel.revokeBlockedReason, Self.nonRevocableSentence)
        XCTAssertEqual(viewModel.warningText, Self.nonRevocableSentence)
        XCTAssertNotEqual(viewModel.warningText, PCStrings.revokeConsentWarning)
    }

    func testABlockedRevokeIgnoresTheOrganisationWithdrawWarning() throws {
        let viewModel = ModifyConsentViewModel(
            consent: try decodeConsent(status: "ACTIVE", revocable: false),
            organisationWarning: "Our own withdrawal note."
        )

        XCTAssertEqual(viewModel.warningText, Self.nonRevocableSentence)
    }

    func testARevocableRevokeStillPrefersTheOrganisationWithdrawWarning() throws {
        let viewModel = ModifyConsentViewModel(
            consent: try decodeConsent(status: "ACTIVE"),
            organisationWarning: "Our own withdrawal note."
        )

        XCTAssertEqual(viewModel.warningText, "Our own withdrawal note.")
    }

    func testTheBlockedReasonStillPrefersThePurposesOwnWords() throws {
        let viewModel = ModifyConsentViewModel(
            consent: try decodeConsent(status: "ACTIVE", revocable: false, warning: Self.warning),
            organisationWarning: "Our own withdrawal note."
        )

        XCTAssertEqual(viewModel.revokeBlockedReason, Self.warning)
    }

    func testEveryPrivacyCentreLanguageCarriesTheBlockedReason() {
        for language in PrivacyCenterLanguages.all.map(\.code) {
            PCStrings.currentLanguage = language
            let reason = PCStrings.nonRevocableConsentWarning
            XCTAssertFalse(reason.trimmingCharacters(in: .whitespaces).isEmpty, language)
            XCTAssertNotEqual(reason, "nonRevocableConsentWarning", language)
            if language != "en" {
                XCTAssertNotEqual(reason, Self.nonRevocableSentence, language)
            }
        }
    }

    func testRevokeIsUnchangedWhenTheServerOmitsTheKey() throws {
        let viewModel = ModifyConsentViewModel(consent: try decodeConsent(status: "ACTIVE"))

        XCTAssertFalse(viewModel.isRevokeBlockedByPurpose)
        XCTAssertFalse(viewModel.isConfirmDisabled)
        XCTAssertNil(viewModel.revokeBlockedReason)

        viewModel.startRevoke()
        if case .confirmRevoke = viewModel.step {} else {
            XCTFail("a revocable purpose still reaches the confirm step")
        }
    }

    func testRegrantAndRenewIgnoreTheFlag() throws {
        for status in ["WITHDRAW", "EXPIRED"] {
            let viewModel = ModifyConsentViewModel(
                consent: try decodeConsent(status: status, revocable: false, warning: Self.warning)
            )

            XCTAssertFalse(viewModel.isRevokeBlockedByPurpose, status)
            XCTAssertFalse(viewModel.isConfirmDisabled, status)
            XCTAssertNil(viewModel.revokeBlockedReason, status)
        }
    }

    private func consentManager() -> (ConsentManagerViewModel, PrivacyCenterStore) {
        PCMockURLProtocol.reset()
        let store = PrivacyCenterStore(
            baseUrl: PCFixtures.base,
            slug: "acme",
            accessToken: PCFixtures.liveToken,
            refreshToken: "refresh-1",
            themeMode: .light,
            initialPage: .consentManager,
            onBack: nil,
            onError: { _ in false },
            language: "en",
            urlSession: PCFixtures.session(),
            ledgerBaseUrl: nil
        )
        return (ConsentManagerViewModel(store: store), store)
    }

    func testTheHostFacingPerformActionRefusesABlockedRevoke() async {
        let (viewModel, store) = consentManager()

        await viewModel.performAction(
            purposeId: Self.credit,
            action: .revoke,
            revocable: false,
            revokeWarningMessage: Self.warning
        )

        XCTAssertEqual(store.toast?.text, Self.warning)
        XCTAssertTrue(PCMockURLProtocol.requests.isEmpty)
    }

    func testTheHostFacingPerformActionRefusesABlockedRevokeWithTheDefaultReason() async {
        let (viewModel, store) = consentManager()

        await viewModel.performAction(purposeId: Self.credit, action: .revoke, revocable: false)

        XCTAssertEqual(store.toast?.text, Self.nonRevocableSentence)
        XCTAssertTrue(PCMockURLProtocol.requests.isEmpty)
    }

    func testTheHostFacingPerformActionLetsARevocableRevokeThrough() async {
        let (viewModel, store) = consentManager()

        await viewModel.performAction(purposeId: Self.credit, action: .revoke)

        XCTAssertNotEqual(store.toast?.text, Self.nonRevocableSentence)
        XCTAssertNotEqual(store.toast?.text, Self.warning)
    }

    func testTheFlagSurvivesTheGroupedConsentMapper() throws {
        let payload: [String: Any] = [
            "direct": [[
                "product_uuid": "prod-a",
                "product_name": "Product A",
                "active_purposes": 1,
                "has_more_purposes": false,
                "purposes": [[
                    "purpose_uuid": Self.credit,
                    "name": "Credit Reporting",
                    "status": "ACTIVE",
                    "method": "explicit",
                    "data_elements": [],
                    "revocable": false,
                    "revoke_warning_message": Self.warning,
                ]],
            ]],
        ]
        let detail = try JSONDecoder().decode(
            UserConsentDetail.self,
            from: try JSONSerialization.data(withJSONObject: payload)
        )
        let groups = ConsentManagerNormalization.directGroups(from: detail)

        XCTAssertEqual(groups.first?.purposes.first?.revocable, false)
        XCTAssertEqual(groups.first?.purposes.first?.isRevocable, false)
        XCTAssertEqual(groups.first?.purposes.first?.revokeWarningMessage, Self.warning)
    }
}
