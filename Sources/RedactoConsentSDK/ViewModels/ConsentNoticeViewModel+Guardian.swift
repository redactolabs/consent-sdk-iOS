import Foundation
import UIKit

private struct GuardianResponseError: LocalizedError {
    var errorDescription: String? { GuardianCopy.invalidResponse }
}

/// The pause flag the polling loop reads, flipped by app lifecycle observers.
private final class PollPause: @unchecked Sendable {
    var paused = false
}

extension ConsentNoticeViewModel {
    // MARK: - Guardian Form

    func handleGuardianFormChange(_ field: String, _ value: String) {
        switch field {
        case "guardianName":
            guardianFormData.guardianName = value
        case "guardianContact":
            guardianFormData.guardianContact = value
        case "guardianRelationship":
            guardianFormData.guardianRelationship = value
        default:
            break
        }
        guardianFormErrors[field] = nil
    }

    /// Every missing field at once, keyed as the form reads them.
    static func guardianFormErrors(for data: GuardianFormData) -> [String: String] {
        var errors: [String: String] = [:]
        if data.guardianName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianName"] = GuardianCopy.nameRequired
        }
        if data.guardianContact.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianContact"] = GuardianCopy.contactRequired
        }
        if data.guardianRelationship.trimmingCharacters(in: .whitespaces).isEmpty {
            errors["guardianRelationship"] = GuardianCopy.relationshipRequired
        }
        return errors
    }

    @discardableResult
    func handleGuardianFormNext() -> Task<Void, Never>? {
        let errors = Self.guardianFormErrors(for: guardianFormData)
        guardianFormErrors = errors
        guard errors.isEmpty else { return nil }

        guardianTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            // A new principal (token swap) cancels this; its response must not
            // hand the old principal's verification to the new one.
            let startedWith = self.accessToken
            self.isSubmittingGuardian = true
            self.guardianFormErrors = [:]
            self.verificationError = nil

            do {
                let response = try await ConsentAPI.initiateGuardianVerification(.init(
                    accessToken: self.accessToken,
                    baseUrl: self.baseUrl,
                    guardianName: self.guardianFormData.guardianName,
                    guardianContact: self.guardianFormData.guardianContact,
                    guardianRelationship: self.guardianFormData.guardianRelationship
                ))
                guard !Task.isCancelled, self.accessToken == startedWith else { return }
                self.isSubmittingGuardian = false

                if response.alreadyVerified == true, let reference = response.verificationReference {
                    // Already verified: a brief success flash, then the notice.
                    self.verificationReference = reference
                    self.showGuardianForm = false
                    self.showVerificationScreen = true
                    self.isInitiatingVerification = false
                    self.isVerificationComplete = true
                    self.isAutoTransitioning = true
                    self.autoTransitionTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        guard let self, !Task.isCancelled else { return }
                        self.showVerificationScreen = false
                        self.isVerificationComplete = false
                        self.isAutoTransitioning = false
                        self.autoTransitionTask = nil
                    }
                    return
                }

                guard let sessionToken = response.sessionToken,
                      let redirect = response.digilockerRedirectUrl else {
                    throw GuardianResponseError()
                }

                self.showGuardianForm = false
                self.showVerificationScreen = true
                self.isInitiatingVerification = true

                let opened: Bool
                if let url = URL(string: redirect) {
                    opened = await self.openURL(url)
                } else {
                    opened = false
                }
                guard opened else {
                    self.isInitiatingVerification = false
                    self.verificationError = GuardianCopy.openFailed
                    return
                }

                self.isInitiatingVerification = false
                self.startStatusPolling(sessionToken: sessionToken)
            } catch {
                guard !Task.isCancelled, self.accessToken == startedWith else { return }
                self.isInitiatingVerification = false
                let message = error.localizedDescription
                if (error as? RedactoAPIError)?.statusCode == 422 {
                    if message.contains("guardian_contact") {
                        self.guardianFormErrors = ["guardianContact": message]
                    } else if message.contains("guardian_name") {
                        self.guardianFormErrors = ["guardianName": message]
                    } else if message.contains("guardian_relationship") {
                        self.guardianFormErrors = ["guardianRelationship": message]
                    } else {
                        self.guardianFormErrors = ["general": message]
                    }
                    self.showVerificationScreen = false
                    self.showGuardianForm = true
                } else {
                    self.guardianFormErrors = ["general": message.isEmpty ? GuardianCopy.initiateFailed : message]
                    self.showVerificationScreen = false
                    self.showGuardianForm = true
                    self.onError?(error)
                }
            }
            self.isSubmittingGuardian = false
        }
        guardianTask = task
        return task
    }

    // MARK: - Age Verification

    func handleAgeVerificationYes() {
        showAgeVerification = false
        isMinorFlow = false
        selfDeclaredAdult = true
    }

    func handleAgeVerificationNo() {
        showAgeVerification = false
        showGuardianForm = true
    }

    // MARK: - Verification Polling

    /// Polls every interval, stopping after 40 attempts; paused while the app
    /// is in the background and polled at once on return.
    func startStatusPolling(sessionToken: String) {
        pollingTask?.cancel()
        verificationSessionToken = sessionToken
        isPollingStatus = true
        verificationError = nil
        verificationErrorCode = nil
        canRetryVerification = false

        let interval = pollIntervalNanos
        pollingTask = Task { [weak self] in
            let maxAttempts = 40
            let maxConsecutiveErrors = 3
            var attempts = 0
            var consecutiveErrors = 0
            let pause = PollPause()

            let willResign = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in pause.paused = true }
            let didBecomeActive = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in pause.paused = false }
            defer {
                NotificationCenter.default.removeObserver(willResign)
                NotificationCenter.default.removeObserver(didBecomeActive)
            }

            try? await Task.sleep(nanoseconds: interval)

            // Each attempt holds the view model only for its own request, so a
            // view torn down mid-poll is freed and its deinit ends the loop.
            while !Task.isCancelled {
                if pause.paused {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                attempts += 1
                guard let step = await self?.pollGuardianStatus(
                    sessionToken: sessionToken,
                    attempt: attempts,
                    maxAttempts: maxAttempts,
                    consecutiveErrors: consecutiveErrors,
                    maxConsecutiveErrors: maxConsecutiveErrors
                ) else { return }
                guard case .again(let errors) = step else { return }
                consecutiveErrors = errors
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    enum GuardianPollStep {
        case again(consecutiveErrors: Int)
        case done
    }

    func pollGuardianStatus(
        sessionToken: String,
        attempt: Int,
        maxAttempts: Int,
        consecutiveErrors: Int,
        maxConsecutiveErrors: Int
    ) async -> GuardianPollStep {
        if attempt > maxAttempts {
            failVerification(GuardianCopy.takingLonger, code: "SESSION_EXPIRED", canRetry: true)
            return .done
        }
        do {
            let response = try await ConsentAPI.verifyGuardianStatus(.init(
                accessToken: accessToken,
                baseUrl: baseUrl,
                sessionToken: sessionToken
            ))
            if Task.isCancelled { return .done }

            if response.status == "verified" {
                stopPolling()
                guard let reference = response.verificationReference
                    ?? response.guardianDetails?.verificationReference else {
                    failVerification(GuardianCopy.noReference, code: nil, canRetry: true)
                    return .done
                }
                verificationReference = reference
                isVerificationComplete = true
                return .done
            }

            if response.status == "failed" || response.status == "expired" {
                failVerification(
                    GuardianCopy.message(errorCode: response.errorCode, fallback: response.error),
                    code: response.errorCode,
                    canRetry: response.canRetry ?? false
                )
                return .done
            }
            return .again(consecutiveErrors: 0)
        } catch {
            if Task.isCancelled { return .done }
            let status = (error as? RedactoAPIError)?.statusCode
            if status == 404 || status == 410 {
                failVerification(GuardianCopy.sessionGone, code: "SESSION_EXPIRED", canRetry: true)
                return .done
            }
            let errors = consecutiveErrors + 1
            if errors >= maxConsecutiveErrors {
                let message = error.localizedDescription
                failVerification(message.isEmpty ? GuardianCopy.statusUnavailable : message, code: nil, canRetry: true)
                return .done
            }
            return .again(consecutiveErrors: errors)
        }
    }

    private func failVerification(_ message: String, code: String?, canRetry: Bool) {
        stopPolling()
        verificationError = message
        verificationErrorCode = code
        canRetryVerification = canRetry
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPollingStatus = false
        isInitiatingVerification = false
    }

    func handleBackToGuardianForm(clearName: Bool = false) {
        stopPolling()
        autoTransitionTask?.cancel()
        autoTransitionTask = nil
        showVerificationScreen = false
        showGuardianForm = true
        verificationError = nil
        verificationErrorCode = nil
        canRetryVerification = false
        isVerificationComplete = false
        isAutoTransitioning = false
        if clearName {
            guardianFormData.guardianName = ""
        }
    }

    func handleVerificationContinue() {
        showVerificationScreen = false
        isVerificationComplete = false
    }
}
