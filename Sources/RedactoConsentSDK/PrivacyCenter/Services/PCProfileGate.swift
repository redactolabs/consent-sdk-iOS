import Foundation

enum PCProfileGate {
    static func resolve(
        candidates: [IdentityCandidate],
        pickedOrgUserId: String?,
        tokenOrgUserId: String?,
        isSandbox: Bool
    ) -> ProfileGatePhase {
        if isSandbox { return .resolved }
        let picked = pickedOrgUserId.pcNonEmpty
        let token = tokenOrgUserId.pcNonEmpty
        let isPinned = picked != nil && picked == token
        return candidates.count > 1 && !isPinned ? .picking : .resolved
    }

    static func isPinned(pickedOrgUserId: String?, tokenOrgUserId: String?) -> Bool {
        guard let picked = pickedOrgUserId.pcNonEmpty else { return false }
        return picked == tokenOrgUserId.pcNonEmpty
    }

    static func selectable(_ candidates: [IdentityCandidate]) -> [IdentityCandidate] {
        candidates.filter { !$0.uuid.isEmpty }
    }

    static func labels(for candidate: IdentityCandidate) -> ProfileRowLabels {
        let email = candidate.primaryEmail ?? ""
        let mobile = candidate.primaryMobile ?? ""
        let orgUserId = candidate.orgUserId ?? ""
        let primary: String
        if !orgUserId.isEmpty {
            primary = PCStrings.userIdLabel(orgUserId)
        } else if !email.isEmpty {
            primary = email
        } else if !mobile.isEmpty {
            primary = mobile
        } else {
            primary = candidate.uuid
        }
        var secondary: [String] = []
        for value in [email, mobile] where !value.isEmpty && value != primary && !secondary.contains(value) {
            secondary.append(value)
        }
        return ProfileRowLabels(primary: primary, secondary: secondary)
    }

    static func contact(for candidate: IdentityCandidate, tokenContact: String?, orgUserId: String) -> String {
        tokenContact.pcNonEmpty
            ?? candidate.primaryEmail.pcNonEmpty
            ?? candidate.primaryMobile.pcNonEmpty
            ?? orgUserId
    }

    static func orgUserId(fromToken token: String) -> String? {
        let segments = token.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard
            let data = Data(base64Encoded: base64),
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let userData = payload["user_data"] as? [String: Any],
            let orgUserId = userData["org_user_id"] as? String,
            !orgUserId.isEmpty
        else {
            return nil
        }
        return orgUserId
    }
}
