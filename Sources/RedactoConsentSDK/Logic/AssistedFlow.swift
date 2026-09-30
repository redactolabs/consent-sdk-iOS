import Foundation

enum AssistedFlow {
    static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isWholeNumber
    }

    static func sanitizeMobile(_ raw: String) -> String {
        String(raw.filter(isDigit).prefix(AssistedConfig.mobileLength))
    }

    static func sanitizeOtp(_ raw: String) -> String {
        String(raw.filter(isDigit).prefix(AssistedConfig.otpLength))
    }

    static func isValidMobile(_ value: String) -> Bool {
        value.count == AssistedConfig.mobileLength && value.allSatisfy(isDigit)
    }

    static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: AssistedConfig.emailPattern, options: .regularExpression) != nil
    }

    static func digits(of code: String) -> [String] {
        let characters = Array(code)
        return (0..<AssistedConfig.otpLength).map { $0 < characters.count ? String(characters[$0]) : "" }
    }

    static func otpRecipient(_ method: AssistedVerifyMethod, mobile: String, email: String) -> String {
        switch method {
        case .mobile: return "\(AssistedConfig.dialCode)\(mobile)"
        case .email: return email.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func otpChannel(_ method: AssistedVerifyMethod) -> String {
        switch method {
        case .mobile: return AssistedConfig.smsChannel
        case .email: return AssistedConfig.emailChannel
        }
    }

    /// The verify endpoint returns English copy with no error code, so the
    /// failure is localized from the HTTP status and `should_request_new`.
    static func verifyErrorMessage(_ error: Error, _ ts: AssistedI18n = AssistedI18n(language: "English")) -> String {
        guard let apiError = error as? AssistedAPIError else { return ts(.otpVerifyFailed) }
        switch apiError.status ?? 0 {
        case 404: return ts(.otpNotFound)
        case 400: return apiError.shouldRequestNew ? ts(.otpExpired) : ts(.otpIncorrect)
        default: return ts(.otpVerifyFailed)
        }
    }

    static func isConsentAlreadyProvided(_ error: Error) -> Bool {
        guard let apiError = error as? RedactoAPIError else { return false }
        return apiError.statusCode == 409 || apiError.errorCode == AssistedConfig.alreadyProvidedCode
    }

    /// One entry per purpose in the config's order, never per product: React's
    /// assisted submit is flat (tsx ~1419-1438). Required elements go selected.
    static func submitPurposes(_ purposes: [ActiveConfigPurpose], mode: AcceptMode, current: SelectionState) -> [Purpose] {
        let rows = purposes.map { NoticePurposeRow(purpose: $0, productUuid: nil) }
        let selection = ProductConsent.selectionForMode(rows: rows, mode: mode, current: current)
        return purposes.map { purpose in
            Purpose(
                uuid: purpose.uuid,
                name: purpose.name,
                description: purpose.description,
                industries: purpose.industries,
                selected: selection.selectedPurposes[purpose.uuid] ?? false,
                dataElements: purpose.dataElements.map { element in
                    DataElement(
                        uuid: element.uuid,
                        name: element.name,
                        description: element.description,
                        industries: element.industries,
                        enabled: element.enabled,
                        required: element.required,
                        selected: element.required
                            || (selection.selectedDataElements[dataElementKey(purposeUuid: purpose.uuid, elementUuid: element.uuid)] ?? false)
                    )
                }
            )
        }
    }
}
