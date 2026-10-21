# Redacto Consent SDK for iOS

Native Swift SDK for rendering and submitting user consent with Redacto CMP.

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## Installation

### Swift Package Manager

In Xcode:

1. Open **File > Add Package Dependencies...**
2. Enter the repository URL:
   - `https://github.com/redactolabs/consent-sdk-ios.git`
3. Select a release version (for example `2.1.0`).
4. Add the `RedactoConsentSDK` product to your app target.

Or via `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/redactolabs/consent-sdk-ios.git", from: "2.1.0")
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
platform :ios, '16.0'

target 'YourApp' do
  use_frameworks!
  pod 'RedactoConsentSDK', '~> 2.1'
end
```

Then run:

```bash
pod install
```

## Migrating from 1.x

- **Errors.** A failed HTTP response from the notice and inline APIs now reaches `onError` as `RedactoAPIError.api(status:code:message:)`. The old cases (`.alreadyConsented`, `.unauthorized`, `.notFound`, …) are still in the enum but are no longer thrown for an HTTP status, so a `catch` or `case` on them stops matching. Match on the status instead:

  ```swift
  onError: { error in
      if let apiError = error as? RedactoAPIError, apiError.statusCode == 409 {
          // already consented
      }
  }
  ```

  `statusCode` returns the same value for the old cases, so this check works on 1.x as well.
