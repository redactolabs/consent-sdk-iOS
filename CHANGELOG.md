# Changelog

All notable changes to `RedactoConsentSDK` are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

## [2.0.0] - 2026-09-29

The first release published since `1.1.0`: it ships everything under `[1.2.0-beta.0]` and `[1.2.0]` below, plus the changes here. It brings every surface to parity with the React SDK, which is the reference implementation. It is a major version: `baseUrl` is now required, errors arrive as `RedactoAPIError.api`, `ConsentStatus` gains a case and the modal draws its own backdrop. See *Migrating from 1.x* in the README.

### Added

- **Console-set appearance** (React #703): colours, style (classic, minimal, soft, glass), radii, layout, position, backdrop, max width, logo size and position, text scale, motion, phone footer, collapsible sections, switches, TTS highlight and dark mode, applied to the modal, inline and assisted notices. Host `settings` override the console; the console overrides the defaults. CSS-only features (custom CSS, CSS variables) have no native equivalent and are ignored.
- **Consent language on the record**: the modal and assisted submits send the BCP-47 code of the language the notice was read in.
- **Assisted notice**: its own copy in all 23 languages React ships, audio narration with highlighting, product policy links and the DPO footer.
- **Privacy Center**:
  - DSR form: product step; erasure "revoke consent on fulfilment" choice; nomination by email or mobile; correction by field with both values required; access time period.
  - Notification hub: bell, sheet and full page.
  - Case pages: request-details tab, document-request uploads, opening attachments, and a composer locked on finalised cases.
  - Consent Manager: My Consents / Managing tabs, product and purpose views, CSV export, TRANSFERRED chip, and nominator error messages.
  - Shell: activity timeline, receipts paging, workspace branding, account menu with sign-out, session-expired screen, and token re-sync with `onTokensRefreshed`.
  - Localisation: all 23 string bundles regenerated from React's translations.

### Changed

- **Breaking:** `baseUrl` is required on `RedactoNoticeConsent`, `RedactoNoticeConsentInline` and `RedactoNoticeAssisted`, and there is no built-in host: a missing or blank value fails with "baseUrl is required" before any request. `RedactoConstants.defaultConsentAPIBaseURL` is removed.
- **Breaking (visual):** the modal fills its container, dims it and places the card from the appearance, as React does.
- The modal re-reads when `noticeId`, the tokens, `language`, `applicationId`, `ledgerBaseUrl`, `validateAgainst`, `includeFullyConsentedData` or the sandbox inputs change. A failed load shows React's error dialog with Refresh, and bad props show a configuration error.
- Locking follows React. On a reconsent, purposes already consented are locked and listed first. Otherwise, rows lock only in fully-consented review mode, which now needs only every row to be `selected`.
- The saved purpose order applies to single-product notices (rows, payload and narration). The additional-text footer shows without a privacy-center link. Language labels are native, and TTS falls back to the default language.
- Assisted: one flat purpose list in product order, submitted one row per purpose, as React does. Purpose pre-selection is seeded on load and reset, and the notice is re-read when the organisation, workspace, notice or `baseUrl` changes.
- Modify consent follows React: revoke when active, regrant when withdrawn or revoked, renew when expired, nothing when declined.
- Privacy Center dates are formatted in the chosen language and accept timestamps without a timezone. Users no longer see raw decoding errors. A dead refresh token stops retrying.
- Guardian (DigiLocker) initiate and status each make one request; a URL that cannot be built throws instead of crashing.
- A request the server redirects (for example `/notifications` to `/notifications/`) keeps its credential. URLSession drops `Authorization` on a redirect where a browser keeps it, so the notification list answered 401.
- The inline notice reads from the ledger when `ledgerBaseUrl` is set, as the modal does. A magic link (`applicationId`) and a read with no token stay on the consent server, which alone serves `specific_uuid` and the tokenless `get-notice`.
- The notice's text sits at the web's 1.5x line height, its buttons are the web's 39pt, a medium weight the font lacks (Arial) draws regular as the browser does, and the phone card uses the full safe area. The notice now measures the same as the React SDK's at the same width.
- The notice follows the user's text-size setting. At the default size it measures exactly as the React SDK's; a larger setting grows its text along iOS's body-text curve, up to twice the default. The guardian form now uses the notice's font too.
- The Privacy Center keeps the language the reader picked when the host re-renders (for example after a token refresh); its store is now built once.
- A guardian (DigiLocker) request started for one principal is cancelled when the host swaps the token, and its response is ignored; status polling no longer keeps a dismissed notice alive.
- The notification bell stops polling once the Privacy Center is gone.
- A slower Consent Manager response can no longer replace the list of a newer filter, tab or page.
- A same-host redirect keeps the credential only on the same port.
- An SVG logo renders on iPad, where web views default to desktop layout.
- The Privacy Center keeps its own colour scheme for placeholders and bars when the host prefers the other one.
- A select field shows its value on one left-aligned line.
- Opening the notice requests its audio once, not twice.
- The modal card is as tall as its content, up to its cap. The age check, guardian form and short notices no longer stretch to full height, and a logo lines up with the text instead of centring in a wide box.

### Fixed

- The SDK builds with Xcode 15.4 (Swift 5.10) again: two tasks read a weakly captured `self` from their enclosing closure, which only Xcode 16 accepts. A new iOS CI workflow builds and tests every iOS change on the release runner's toolchain.
- **A notice with any blank field never rendered.** The ledger and the consent server both send a blank `logo_url`, `privacy_center_url`, colour, font, heading, button label or purpose `description` as `null`, and the notice decoder required every one of them, so the read threw a decoding error and nothing appeared. Those fields now decode `null` or absent as empty, which the views already treat as "not set"; the modal falls back to its default heading and button labels for an empty one. A legacy recorded grant with no `status`, `needs_reconsent` or `data_elements`, and a malformed `dpo_info` or `products` block, no longer fail the notice either.
- **The modal notice showed a spinner forever for a user who had already consented.** On a 409 it called `onAccept` but never left the loading state. It now renders nothing, as React does.
- **The review-mode button reopened the consent form instead of handing back to the host.** For a fully consented user (`includeFullyConsentedData`) the button now calls `onAccept`, and its default label is "Continue", matching React.
- **The inline notice never told the host it was valid until the user tapped something.** `onValidationChange` and auto-submit now run as soon as the notice loads, so a notice with nothing required (or satisfied by pre-selection) reports `true` and submits without a tap. `onValidationChange` fires only when the value changes.
- **The inline notice ignored the notice's pre-selection setting.** `MANDATORY` and `ALL` now seed the ticks, as in React.
- **The inline notice re-read itself, and dropped the reader's ticks, every time its view reappeared** (a List row scrolling back, a navigation pop). It now reads once per identity.
- **The inline notice ignored a new `applicationId`, `noticeUuid`, `language`, org or workspace on a mounted view**, so a 409 for one application kept the notice hidden for the next and the old `specific_uuid` was submitted. A change to any of them now resets the notice and reads again. A new access token also re-reads, so the next principal's 409 and ledger check govern.
- **Privacy Center attachments failed with 422.** Neither upload sent the `payload` part the endpoints require; the DSR upload now carries `organization_uuid`, `uuid`, `is_public`, `allow_ai_processing` and its metadata (and the sandbox identity), and a case upload carries `{"metadata": null}`, as React sends.
- **One unexpected consent status blanked the whole Consent Manager.** `REVOKED` and `WITHDRAWN` now read as the withdrawn state and any other unknown value as `ConsentStatus.unknown`, which renders with no actions.
- **A case thread failed to load, and reported an error every 10 seconds, when a document request had null fields** or a message had an unknown `message_type` or `sender_role`. Null text fields decode as empty, an unknown message type as a plain message.
- An upload response without `file_name` or `file_size` no longer fails an upload that succeeded.
- A case message from a `sender_role` this release does not know is kept as `SenderRole.other` and shown on the received side under the sender's email (or the time alone), never attributed to "You" or "Privacy team".
- An inline submit still in flight when the identity or access token changes no longer calls `onAccept` or submits the previous notice under the new identity; the old configuration is dropped at once and the new identity still auto-submits once its read lands.

### Changed

- **Breaking:** `ConsentStatus` gains an `unknown` case; an exhaustive `switch` over it needs one more branch.
- **Breaking:** a failed HTTP response from the notice and inline APIs now throws `RedactoAPIError.api(status:code:message:)`, instead of `.unauthorized`, `.forbidden`, `.notFound`, `.alreadyConsented`, `.invalidRequest`, `.validationError` or `.serverError` with fixed SDK copy. Those cases stay in the enum but are no longer thrown for an HTTP status. `message` is the server's `message` or `detail` when the body has one, otherwise a status-based SDK message (401, 403, 5xx) or the caller's fallback; `errorCode` is the server's `error_code` when present and `nil` otherwise. Match on `error.statusCode` (for example `error.statusCode == 409` for an existing consent) and `error.errorCode` instead; `statusCode` returns the same value for the old cases, so a `statusCode` check works against both.

## [1.2.0-beta.0] - 2026-08-13

Never published: the release workflow rejected a pre-release version, so the public repo and CocoaPods stayed at `1.1.0`. Everything here and under `[1.2.0]` ships in `2.0.0`.

### Added

- Sandbox mode for `RedactoNoticeConsent` and `RedactoPrivacyCenter` via a pasted static token, reaching parity with the React / React Native / Flutter SDKs (#552). A new `SandboxConfig` carries the org/workspace and acting test identity; the notice and Privacy Center send the static `X-Consent-Token` instead of a live JWT when configured.
- "Accept All" button on the notice, alongside a re-laid-out footer (#588). Required data elements start unchecked, so the accept button was disabled until each was ticked by hand; Accept All is a one-click shortcut that submits the full explicit purpose list. The footer switches layout on `horizontalSizeClass` and emits actions in visual order so focus order follows. Host API and payload shape are unchanged.

### Fixed

- Privacy Center now sends the acting sandbox identity (`org_user_id` / `primary_email` / `primary_mobile`) on requested-document submit, receipts and document uploads (#598). In sandbox mode the static token carries no identity, so these principal-scoped calls previously failed with "Sandbox request requires a user identifier". The live JWT path is unchanged.

## [1.2.0] - 2026-07-28

### Added

- Per-purpose revoke warning message in the Privacy Center, reaching parity with the React SDK. `PurposeItem` and `UserConsent` decode a new optional `revoke_warning_message` (surfaced as `revokeWarningMessage`) from the Privacy Center user-consents response, and `ConsentManagerNormalization` threads it through. The revoke confirmation modal shows the admin's custom message when present and non-empty, otherwise the localized default. Mirrors the React SDK's `revoke_warning_message || t('revokeConsentWarning')`.

### Changed

- Aligned the default revoke-warning copy with the React SDK. A new localized `revokeConsentWarning` string (English: "If you revoke this consent, you may lose access to certain features that rely on this data.") is now the fallback shown in the revoke confirmation modal when no custom message is set, replacing the previous `revokeConfirmBody` copy at that site. Localized across all 23 Privacy Center languages, sourced from the React SDK's translations. `revokeConfirmBody` is retained.

### Fixed

- `RedactoConsentInline` reads the notice from the authenticated `notices/{notice_uuid}` endpoint whenever an access token is available, instead of the tokenless `notices/get-notice/{notice_uuid}`. Only the consent server serves the tokenless path, so pointing `baseUrl` at the Go consent ledger failed with 404 `Resource not found`; `notices/{notice_uuid}` is served by both backends and returns the caller's consent overlay (and 409 `CONSENT_ALREADY_PROVIDED`). `ConsentAPI.FetchInlineConsentContentParams` takes a new optional `accessToken`; without one the tokenless path is unchanged.
- `ConsentInlineViewModel.updateAccessToken(_:)` re-reads the notice when the first read was tokenless, so a token that arrives after the view appears switches to the authenticated endpoint instead of leaving the unauthenticated content on screen. A later token change does not refetch. `performFetch()` also clears `hasAlreadyConsented`, so a 409 for one principal cannot blank the view for the next one.

## [1.1.0] - 2026-06-15

> Aligns the published release line. `RedactoConsentSDK` was already on CocoaPods and SPM at `1.0.0` (a pre–Privacy Center cut). This is the first 1.x release to ship the Privacy Center, and it also adds the My Receipt screen and the "no data" empty state. The Privacy Center work was previously tracked internally as `0.1.0`, which was never published.

### Added

- `RedactoPrivacyCenter` SwiftUI module with full feature parity with the React Native SDK:
  - Consent Manager screen (direct/nominated tabs, search, product filters, paginated list, modify/revoke/regrant/renew via modal).
  - DSR Form screen (request type selector, purposes/data elements, correction fields, grievance types, nomination, time period, supporting docs upload, success screen with case ID).
  - Activity Log screen (paginated, status badges, timestamps).
  - Case History + Case Details screens (status tabs, message thread with 10s polling, attachments, document request cards).
- My Receipt (consent receipts) screen: a new "Receipts" tab that lists a user's consent receipts and lets them export/share a receipt via the system share sheet. Backed by the `Receipt` model, `ReceiptListViewModel`, and new receipt endpoints on `PrivacyCenterAPI`.
- Privacy Center "no data" empty state: the Privacy Center now checks data availability on load (`PrivacyCenterStore.checkDataAvailability()`), showing a loader while checking and a dedicated empty state — with the tab bar hidden — when the user has no consent or request data.
- `PrivacyCenterTheme` with light/dark token sets, injected via SwiftUI environment.
- `PrivacyCenterAPI` actor with single-flight token refresh (`TokenStore`) and 401 retry interceptor.
- `MultipartFormBuilder` for document upload via `URLSession.upload(for:from:)`.
- Localization bundles for 24 languages (English plus Assamese, Bhojpuri, Bengali, Bodo, Dogri, Konkani, Gujarati, Hindi, Kannada, Kashmiri, Maithili, Malayalam, Manipuri, Marathi, Nepali, Odia, Punjabi, Sanskrit, Santali, Sindhi, Tamil, Telugu, Urdu).
- Public re-exports: `RedactoPrivacyCenter`, `PrivacyCenterTheme`, `PrivacyCenterThemeMode`, `PrivacyCenterAPI`, `TokenStore`, `PCStrings`.

### Changed

- `Package.swift` declares `defaultLocalization: "en"` and processes Privacy Center resources.
- `RedactoConsentSDK.podspec` adds `resource_bundles` for shipped strings.
- `RedactoJwtPayload` gains optional `email`, `contact`, `primary_email`, `organisation_name`, `sub` for Privacy Center auth flows.
- Consent Manager aligned to the `GET user-consents` API contract (updated `UserConsent`, `RedactoJwtPayload`, `PrivacyCenterAPI`, and `ConsentManagerViewModel`).
- Removed the status filter from the native Consent Manager / receipts list to match the other platform SDKs.

### Fixed

- Keep revoked-consent purposes raisable in Privacy Center DSAR forms.
- Hardened Privacy Center JSON decoding: lenient `CaseMessage` (optional `documents`/`document_uuids`, uuids derived from documents), `Receipt` (accepts `uuid`/`receipt_uuid`/`id`, optional display fields, `ReceiptDetail` `skip`/`limit` pagination), and optional `dpo_url`.
- Show an error empty state in the receipts list when receipt loading fails.
- Resolve the localized-strings resource bundle under CocoaPods (`Bundle.module` is SwiftPM-only), so the Privacy Center builds and localizes correctly when installed via CocoaPods.

## [0.0.4] - 2026-03-30

### Added

- Initial public iOS SDK dry-run release baseline for Swift Package Manager and CocoaPods.
