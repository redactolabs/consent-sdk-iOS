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
3. Select a release version (for example `2.0.0`).
4. Add the `RedactoConsentSDK` product to your app target.

Or via `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/redactolabs/consent-sdk-ios.git", from: "2.0.0")
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
platform :ios, '16.0'

target 'YourApp' do
  use_frameworks!
  pod 'RedactoConsentSDK', '~> 2.0'
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
            baseUrl: "https://your-consent-api-host/consent",
            onAccept: { /* consent recorded */ },
            onDecline: { }
        )
    }
}
```

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
            baseUrl: "https://your-consent-api-host/consent",
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
            baseUrl: "https://consent.redacto.ai",
            slug: "your-workspace-slug",
            sandboxToken: "your-sandbox-token",
            email: "test.user@example.com",
            organisationUuid: "your-organization-id",
            workspaceUuid: "your-workspace-id",
            onError: { _ in false }
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
- Sandbox requests always talk to the consent server, never the Go ledger.

### Going live

Keep the same views. Remove the sandbox props and pass a real `accessToken` / `refreshToken` JWT minted by your backend. Records then write as `environment=live`.

## Development

From this monorepo:

```bash
cd packages/consent-sdk-ios
swift test
```
