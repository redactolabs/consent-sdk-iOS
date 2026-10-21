import XCTest
@testable import RedactoConsentSDK

/// Port of the React SDK's `settings/resolve.test.ts`, `languages.test.ts`,
/// `placeholders.test.ts` and `requests.test.ts`.
final class PrivacyCenterSettingsTests: XCTestCase {
    private let defaults = ResolvedPrivacyCenterSettings.defaults

    private func json(_ object: Any) -> PCJSONValue {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])
        return try! JSONDecoder().decode(PCJSONValue.self, from: data)
    }

    private func resolve(_ object: Any?, _ overrides: PrivacyCenterSettings? = nil) -> ResolvedPrivacyCenterSettings {
        PrivacyCenterSettingsResolver.resolve(published: object.map(json), overrides: overrides)
    }

    // MARK: - Resolver

    func testIsTheDefaultsWhenNothingWasPublished() {
        XCTAssertEqual(resolve(nil), defaults)
        XCTAssertEqual(resolve(nil, PrivacyCenterSettings()), defaults)
        XCTAssertEqual(resolve("junk"), defaults)
    }

    func testKeepsValidPublishedValues() {
        let settings = resolve([
            "branding": [
                "inherit_colors": false, "primary_color": "#112233", "style": "glass",
                "corner_radius": 12, "font_family": "Georgia", "inherit_font": false,
            ],
            "portal": ["welcome_enabled": true, "session_timeout_minutes": 30, "withdraw_warning": "  Careful  "],
            "footer": ["copyright": "© {year} {legal}", "links": [["label": "Terms", "url": "https://acme.test/terms"]]],
        ])
        XCTAssertFalse(settings.branding.inheritColors)
        XCTAssertEqual(settings.branding.primaryColor, "#112233")
        XCTAssertEqual(settings.branding.style, .glass)
        XCTAssertEqual(settings.branding.cornerRadius, 12)
        XCTAssertEqual(settings.branding.fontFamily, "Georgia")
        XCTAssertTrue(settings.portal.welcomeEnabled)
        XCTAssertEqual(settings.portal.sessionTimeoutMinutes, 30)
        XCTAssertEqual(settings.portal.withdrawWarning, "Careful")
        XCTAssertEqual(settings.footer.links, [PrivacyCenterFooterLink(label: "Terms", url: "https://acme.test/terms")])
        XCTAssertEqual(settings.footer.copyright, "© {year} {legal}")
    }

    func testDropsMalformedValuesForTheDefaults() {
        let settings = resolve([
            "branding": [
                "primary_color": "red", "logo_url": "http://insecure.test/logo.png", "logo_height": 400,
                "style": "neon", "font_family": "Comic Sans MS", "corner_radius": -3,
            ],
            "sign_in": ["layout": "carousel", "channels": "fax", "default_country_code": "+999", "title": "   "],
            "footer": ["links": [["label": "x", "url": "javascript:alert(1)"], ["label": "", "url": "https://a.test"]]],
        ])
        XCTAssertNil(settings.branding.primaryColor)
        XCTAssertNil(settings.branding.logoUrl)
        XCTAssertEqual(settings.branding.logoHeight, 96)
        XCTAssertEqual(settings.branding.style, .classic)
        XCTAssertNil(settings.branding.fontFamily)
        XCTAssertEqual(settings.branding.cornerRadius, 0)
        XCTAssertEqual(settings.signIn.layout, .card)
        XCTAssertEqual(settings.signIn.channels, .both)
        XCTAssertEqual(settings.signIn.defaultCountryCode, "+91")
        XCTAssertEqual(settings.signIn.title, defaults.signIn.title)
        XCTAssertEqual(settings.footer.links, [])
    }

    // A number is never read as a boolean, nor the reverse.
    func testDoesNotConfuseNumbersAndBooleans() {
        let settings = resolve(["portal": ["welcome_enabled": 1, "session_timeout_minutes": true]])
        XCTAssertFalse(settings.portal.welcomeEnabled)
        XCTAssertNil(settings.portal.sessionTimeoutMinutes)
    }

    func testTreatsAnEmptyOptionalStringAsTheBuiltIn() {
        let settings = resolve(["sign_in": ["tagline": "", "field_label": "  "]])
        XCTAssertNil(settings.signIn.tagline)
        XCTAssertNil(settings.signIn.fieldLabel)
    }

    func testSectionsKeepThePublishedOrderAndLabels() {
        let settings = resolve(["portal": ["sections": [
            ["key": "activity", "label": "History", "enabled": true],
            ["key": "consent-manager", "label": NSNull(), "enabled": true],
            ["key": "form", "label": NSNull(), "enabled": false],
            ["key": "receipts", "label": NSNull(), "enabled": true],
            ["key": "notifications", "label": NSNull(), "enabled": false],
        ]]])
        XCTAssertEqual(settings.portal.sections.map(\.key), [.activity, .consentManager, .form, .receipts, .notifications])
        XCTAssertEqual(settings.portal.sections[0], PrivacyCenterSection(key: .activity, label: "History", enabled: true))
        XCTAssertFalse(settings.portal.sections[2].enabled)
    }

    func testRequestTypesDropUnknownAndRepeatedKeysAndAddBackMissingOnes() {
        let settings = resolve(["portal": ["request_types": [
            ["key": "grievance", "label": "Complaint", "enabled": true],
            ["key": "grievance", "label": "Again", "enabled": false],
            ["key": "portability", "label": NSNull(), "enabled": true],
        ]]])
        XCTAssertEqual(settings.portal.requestTypes.map(\.key), [.grievance, .access, .correction, .erasure, .nomination])
        XCTAssertEqual(settings.portal.requestTypes[0], PrivacyCenterRequestTypeSetting(key: .grievance, label: "Complaint", enabled: true))
    }

    func testFallsBackToTheDefaultSectionsWhenNothingWouldBeEnabled() {
        let sections = PrivacyCenterSectionKey.allCases.map { ["key": $0.rawValue, "label": NSNull(), "enabled": false] as [String: Any] }
        XCTAssertEqual(resolve(["portal": ["sections": sections]]).portal.sections, defaults.portal.sections)
    }

    func testKeepsLanguagesConsistent() {
        let settings = resolve(["languages": ["enabled": ["ta", "en", "xx"], "default": "hi", "auto_detect": false]])
        XCTAssertEqual(settings.languages.enabled, ["en", "ta"])
        XCTAssertEqual(settings.languages.defaultLanguage, "en")
        XCTAssertFalse(settings.languages.autoDetect)
    }

    func testCapsTheSessionTimeoutAndIgnoresNonsense() {
        XCTAssertEqual(resolve(["portal": ["session_timeout_minutes": 15]]).portal.sessionTimeoutMinutes, 15)
        XCTAssertNil(resolve(["portal": ["session_timeout_minutes": 0]]).portal.sessionTimeoutMinutes)
        XCTAssertEqual(resolve(["portal": ["session_timeout_minutes": 99999]]).portal.sessionTimeoutMinutes, 1440)
        XCTAssertEqual(resolve(["portal": ["session_timeout_minutes": 0.4]]).portal.sessionTimeoutMinutes, 0)
    }

    func testClampsHugeNumbersWithoutTrapping() {
        let huge = resolve([
            "branding": ["logo_height": 1e20, "corner_radius": 1e20],
            "portal": ["session_timeout_minutes": 1e20],
        ])
        XCTAssertEqual(huge.branding.logoHeight, 96)
        XCTAssertEqual(huge.branding.cornerRadius, 24)
        XCTAssertEqual(huge.portal.sessionTimeoutMinutes, 1440)

        let negative = resolve([
            "branding": ["logo_height": -1e20, "corner_radius": -1e20],
            "portal": ["session_timeout_minutes": -1e20],
        ])
        XCTAssertEqual(negative.branding.logoHeight, 28)
        XCTAssertEqual(negative.branding.cornerRadius, 0)
        XCTAssertNil(negative.portal.sessionTimeoutMinutes)
    }

    func testRevokeOnErasureIsNilUnlessDecided() {
        XCTAssertNil(resolve(nil).portal.revokeConsentsOnErasure)
        XCTAssertEqual(resolve(["portal": ["revoke_consents_on_erasure": true]]).portal.revokeConsentsOnErasure, true)
        XCTAssertNil(resolve(["portal": ["revoke_consents_on_erasure": NSNull()]]).portal.revokeConsentsOnErasure)
    }

    func testKeepsOnlyKnownGrievanceCategories() {
        XCTAssertEqual(resolve(["portal": ["grievance_categories": ["data_breach", "spam"]]]).portal.grievanceCategories, [.dataBreach])
        XCTAssertEqual(resolve(["portal": ["grievance_categories": ["spam"]]]).portal.grievanceCategories, defaults.portal.grievanceCategories)
    }

    // MARK: - Host overrides

    private let published: [String: Any] = [
        "branding": ["style": "glass", "inherit_colors": false, "primary_color": "#112233"],
        "portal": ["welcome_enabled": true, "welcome_title": "Hello"],
    ]

    func testOverridesMergeFieldByFieldOverEachPublishedGroup() {
        let settings = resolve(published, PrivacyCenterSettings(
            branding: .init(primaryColor: "#445566"),
            portal: .init(welcomeTitle: "Hi there")
        ))
        XCTAssertEqual(settings.branding.style, .glass)
        XCTAssertFalse(settings.branding.inheritColors)
        XCTAssertEqual(settings.branding.primaryColor, "#445566")
        XCTAssertTrue(settings.portal.welcomeEnabled)
        XCTAssertEqual(settings.portal.welcomeTitle, "Hi there")
    }

    func testTheLegacyThemeIsTheStyle() {
        XCTAssertEqual(resolve(published, PrivacyCenterSettings(theme: "classic")).branding.style, .classic)
        XCTAssertEqual(resolve(nil, PrivacyCenterSettings(theme: "glass")).branding.style, .glass)
        XCTAssertEqual(PrivacyCenterSettings(theme: "neon").appearance, .classic)
    }

    func testBrandingStyleWinsOverTheme() {
        let settings = resolve(nil, PrivacyCenterSettings(theme: "classic", branding: .init(style: "glass")))
        XCTAssertEqual(settings.branding.style, .glass)
    }

    func testOverridesAreValidatedLikeThePublishedValues() {
        XCTAssertNil(resolve(nil, PrivacyCenterSettings(branding: .init(primaryColor: "blue"))).branding.primaryColor)
    }

    func testADoubleOptionalClearsAPublishedValue() {
        let timed: [String: Any] = ["portal": ["session_timeout_minutes": 30, "revoke_consents_on_erasure": false]]
        let cleared = resolve(timed, PrivacyCenterSettings(portal: .init(revokeConsentsOnErasure: .some(nil), sessionTimeoutMinutes: .some(nil))))
        XCTAssertNil(cleared.portal.sessionTimeoutMinutes)
        XCTAssertNil(cleared.portal.revokeConsentsOnErasure)
        let kept = resolve(timed, PrivacyCenterSettings(portal: .init(welcomeEnabled: true)))
        XCTAssertEqual(kept.portal.sessionTimeoutMinutes, 30)
        XCTAssertEqual(kept.portal.revokeConsentsOnErasure, false)
    }

    func testTypedOverridesReachEveryGroup() {
        let settings = resolve(nil, PrivacyCenterSettings(
            signIn: .init(layout: .split, highlights: ["One", "Two", "Three", "Four"], channels: .email),
            languages: .init(enabled: ["hi", "en"], defaultLanguage: "hi"),
            footer: .init(links: [PrivacyCenterFooterLink(label: "Terms", url: "https://acme.test/terms")], showPoweredBy: false)
        ))
        XCTAssertEqual(settings.signIn.layout, .split)
        XCTAssertEqual(settings.signIn.channels, .email)
        XCTAssertEqual(settings.signIn.highlights, ["One", "Two", "Three"])
        XCTAssertEqual(settings.languages.enabled, ["en", "hi"])
        XCTAssertEqual(settings.languages.defaultLanguage, "hi")
        XCTAssertEqual(settings.footer.links.count, 1)
        XCTAssertFalse(settings.footer.showPoweredBy)
    }

    func testOnlyRealOverridesCountAsCustomising() {
        XCTAssertFalse(PrivacyCenterSettings().overridesPublishedSettings)
        XCTAssertFalse(PrivacyCenterSettings(theme: "glass").overridesPublishedSettings)
        XCTAssertTrue(PrivacyCenterSettings(portal: .init(welcomeEnabled: true)).overridesPublishedSettings)
    }

    // MARK: - Brand contact

    func testBrandContactIsEmptyWhenTheServerSendsNothing() {
        XCTAssertEqual(PrivacyCenterSettingsResolver.brandContact(nil), .empty)
    }

    func testBrandContactKeepsWellFormedDetailsAndDropsTheRest() {
        let contact = PrivacyCenterSettingsResolver.brandContact(json([
            "legal_entity_name": " Acme Bank Ltd ",
            "privacy_policy_url": "https://acme.test/privacy",
            "grievance_email": "dpo@acme.test",
            "grievance_url": "http://acme.test/grievance",
            "dp_board_url": "javascript:alert(1)",
        ]))
        XCTAssertEqual(contact, PrivacyCenterBrandContact(
            legalEntityName: "Acme Bank Ltd",
            privacyPolicyUrl: "https://acme.test/privacy",
            grievanceEmail: "dpo@acme.test"
        ))
        XCTAssertNil(PrivacyCenterSettingsResolver.brandContact(json(["grievance_email": "not an email"])).grievanceEmail)
    }

    // MARK: - Languages

    private func languages(enabled: [String]? = nil, defaultLanguage: String = "en", autoDetect: Bool = true) -> PrivacyCenterLanguageSettings {
        PrivacyCenterLanguageSettings(
            enabled: enabled ?? defaults.languages.enabled,
            defaultLanguage: defaultLanguage,
            autoDetect: autoDetect,
            showSwitcher: true
        )
    }

    func testKeepsTheDetectedLanguageWhenEnabledAndDetectionIsOn() {
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "hi", languages: languages(), userChoice: nil), "hi")
    }

    func testUsesTheDefaultWhenDetectionIsOff() {
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "hi", languages: languages(defaultLanguage: "ta", autoDetect: false), userChoice: nil), "ta")
    }

    func testNeverKeepsADisabledLanguage() {
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "hi", languages: languages(enabled: ["en", "ta"], defaultLanguage: "ta"), userChoice: nil), "ta")
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "fr", languages: languages(), userChoice: nil), "en")
    }

    func testKeepsWhatTheVisitorPickedWhileItStaysEnabled() {
        let config = languages(enabled: ["en", "ta"], autoDetect: false)
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "ta", languages: config, userChoice: "ta"), "ta")
        XCTAssertEqual(PrivacyCenterLanguagePolicy.pick(current: "hi", languages: config, userChoice: "hi"), "en")
    }

    func testUrduSindhiAndKashmiriReadRightToLeft() {
        for code in ["ur", "sd", "ks"] {
            XCTAssertTrue(PrivacyCenterLanguagePolicy.isRightToLeft(code), code)
        }
        for code in ["en", "hi", ""] {
            XCTAssertFalse(PrivacyCenterLanguagePolicy.isRightToLeft(code), code)
        }
        XCTAssertFalse(PrivacyCenterLanguagePolicy.isRightToLeft(nil))
    }

    func testAsksForSettingsOnlyInAShippedLanguage() {
        XCTAssertEqual(PrivacyCenterLanguagePolicy.requestLanguage("mni-Mtei"), "mni-Mtei")
        XCTAssertEqual(PrivacyCenterLanguagePolicy.requestLanguage("fr"), "en")
    }

    // MARK: - Placeholders

    private let context = PrivacyCenterPlaceholderContext(brand: "Acme", legal: "Acme Holdings Ltd", year: 2026)

    func testFillsEveryToken() {
        var full = context
        full.contact = "jane@example.com"
        full.name = "Jane"
        XCTAssertEqual(
            PrivacyCenterCopy.fillPlaceholders("{brand} · © {year} {legal} · {contact} · {name}", full),
            "Acme · © 2026 Acme Holdings Ltd · jane@example.com · Jane"
        )
    }

    func testFallsBackToTheBrandForLegal() {
        XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders("© {legal}", PrivacyCenterPlaceholderContext(brand: "Acme")), "© Acme")
    }

    func testDefaultsTheYearToThisYear() {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders("{year}", PrivacyCenterPlaceholderContext(brand: "Acme")), String(year))
    }

    func testCollapsesAnUnknownName() {
        let cases = [
            ("Welcome back, {name}!", "Welcome back!"),
            ("Hi {name}, here is everything", "Hi, here is everything"),
            ("{name}, welcome", "welcome"),
            ("Welcome {name} to {brand}", "Welcome to Acme"),
        ]
        for (template, expected) in cases {
            XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders(template, PrivacyCenterPlaceholderContext(brand: "Acme")), expected, template)
        }
    }

    func testLeavesUnknownTokensAndPlainBracesAlone() {
        XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders("{phone} and {{brand}}", context), "{phone} and {Acme}")
    }

    func testReturnsAnEmptyStringForNothing() {
        XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders(nil, context), "")
        XCTAssertEqual(PrivacyCenterCopy.fillPlaceholders("", context), "")
    }

    func testShowsAnUnchangedDefaultThroughTheTranslatedStrings() {
        let rendered = PrivacyCenterCopy.render(defaults.portal.welcomeTitle, context) { key in
            key == "welcomeTitleDefault" ? "{brand} में आपका स्वागत है" : nil
        }
        XCTAssertEqual(rendered, "Acme में आपका स्वागत है")
        XCTAssertEqual(PrivacyCenterCopy.render("Custom {brand}", context) { _ in "never" }, "Custom Acme")
    }

    func testReadsTheUsualNameClaims() {
        XCTAssertEqual(PrivacyCenterCopy.principalFirstName(["user_data": ["first_name": "Jane Doe"]]), "Jane")
        XCTAssertEqual(PrivacyCenterCopy.principalFirstName(["name": " Ravi Kumar "]), "Ravi")
        XCTAssertNil(PrivacyCenterCopy.principalFirstName(["email": "jane@example.com"]))
    }

    // MARK: - Request types and grievances

    func testListsEveryTypeInTheBuiltInOrderUntilSettingsArePublished() {
        let options = PrivacyCenterRequestOptions.requestTypes(defaults.portal.requestTypes, serverEnabled: nil, keepLegacyOrder: true)
        XCTAssertEqual(options.map(\.type), RequestType.allCases)
    }

    func testFollowsThePublishedOrderLabelsAndSwitches() {
        let types = [
            PrivacyCenterRequestTypeSetting(key: .grievance, label: "Complaint"),
            PrivacyCenterRequestTypeSetting(key: .access),
            PrivacyCenterRequestTypeSetting(key: .correction, enabled: false),
            PrivacyCenterRequestTypeSetting(key: .erasure, label: "Delete my data"),
            PrivacyCenterRequestTypeSetting(key: .nomination, enabled: false),
        ]
        XCTAssertEqual(PrivacyCenterRequestOptions.requestTypes(types, serverEnabled: nil), [
            .init(type: .grievance, label: "Complaint"),
            .init(type: .access, label: nil),
            .init(type: .erasure, label: "Delete my data"),
        ])
    }

    func testNarrowsToTheServersOwnList() {
        let options = PrivacyCenterRequestOptions.requestTypes(defaults.portal.requestTypes, serverEnabled: ["access", "grievance"])
        XCTAssertEqual(options.map(\.type), [.access, .grievance])
    }

    func testKeepsOnlyTheAllowedGrievanceCategories() {
        let options = [
            GrievanceOption(value: .consentViolation, label: "Consent violation"),
            GrievanceOption(value: .dataBreach, label: "Data breach"),
        ]
        XCTAssertEqual(PrivacyCenterRequestOptions.grievanceOptions(options, allowed: [.dataBreach]), [options[1]])
    }

    func testMapsEveryRequestTypeToItsKeyAndBack() {
        for key in PrivacyCenterRequestTypeKey.allCases {
            XCTAssertEqual(PrivacyCenterRequestTypeKey(key.requestType), key)
        }
    }

    // MARK: - Sections

    func testTheMenuFollowsThePublishedSections() {
        let sections = [
            PrivacyCenterSection(key: .activity, label: "History"),
            PrivacyCenterSection(key: .consentManager),
            PrivacyCenterSection(key: .form, enabled: false),
            PrivacyCenterSection(key: .receipts),
            PrivacyCenterSection(key: .notifications, enabled: false),
        ]
        XCTAssertEqual(PrivacyCenterSections.tabs(sections).map(\.key), [.activity, .consentManager, .receipts])
        XCTAssertEqual(PrivacyCenterSections.label(.activity, in: sections) { $0 }, "History")
        XCTAssertEqual(PrivacyCenterSections.label(.receipts, in: sections) { $0 }, "myReceipt")
        XCTAssertFalse(PrivacyCenterSections.isEnabled(.notifications, in: sections))
        XCTAssertTrue(PrivacyCenterSections.isEnabled(.form, in: defaults.portal.sections))
    }

    // MARK: - Footer

    func testTheFooterShowsPoweredByAsBeforeWhenNothingIsPublished() {
        let content = footer(defaults.footer)
        XCTAssertTrue(content.showsPoweredBy)
        XCTAssertFalse(content.hasExtras)
        XCTAssertTrue(footer(defaults.footer, hidePlatformBranding: true).isEmpty)
    }

    func testTheFooterAddsLinksThePolicyContactLinesAndACopyright() {
        var settings = defaults.footer
        settings.links = [PrivacyCenterFooterLink(label: "Terms", url: "https://acme.test/terms")]
        settings.showPrivacyPolicy = true
        settings.showContact = true
        settings.copyright = "© {year} {legal}"
        let content = footer(settings, policy: "https://acme.test/privacy", dpoEmail: "dpo@acme.test")
        XCTAssertEqual(content.links.map(\.label), ["Terms", "Privacy Policy"])
        XCTAssertEqual(content.grievanceEmail, "dpo@acme.test")
        XCTAssertEqual(content.copyright, "© 2026 Acme Holdings Ltd")
    }

    func testTheFooterPrefersTheBrandIdentityDetailsAndSkipsAnInsecurePolicy() {
        var settings = defaults.footer
        settings.showPrivacyPolicy = true
        settings.showContact = true
        let contact = PrivacyCenterBrandContact(grievanceEmail: "grievance@acme.test", grievanceUrl: "https://acme.test/form", dpBoardUrl: "https://dpb.gov.in")
        let content = footer(settings, contact: contact, policy: "http://acme.test/privacy", dpoEmail: "dpo@acme.test")
        XCTAssertEqual(content.links, [])
        XCTAssertEqual(content.grievanceEmail, "grievance@acme.test")
        XCTAssertEqual(content.grievanceUrl, "https://acme.test/form")
        XCTAssertEqual(content.dpBoardUrl, "https://dpb.gov.in")
    }

    func testTheFooterCanDropPoweredBy() {
        var settings = defaults.footer
        settings.showPoweredBy = false
        XCTAssertTrue(footer(settings).isEmpty)
    }

    private func footer(
        _ settings: PrivacyCenterFooterSettings,
        contact: PrivacyCenterBrandContact = .empty,
        policy: String? = nil,
        dpoEmail: String? = nil,
        hidePlatformBranding: Bool = false
    ) -> PrivacyCenterFooterContent {
        PrivacyCenterFooterContent.make(
            footer: settings,
            brandContact: contact,
            brandingPrivacyPolicyUrl: policy,
            brandingDpoEmail: dpoEmail,
            hidePlatformBranding: hidePlatformBranding,
            privacyPolicyLabel: "Privacy Policy",
            copyright: { PrivacyCenterCopy.fillPlaceholders($0, self.context) }
        )
    }

    // MARK: - Brand colours

    func testPicksTheTextColourWithTheHigherContrast() {
        XCTAssertEqual(PrivacyCenterBrandColors.contrastText("#112233"), "#FFFFFF")
        XCTAssertEqual(PrivacyCenterBrandColors.contrastText("#FFEE99"), "#101828")
        XCTAssertEqual(PrivacyCenterBrandColors.contrastText("bad"), "#FFFFFF")
    }
}
