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
3. Select a release version (for example `0.0.4`).
4. Add the `RedactoConsentSDK` product to your app target.

Or via `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/redactolabs/consent-sdk-ios.git", from: "0.0.4")
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
platform :ios, '16.0'

target 'YourApp' do
  use_frameworks!
  pod 'RedactoConsentSDK', '~> 0.0'
end
```

Then run:

```bash
pod install
```

## Quick Start

```swift
import RedactoConsentSDK
import SwiftUI

struct ContentView: View {
    var body: some View {
        RedactoNoticeConsent(
            noticeId: "your-notice-id",
            accessToken: "your-access-token",
            refreshToken: "your-refresh-token"
        )
    }
}
```

## Development

From this monorepo:

```bash
cd packages/consent-sdk-ios
swift test
```
