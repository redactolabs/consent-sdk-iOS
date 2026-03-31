# Releasing `RedactoConsentSDK`

## Versioning policy

- Uses Semantic Versioning: `MAJOR.MINOR.PATCH`
- Release tag format in public repo: `vX.Y.Z`
- `RedactoConsentSDK.podspec` version and source tag must match the release version
- Keep `[Unreleased]` and released entries updated in `CHANGELOG.md`

## Release steps

1. Update iOS SDK code in `packages/consent-sdk-ios`.
2. Update `CHANGELOG.md`.
3. Trigger GitHub Actions workflow `Release iOS SDK` with:
   - `version`: next semver (for example `0.0.5`)
   - `public_repo`: public repository in `owner/name` format
   - `publish_cocoapods`: `true` for production release
4. Verify:
   - Public repo has tag `vX.Y.Z`
   - SPM resolves from the public Git URL
   - CocoaPods release is visible (`pod trunk info RedactoConsentSDK`)
