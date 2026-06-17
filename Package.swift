// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RedactoConsentSDK",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RedactoConsentSDK", targets: ["RedactoConsentSDK"]),
    ],
    targets: [
        .target(
            name: "RedactoConsentSDK",
            resources: [
                .process("PrivacyCenter/Localization/Resources"),
            ]
        ),
        .testTarget(name: "RedactoConsentSDKTests", dependencies: ["RedactoConsentSDK"]),
    ]
)
