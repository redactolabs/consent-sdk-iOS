import Foundation

/// Sandbox-mode auth primitives for the consent PoC.
///
/// In sandbox mode the SDK talks to the consent-server with a pasted static
/// token and an explicit test identity, bypassing the JWT entirely. Org/workspace
/// UUIDs come from the host-supplied config (they still build the
/// `/public/organisations/{org}/workspaces/{ws}/...` URL paths) instead of being
/// decoded from a token.
///
/// Auth is the single `X-Consent-Token` header carrying the static token (raw,
/// no `Bearer` prefix); its presence alone marks the request as
/// `environment=test`. There is NO subject header. The acting identity carries
/// EVERY identifier the host supplied — UCIC (`org_user_id`), email
/// (`primary_email`), and/or mobile (`primary_mobile`) — mirroring a live JWT's
/// `user_data`. It rides the request's own payload: query items on GET/query
/// reads, and the JSON body on POSTs (form fields on multipart uploads). The
/// server picks the principal by precedence (UCIC > email > mobile) and preserves
/// the rest as the display-only sandbox contact, so the contact shows on the
/// dashboard/receipt just as it does for a live user. The server normalizes and
/// namespaces the identity `test::` server-side.
///
/// This type exists so every call site resolves its org/workspace UUIDs and
/// builds its auth header + identity payload through one place, keeping sandbox
/// vs. JWT branching from drifting across the consent + Privacy-Center fetch
/// sites. It is a direct port of the React SDK's `shared/sandbox.ts` +
/// `RedactoNoticeConsent/api/sandbox.ts` + `RedactoPrivacyCenter/lib/sandbox.ts`.
public struct SandboxConfig: Sendable, Equatable {
    /// HTTP header carrying the static sandbox token (the credential). Its
    /// presence marks a request as `environment=test`. Sent raw — no `Bearer`.
    public static let tokenHeader = "X-Consent-Token"

    /// The static sandbox token (the credential).
    public let token: String
    /// UCIC — the client's own user id (`org_user_id`). Takes precedence for the principal.
    public let ucic: String?
    /// Email — carried on every request like a live JWT's `user_data.primary_email`.
    public let email: String?
    /// Mobile — carried on every request like a live JWT's `user_data.primary_mobile`.
    public let mobile: String?
    public let organisationUuid: String
    public let workspaceUuid: String

    /// Legacy single "email-or-mobile" acting subject, kept for source
    /// compatibility. Derived from `email`/`mobile` (email wins). Prefer reading
    /// `email` and `mobile` directly — a single `subject` collapses the two into
    /// one identifier and drops the other from the request.
    @available(*, deprecated, message: "Use `email` and `mobile`; `subject` collapses them into one identifier.")
    public var subject: String { email ?? mobile ?? "" }

    /// Carry every supplied identifier (`ucic`/`email`/`mobile`), mirroring a live
    /// JWT's `user_data`. `nil`/empty identifiers are simply omitted downstream.
    public init(
        token: String,
        ucic: String?,
        email: String? = nil,
        mobile: String? = nil,
        organisationUuid: String,
        workspaceUuid: String
    ) {
        self.token = token
        self.ucic = ucic
        self.email = email
        self.mobile = mobile
        self.organisationUuid = organisationUuid
        self.workspaceUuid = workspaceUuid
    }

    /// Legacy initializer kept for source compatibility. A single `subject`
    /// collapses email and mobile into one field; it is classified here into
    /// `email` (contains "@") or `mobile` so the full identity still reaches the
    /// server. Prefer `init(token:ucic:email:mobile:organisationUuid:workspaceUuid:)`.
    @available(*, deprecated, message: "Use init(token:ucic:email:mobile:organisationUuid:workspaceUuid:); a single `subject` drops one of email/mobile.")
    public init(token: String, ucic: String?, subject: String, organisationUuid: String, workspaceUuid: String) {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let classifiedEmail: String? = (!trimmed.isEmpty && trimmed.contains("@")) ? trimmed : nil
        let classifiedMobile: String? = (!trimmed.isEmpty && !trimmed.contains("@")) ? trimmed : nil
        self.init(
            token: token,
            ucic: ucic,
            email: classifiedEmail,
            mobile: classifiedMobile,
            organisationUuid: organisationUuid,
            workspaceUuid: workspaceUuid
        )
    }

