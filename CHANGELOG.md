# Changelog

All notable changes to `RedactoConsentSDK` are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

## [1.1.0] - 2026-06-17

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
- DPO contact: `DpoInfo` exposes `dpo_email` and a resolved `dpoContactUrl` (prefers `dpo_url`, falls back to `mailto:`).

### Changed

- `Package.swift` declares `defaultLocalization: "en"` and processes Privacy Center resources.
- `RedactoConsentSDK.podspec` adds `resource_bundles` for shipped strings.
- `RedactoJwtPayload` gains optional `email`, `contact`, `primary_email`, `organisation_name`, `sub` for Privacy Center auth flows.
- Consent Manager aligned to the `GET user-consents` API contract (updated `UserConsent`, `RedactoJwtPayload`, `PrivacyCenterAPI`, and `ConsentManagerViewModel`).
- Removed the status filter from the native Consent Manager / receipts list to match the other platform SDKs.
- `PCButton` gains a `size` (`.regular`/`.compact`) and explicit full-width control; the Case History header now uses a compact "New request" button.

### Fixed

- Keep revoked-consent purposes raisable in Privacy Center DSAR forms.
- Hardened Privacy Center JSON decoding: lenient `CaseMessage` (optional `documents`/`document_uuids`, uuids derived from documents), `Receipt` (accepts `uuid`/`receipt_uuid`/`id`, optional display fields, `ReceiptDetail` `skip`/`limit` pagination), and optional `dpo_url`.
- Show an error empty state in the receipts list when receipt loading fails.
- Resolve the localized-strings resource bundle under CocoaPods (`Bundle.module` is SwiftPM-only), so the Privacy Center builds and localizes correctly when installed via CocoaPods.

## [0.0.4] - 2026-03-30

### Added

- Initial public iOS SDK dry-run release baseline for Swift Package Manager and CocoaPods.
