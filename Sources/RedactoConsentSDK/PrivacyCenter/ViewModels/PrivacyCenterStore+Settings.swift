import Foundation

/// The published Privacy Center settings (React `PrivacyCenterSettingsContext`,
/// `NavigationContext`, `useInactivityTimeout` and the built-in sign-in).
extension PrivacyCenterStore {
    // MARK: - Sections

    func isSectionEnabled(_ key: PrivacyCenterSectionKey) -> Bool {
        PrivacyCenterSections.isEnabled(key, in: settings.portal.sections)
    }

    /// Case details is a drill-down reached from several sections, so it stays.
    func isPageAllowed(_ page: InternalPage) -> Bool {
        page == .caseDetails || enabledPages.contains(page)
    }

    var enabledPages: [InternalPage] {
        PrivacyCenterSections.tabs(settings.portal.sections).compactMap { InternalPage(rawValue: $0.key.rawValue) }
    }

    /// The page on show: a switched-off initial or current page lands on the
    /// first section left.
    public var visiblePage: InternalPage {
        isPageAllowed(currentPage) ? currentPage : (enabledPages.first ?? .consentManager)
    }

    /// The tabs, in the published order with their labels.
    var tabSections: [PrivacyCenterSection] {
        PrivacyCenterSections.tabs(settings.portal.sections)
    }

    func sectionLabel(_ key: PrivacyCenterSectionKey) -> String {
        PrivacyCenterSections.label(key, in: settings.portal.sections) { PCStrings.t($0) }
    }

    /// The home the brand mark leads to: the first section.
    var homePage: InternalPage {
        enabledPages.first ?? .consentManager
    }

    // MARK: - Languages

    /// The languages the switcher offers.
    var languageOptions: [PrivacyCenterLanguage] {
        PrivacyCenterLanguages.all.filter { settings.languages.enabled.contains($0.code) }
    }

    /// Hidden when the settings turn it off or fewer than two are enabled.
    var showsLanguageSwitcher: Bool {
        settings.languages.showSwitcher && languageOptions.count >= 2
    }

    /// Urdu, Sindhi and Kashmiri read right to left once settings are
    /// customised; with nothing published the direction is inherited.
    public var isRightToLeft: Bool {
        isSettingsCustomised && PrivacyCenterLanguagePolicy.isRightToLeft(language)
    }

    /// Moves the visitor onto an enabled language once settings that restrict
    /// languages arrive. Runs when the language policy changes, not on every
    /// fetch, so a later switch is never undone.
    func applyLanguagePolicy() {
        let policy: PrivacyCenterLanguageSettings? = isSettingsCustomised ? settings.languages : nil
        guard policy != appliedLanguagePolicy else { return }
        appliedLanguagePolicy = policy
        guard let policy else { return }
        let target = PrivacyCenterLanguagePolicy.pick(current: language, languages: policy, userChoice: languageChoice)
        if target != language {
            setLanguage(target)
        }
    }

    // MARK: - Copy

    /// What `{brand}` and `{legal}` resolve to here.
    var placeholderContext: PrivacyCenterPlaceholderContext {
        PrivacyCenterPlaceholderContext(
            brand: displayOrgName,
            legal: brandContact.legalEntityName ?? branding?.legalName.pcTrimmedNonEmpty
        )
    }

    /// A piece of settings copy as shown: an unchanged default in the
    /// visitor's language, then its placeholders filled.
    func copy(_ value: String?, contact: String? = nil, name: String? = nil) -> String {
        var context = placeholderContext
        context.contact = contact
        context.name = name
        return PrivacyCenterCopy.render(value, context)
    }

    /// The organisation's withdraw warning, nil to use the built-in one.
    var organisationWithdrawWarning: String? {
        copy(settings.portal.withdrawWarning).pcNonEmptyValue
    }

    // MARK: - Fetching

    /// Fetches the published settings in the current language once the
    /// organisation is known. Never waits and never fails: the centre renders
    /// with the defaults until they arrive, and keeps them if the fetch fails.
    func loadSettings() {
        settingsTask?.cancel()
        settingsTask = Task { [weak self] in
            await self?.refreshSettings()
        }
    }

    /// Waits for the fetch in flight, and for one it led to (a language the
    /// published settings moved the visitor onto).
    func awaitSettings() async {
        while let task = settingsTask {
            await task.value
            if task == settingsTask { return }
        }
    }

    /// The fetch itself, for a caller that waits on it.
    func refreshSettings() async {
        // With no token and no built-in sign-in the host is still fetching its
        // token: add no request it never made.
        guard hasSession || builtInSignIn else { return }
        checkSignInOrganisation()
        guard let organisation = organisationUuid, !Task.isCancelled else { return }
        let requestLanguage = PrivacyCenterLanguagePolicy.requestLanguage(language)
        let response = await PrivacyCenterPublicAPI.fetchSettings(
            baseUrl: baseUrl,
            organisationUuid: organisation,
            language: requestLanguage,
            urlSession: urlSession
        )
        // A response for an organisation or language since left behind would
        // overwrite a newer one: it is dropped.
        guard !Task.isCancelled,
              organisation == organisationUuid,
              requestLanguage == PrivacyCenterLanguagePolicy.requestLanguage(language),
              let response else { return }
        applyPublished(response, organisation: organisation)
    }