- **`ConsentStatus`** has a new `unknown` case. An exhaustive `switch` over it needs a branch for it, or a `default`.
- **Review mode.** With `includeFullyConsentedData`, the button shown to a fully consented user now calls `onAccept` (default label "Continue") instead of reopening the form.
- **`baseUrl` is required.** `RedactoNoticeConsent`, `RedactoNoticeConsentInline` and `RedactoNoticeAssisted` no longer fall back to a built-in host: pass the consent API host your app uses. A blank value fails through `onError` ("baseUrl is required") without making a request. `RedactoConstants.defaultConsentAPIBaseURL` is removed.
- **The modal draws its own backdrop.** `RedactoNoticeConsent` now fills the space it is given, dims it (when `blockUI` is on) and places its card where the console's appearance says, as the React SDK does. Present it over your content in a `ZStack` or a `.fullScreenCover`; inside a `.sheet` the card floats inside the sheet.
- **Console appearance applies.** Colours, style, radius, layout, text scale, selection control and the confirm step set in the Redacto console now reach iOS. Anything you pass in `settings` still wins.
- **Inline notice.** It has no language selector (React's inline has none), and it reports `onValidationChange` and auto-submits as soon as it loads.
- **Privacy Center.** New optional `settings: PrivacyCenterSettings` and `onTokensRefreshed`; `onBack` is now honoured, and a dead refresh token shows a session-expired screen instead of retrying.

## Quick Start

```swift
import RedactoConsentSDK
import SwiftUI

struct ContentView: View {
    var body: some View {
        RedactoNoticeConsent(
            noticeId: "your-notice-id",
            accessToken: "your-access-token",
            refreshToken: "your-refresh-token",
            baseUrl: "https://api.redacto.io",
            onAccept: { /* consent recorded */ },
            onDecline: { }
        )
    }
}
```

## `baseUrl`

Pass the Redacto API host for your environment, such as `https://api.redacto.io`, as `baseUrl` on every view (`RedactoNoticeConsent`, `RedactoNoticeConsentInline`, `RedactoNoticeAssisted`, `RedactoPrivacyCenter`). The SDK reaches each service under that host:

| Service | URL | Used for |
| --- | --- | --- |
| Consent server | `{baseUrl}/consent` | Magic-link and sandbox notice reads, the tokenless inline read, the assisted notice, OTP and audio, guardian verification, OTP refresh, and the Privacy Center's published settings, built-in sign-in codes, and DSR, case, activity and notification routes |
| Consent ledger | `{baseUrl}/consent-ledger` | JWT notice reads (modal and inline), notice audio (sandbox included), consent writes, the prior-consent check, user consents, receipts and Privacy Center consent changes |
| User service | `{baseUrl}/user/api/0` | Privacy Center workspace branding |

A `baseUrl` ending in `/consent-ledger` is read as its host. There is no built-in host: a blank `baseUrl` fails through `onError` ("baseUrl is required") before any request.

**The consent server URL still works, but is deprecated.** A `baseUrl` ending in `/consent` (`https://api.redacto.io/consent`, which 2.0.0 documented) keeps working exactly as before: the same requests, with `ledgerBaseUrl` naming the ledger and the consent-server fallbacks when it is not set. So does a value that is not an absolute `http(s)` URL. Move to the host when convenient; the SDK logs one warning per process (`os.Logger`, subsystem `io.redacto.RedactoConsentSDK`, category `baseUrl`).

**`ledgerBaseUrl` is deprecated.** It is read only when `baseUrl` is the consent server URL (`…/consent`) or omitted, as in earlier releases. It is ignored when `baseUrl` is the API host, and passing it then logs a one-time warning.

**If your backend reuses this value**, for example to mint tokens, note that it still needs the consent server URL, `{host}/consent`, for its own calls. Keep that URL in the backend's configuration, or append `/consent` to the host before sending it.

### Local development

Put the services behind one local gateway, the way production does, and pass its address as `baseUrl`. For example, with [Caddy](https://caddyserver.com), the consent server on port 8000 and the ledger on port 8090:

```caddyfile
:8080 {
	handle /consent-ledger/* {
		reverse_proxy localhost:8090
	}
	handle /consent/* {
		reverse_proxy localhost:8000
	}
}
```

Then pass `baseUrl: "http://localhost:8080"`. Both services serve their own path prefix (`/consent/…`, `/consent-ledger/…`), so the gateway forwards paths unchanged. Any reverse proxy works the same way (nginx, Traefik, your docker-compose gateway).

The iOS Simulator reaches the Mac at `http://localhost:8080`. A physical device needs the Mac's LAN IP, and plain `http` may need an App Transport Security exception in your debug build.

## Notice behaviour set in the console

- **Selection control.** The checkbox, radio or Yes/No dropdown chosen in the console (or `settings.selectionControl`) answers the purposes, the product headings and every data element row. With switches, a partly ticked product shows off, and the next tap asks for all of it.
- **Ticks.** Ticking a purpose, or a product heading, grants the purpose's mandatory data elements, or every live one when it has none; optional elements stay the visitor's choice.
- **Confirm before submitting.** The modal asks before Accept All, Accept Selected or Decline submits. `RedactoNoticeConsentInline` asks before its automatic submission; answering no holds that selection back until it changes.
- **Translated chrome.** The yes/no controls, the confirm dialog, the verification panel, the privacy policy label and the confirm hints follow the notice's language: English plus the 22 languages of the 8th Schedule.

## Privacy Center

```swift
RedactoPrivacyCenter(
    baseUrl: "https://api.redacto.io",
    accessToken: accessToken,
    refreshToken: refreshToken,
    onError: { _ in false },
    settings: PrivacyCenterSettings(portal: .init(welcomeEnabled: true)),
    builtInSignIn: true,
    onConsentChange: { change in print(change.action, change.purposeUuid) },
    onSignOut: { event in print(event.reason) }
)
```

- **Published settings.** The Privacy Center fetches the settings published in the Redacto console (Rights Management › Privacy Center › Settings) for the organisation and the visitor's language, and fetches them again when the language changes. It never waits for them: with nothing published, or if the request fails, it looks and behaves as before. They cover branding (style, colours, font, name, logo, logo height, corner radius), the menu's order, labels and sections (a section switched off leaves the menu and can't be opened; notifications off removes the bell), a welcome message, the request types and grievance categories the form offers, the revoke-on-erasure choice, the default withdraw warning, enabled languages and the default one, an inactivity sign-out, the footer and the sign-in screen. Once settings are published, Urdu, Sindhi and Kashmiri read right to left.
- **`settings` overrides.** `PrivacyCenterSettings` takes `branding`, `signIn`, `portal`, `languages` and `footer` groups, each merged field by field over what was published. A nil field keeps the published value; an empty string asks for the built-in one; `.some(nil)` clears a nullable number or choice (for example `portal: .init(sessionTimeoutMinutes: .some(nil))`). `theme` still works as an alias for `branding.style`.
- **Organisation font.** The workspace's font, or the settings' when they stop inheriting it, applies across the Privacy Center through the same catalogue the notice uses, when the family is installed on the device.
- **No slug needed.** The branding is read for the organisation in the access token, or for `organisationUuid` in sandbox mode or without a token; with no organisation known, none is requested. `slug` is optional, deprecated and ignored: passing it logs a one-time warning and changes nothing. Remove it.
- **Built-in sign-in.** With `builtInSignIn: true` and no access token, the Privacy Center shows its own sign-in: a mobile number or email, a one-time code (resend after 50 seconds), and then the issued tokens go through the same token store as yours (`onTokensRefreshed` hears of them). Layout, background, copy, channels, default country code, notice line and support link come from the `sign_in` settings. The organisation and workspace come from `organisationUuid` and `workspaceUuid`, which it needs without a token: without both, it says the organisation is unavailable and sends nothing. Off by default, so a host that passes its token a moment late never sees a sign-in screen.
- **Lifecycle callbacks.** `onReady` (once, when the first screen is on show, with whether the visitor is signed in; a centre opened before the host has a token reports it once the token arrives), `onConsentChange` (a withdraw, regrant or renew, with the purpose, product, data elements and nominator), `onRequestSubmit` (the case id, case uuid, request type and product) and `onSignOut` (`.user`, `.timeout` or `.sessionExpired`). The latest closures passed are the ones called.
- **Not on iOS.** Custom CSS, the `data-redacto-part` hooks, the CSS theme variables and `seo` are web-only and are not read.

## Sandbox Mode (No Backend Required)

Sandbox mode lets you build and test a full consent PoC — notice → Privacy Center → DSAR — straight from your app, with no backend and no token minting. You paste a static sandbox token into the SDK instead of minting a JWT. Everything is recorded as test data, isolated from live records. Going live is a config swap, not a rewrite.

Sandbox mode is available on the modal `RedactoNoticeConsent` view and on `RedactoPrivacyCenter`. The inline `RedactoNoticeConsentInline` view does not support sandbox mode.

### 1. Get your sandbox credentials

Redacto Dashboard → **API Keys → Sandbox** tab: copy the **Sandbox token** (static, never expires), then copy the **Organization ID** and **Workspace ID** from **Workspace identifiers**.

### 2. Collect consent

Pass `sandboxToken`, `organisationUuid`, and `workspaceUuid`, plus a test identity (`email`, `mobile`, or `ucic`). Omit `accessToken` / `refreshToken`.

```swift
import RedactoConsentSDK
import SwiftUI

struct ConsentDemo: View {
    var body: some View {
        RedactoNoticeConsent(
            noticeId: "your-notice-id",
            baseUrl: "https://api.redacto.io",
            onAccept: { /* consent recorded as test data */ },
            onDecline: { },
            sandboxToken: "your-sandbox-token",
            email: "test.user@example.com",
            organisationUuid: "your-organization-id",
            workspaceUuid: "your-workspace-id"
        )
    }
}
```

### 3. Manage consent & raise a DSAR

Present `RedactoPrivacyCenter` with the same `sandboxToken`, `organisationUuid`, `workspaceUuid`, and test identity. The same test user can review consent, withdraw it, and file a DSAR — all recorded as test data.

```swift
import RedactoConsentSDK
import SwiftUI

struct PrivacyCenterDemo: View {
    var body: some View {
        RedactoPrivacyCenter(
            baseUrl: "https://api.redacto.io",
            onError: { _ in false },
            sandboxToken: "your-sandbox-token",
            email: "test.user@example.com",
            organisationUuid: "your-organization-id",
            workspaceUuid: "your-workspace-id"
        )
    }
}
```

### Sandbox props

| Prop               | Required | Description                                                                 |
| ------------------ | -------- | --------------------------------------------------------------------------- |
| `sandboxToken`     | Yes      | Static sandbox token; a non-empty value activates sandbox mode              |
| `organisationUuid` | Yes      | Organization ID from Workspace identifiers                                   |
| `workspaceUuid`    | Yes      | Workspace ID from Workspace identifiers                                      |
| `ucic`             | One of   | Test user's UCIC; takes precedence over `email` and `mobile`                |
| `email`            | One of   | Test user's email; used when no `ucic` is set (takes precedence over mobile) |
| `mobile`           | One of   | Test user's mobile; used when neither `ucic` nor `email` is set             |

At least one of `ucic`, `email`, or `mobile` is required. Precedence is `ucic` > `email` > `mobile`.

### How it works

- The sandbox token is sent as the `X-Consent-Token` header (raw, no `Bearer`). The acting identity travels in the request itself — query items on reads, JSON body (or form fields) on writes. There is no JWT and no OTP refresh, so a bad token fails fast with a 401.
- The server records everything under `environment=test`, namespaced and isolated. Test data never mixes with, or reads from, live records.
- With the API host as `baseUrl`, sandbox requests go to the same host as live ones: the notice comes from the consent server, and its audio, consent writes, user consents and receipts go to the ledger, which accepts the same `X-Consent-Token`. With the consent server URL as `baseUrl`, sandbox requests route as in 2.0.0.

### Going live

Keep the same views. Remove the sandbox props and pass a real `accessToken` / `refreshToken` JWT minted by your backend. Records then write as `environment=live`.

## Development

From this monorepo:

```bash
cd packages/consent-sdk-ios
swift test
```
