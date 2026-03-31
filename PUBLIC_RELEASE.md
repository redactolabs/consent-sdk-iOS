# Public Repository Bootstrap (One-Time)

This monorepo is private. To make the iOS SDK publicly installable through SPM and CocoaPods, publish from a dedicated public repository.

## Target repository layout

The public repository root must contain:

- `Package.swift`
- `Sources/RedactoConsentSDK/...`
- `Tests/RedactoConsentSDKTests/...`
- `RedactoConsentSDK.podspec`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`

## One-time setup

1. Create a public GitHub repository (for example `redacto-inc/consent-sdk-ios`).
2. Add required secrets in this private monorepo:
   - `IOS_PUBLIC_REPO_PAT` (token that can push to the public repo)
   - `COCOAPODS_TRUNK_TOKEN` (token for pod trunk publishing)
3. Run the GitHub Actions workflow `Release iOS SDK`.
   - Provide `version` (for example `0.0.4`)
   - Provide `public_repo` in `owner/name` format
   - Set `publish_cocoapods` to `true` to publish the pod

The workflow syncs `packages/consent-sdk-ios` into the public repository root, tags `v<version>`, and publishes the podspec.