    /// Resolve a `SandboxConfig` from raw props, or return `nil` when sandbox
    /// mode is not active (no token). A non-empty token switches the SDK into
    /// sandbox mode.
    ///
    /// Throws when a token is provided but org/workspace or the acting identity
    /// are incomplete — sandbox mode cannot build URLs or identify the acting
    /// principal without them, so failing loudly beats a silent malformed request
    /// (mirrors the React SDK's `resolveSandboxAuth`). Every supplied identifier
    /// is carried through; the server picks the principal by precedence and keeps
    /// the rest as the display-only sandbox contact.
    public static func resolve(
        token: String?,
        email: String?,
        mobile: String?,
        ucic: String?,
        organisationUuid: String?,
        workspaceUuid: String?
    ) throws -> SandboxConfig? {
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedToken, !trimmedToken.isEmpty else {
            return nil
        }

        let org = organisationUuid?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ws = workspaceUuid?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUcic = normalized(ucic)
        let resolvedEmail = normalized(email)
        let resolvedMobile = normalized(mobile)

        guard let org, !org.isEmpty, let ws, !ws.isEmpty else {
            throw RedactoAPIError.invalidRequest(
                "Sandbox mode requires organisationUuid and workspaceUuid"
            )
        }
        guard resolvedUcic != nil || resolvedEmail != nil || resolvedMobile != nil else {
            throw RedactoAPIError.invalidRequest(
                "Sandbox mode requires a UCIC, email, or mobile"
            )
        }

        return SandboxConfig(
            token: trimmedToken,
            ucic: resolvedUcic,
            email: resolvedEmail,
            mobile: resolvedMobile,
            organisationUuid: org,
            workspaceUuid: ws
        )
    }

    /// Trim surrounding whitespace and collapse an empty result to `nil`.
    private static func normalized(_ value: String?) -> String? {
        guard
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    /// The single `X-Consent-Token` credential header. Its presence marks the
    /// request as `environment=test`. There is no subject header — the acting
    /// identity travels in the request's own payload.
    public var authHeaders: [String: String] {
        [Self.tokenHeader: token]
    }

    /// The single acting-identity field, by precedence: `org_user_id` when a UCIC
    /// is set, else `primary_email`, else `primary_mobile`.
    ///
    /// Deprecated: this collapses the identity to ONE field and drops any other
    /// identifier the host supplied, which is exactly the bug that left the ledger
    /// with no sandbox contact. Use `identityBodyFields` / `identityQueryItems`,
    /// which carry every identifier.
    @available(*, deprecated, message: "Use `identityBodyFields` / `identityQueryItems`, which carry every identifier instead of collapsing to one.")
    public var identityField: (name: String, value: String) {
        if let ucic, !ucic.isEmpty {
            return ("org_user_id", ucic)
        }
        if let email, !email.isEmpty {
            return ("primary_email", email)
        }
        return ("primary_mobile", mobile ?? "")
    }

    /// The single acting identity as one query item.
    ///
    /// Deprecated: collapses the identity to one field. Use `identityQueryItems`,
    /// which carries every identifier the host supplied.
    @available(*, deprecated, message: "Use `identityQueryItems`, which carries every identifier instead of collapsing to one.")
    public var identityQueryItem: URLQueryItem {
        if let ucic, !ucic.isEmpty {
            return URLQueryItem(name: "org_user_id", value: ucic)
        }
        if let email, !email.isEmpty {
            return URLQueryItem(name: "primary_email", value: email)
        }
        return URLQueryItem(name: "primary_mobile", value: mobile ?? "")
    }

    /// Every supplied identifier as query items for GET/query reads —
    /// `org_user_id` / `primary_email` / `primary_mobile`, in principal-precedence
    /// order. The server resolves the acting test principal from these query
    /// params on sandbox reads (there is no subject header) and preserves the
    /// non-keyed identifiers as the display-only sandbox contact.
    public var identityQueryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let ucic, !ucic.isEmpty {
            items.append(URLQueryItem(name: "org_user_id", value: ucic))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "primary_email", value: email))
        }
        if let mobile, !mobile.isEmpty {
            items.append(URLQueryItem(name: "primary_mobile", value: mobile))
        }
        return items
    }

    /// Every supplied identifier as flat body fields for POST/write paths —
    /// `org_user_id` / `primary_email` / `primary_mobile`, mirroring a live JWT's
    /// `user_data`. Merge into a JSON request body (or as multipart form fields).
    /// The server keys the principal by precedence (UCIC > email > mobile) and
    /// keeps the rest as the display-only sandbox contact.
    public var identityBodyFields: [String: String] {
        var fields: [String: String] = [:]
        if let ucic, !ucic.isEmpty {
            fields["org_user_id"] = ucic
        }
        if let email, !email.isEmpty {
            fields["primary_email"] = email
        }
        if let mobile, !mobile.isEmpty {
            fields["primary_mobile"] = mobile
        }
        return fields
    }

    /// The raw sandbox contact string, for endpoints whose server field is a
    /// single `contact` (the server classifies it as email/phone/UCIC) —
    /// create-case, manage-consent, form-data. Precedence UCIC > email > mobile
    /// (the same the server uses to pick the principal).
    public var contact: String {
        if let ucic, !ucic.isEmpty { return ucic }
        if let email, !email.isEmpty { return email }
        if let mobile, !mobile.isEmpty { return mobile }
        return ""
    }
}