    func applyPublished(_ response: PublicPrivacyCenterSettings?, organisation: String?) {
        publishedSettings = response
        publishedSettingsOrganisation = organisation
        let resolved = PrivacyCenterSettingsResolver.resolve(published: response?.settings, overrides: hostSettings)
        let customised = (response?.isPublished ?? false) || (hostSettings?.overridesPublishedSettings ?? false)
        brandContact = PrivacyCenterSettingsResolver.brandContact(response?.brandContact)
        isSettingsCustomised = customised
        if resolved != settings {
            settings = resolved
            applyTheme()
        }
        applyLanguagePolicy()
        if !isPageAllowed(currentPage) {
            currentPage = visiblePage
        }
        if !isSectionEnabled(.notifications) {
            isNotificationsOpen = false
        }
        restartInactivityTimerIfNeeded()
    }

    /// The built-in sign-in sends codes for the organisation and workspace the
    /// props or the token name; without both it says so and sends nothing.
    func checkSignInOrganisation() {
        guard builtInSignIn, !hasSession else { return }
        organisationLookupFailed = organisationUuid == nil || workspaceUuid == nil
    }

    // MARK: - Built-in sign-in

    /// No token, and the host asked for the built-in sign-in.
    public var showsSignIn: Bool {
        builtInSignIn && !hasSession
    }

    /// The tokens a verified code issued go through the same token store the
    /// host's do, and the Privacy Center opens.
    func completeSignIn(_ tokens: PrivacyCenterSignInTokens, contact: String?) async {
        await tokenStore.adopt(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken ?? "", contact: contact)
        if let payload = JWTDecoder.decode(tokens.accessToken) {
            organisationUuid = payload.organisationUuid ?? organisationUuid
            workspaceUuid = payload.workspaceUuid ?? workspaceUuid
            rememberOrganisationName(fromToken: tokens.accessToken)
        }
        self.contact = await tokenStore.currentEmail() ?? contact
        currentOrgUserId = PCProfileGate.orgUserId(fromToken: tokens.accessToken)
        pickedOrgUserId = nil
        isSessionExpired = false
        events.sessionStarted()
        dataStatus = .checking
        profilePhase = .checking
        // The centre replaces the sign-in and starts loading as it appears.
        hasSession = true
    }

    /// Back to a signed-out state, so the built-in sign-in shows again.
    public func restartSignIn() {
        signOut()
        hasSession = false
        isSessionExpired = false
        events.sessionStarted()
        dataStatus = .checking
        profilePhase = .checking
        loadSettings()
    }

    /// The session-expired screen offers signing in again when the host gave
    /// no way out.
    var canSignInAgain: Bool {
        builtInSignIn && onBack == nil
    }

    // MARK: - Inactivity

    /// Signs out after `portal.sessionTimeoutMinutes` without a touch, only
    /// while the Privacy Center itself is on show. No timeout, or one that
    /// rounded to 0 minutes, leaves it off.
    func restartInactivityTimerIfNeeded() {
        guard let minutes = settings.portal.sessionTimeoutMinutes, minutes > 0,
              hasSession, !isSessionExpired, !isSandboxSession else {
            stopInactivityTimer()
            return
        }
        let timeout = TimeInterval(minutes * 60)
        if inactivityClock?.timeout == timeout, inactivityTask != nil { return }
        inactivityClock = PrivacyCenterInactivityClock(timeout: timeout, now: now())
        scheduleInactivityCheck(after: timeout)
    }

    func recordActivity() {
        inactivityClock?.activity(at: now())
    }

    /// Back in the foreground: a suspended app's timers did not run, so the
    /// deadline is checked first.
    func resumeFromBackground() {
        guard var clock = inactivityClock else { return }
        let result = clock.resume(at: now())
        inactivityClock = clock
        handle(result)
    }

    func stopInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = nil
        inactivityClock = nil
    }

    func checkInactivity() {
        guard var clock = inactivityClock else { return }
        let result = clock.check(at: now())
        inactivityClock = clock
        handle(result)
    }

    private func handle(_ result: PrivacyCenterInactivityClock.Check) {
        switch result {
        case .fire:
            expireForInactivity()
        case let .wait(delay):
            scheduleInactivityCheck(after: delay)
        case .done:
            break
        }
    }

    private func scheduleInactivityCheck(after delay: TimeInterval) {
        inactivityTask?.cancel()
        inactivityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(delay, 0.5) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.checkInactivity()
        }
    }

    /// Drops the session and shows the same expired screen a dead refresh
    /// token leads to.
    func expireForInactivity() {
        signOut()
        isSessionExpired = true
        events.sessionEnded(.timeout)
    }
}

private extension String {
    var pcNonEmptyValue: String? {
        isEmpty ? nil : self
    }
}
