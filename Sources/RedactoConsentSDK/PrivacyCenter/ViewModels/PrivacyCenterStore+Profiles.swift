import Foundation

extension PrivacyCenterStore {
    public var canSwitchProfile: Bool {
        profileCandidates.count > 1
    }

    public func start() async {
        if showsSignIn {
            // The built-in sign-in is the first screen; the centre loads once
            // it issues tokens.
            events.ready(signedIn: false)
            loadSettings()
            await loadBranding()
            await awaitSettings()
            return
        }
        await resolveProfiles()
        // With no token yet the host is still fetching one: the centre reports
        // ready once `syncHostTokens` hands it over.
        if hasSession {
            events.ready(signedIn: true)
        }
        restartInactivityTimerIfNeeded()
        // The published settings never hold the centre up: they arrive
        // alongside its data and swap in when they land. They go through the
        // one settings task, so a later fetch always replaces this one.
        loadSettings()
        if profilePhase == .resolved {
            await checkDataAvailability()
        }
        await loadBranding()
        await awaitSettings()
    }

    public func resolveProfiles() async {
        let token = await tokenStore.currentRawToken()
        if isSandboxSession || token.isEmpty {
            profilePhase = .resolved
            return
        }
        let tokenOrgUserId = PCProfileGate.orgUserId(fromToken: token)
        currentOrgUserId = tokenOrgUserId
        let pinned = PCProfileGate.isPinned(pickedOrgUserId: pickedOrgUserId, tokenOrgUserId: tokenOrgUserId)
        profilePhase = pinned ? .resolved : .checking
        do {
            let list = try await api.listIdentities().identities
            profileCandidates = list
            profilePhase = PCProfileGate.resolve(
                candidates: list,
                pickedOrgUserId: pickedOrgUserId,
                tokenOrgUserId: tokenOrgUserId,
                isSandbox: false
            )
        } catch {
            profileCandidates = []
            profilePhase = .resolved
            reportError(error)
        }
    }

    public func selectProfile(_ candidate: IdentityCandidate) async {
        guard !candidate.uuid.isEmpty, profileBusyUuid == nil else { return }
        profileBusyUuid = candidate.uuid
        profileSelectError = nil
        defer { profileBusyUuid = nil }
        do {
            let tokens = try await api.selectPrincipal(uuid: candidate.uuid)
            guard
                !tokens.token.isEmpty,
                !tokens.refreshToken.isEmpty,
                let picked = PCProfileGate.orgUserId(fromToken: tokens.token)
            else {
                throw PrivacyCenterAPIError.invalidToken("select-principal")
            }
            let payload = JWTDecoder.decode(tokens.token)
            let scopedContact = PCProfileGate.contact(for: candidate, tokenContact: payload?.resolvedContact, orgUserId: picked)
            await tokenStore.adopt(accessToken: tokens.token, refreshToken: tokens.refreshToken, contact: scopedContact)
            pickedOrgUserId = picked
            currentOrgUserId = picked
            if let payload {
                organisationUuid = payload.organisationUuid
                workspaceUuid = payload.workspaceUuid
            }
            contact = scopedContact
            profilePhase = .resolved
            dataStatus = .checking
            await checkDataAvailability()
        } catch {
            if !isCancellationError(error) {
                profileSelectError = PCStrings.couldNotSwitchProfile
            }
        }
    }

    public func switchProfile() {
        pickedOrgUserId = nil
        profileSelectError = nil
        profileBusyUuid = nil
        profilePhase = .picking
    }
}
