// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RedactoConsentSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RedactoConsentSDK", targets: ["RedactoConsentSDK"]),
    ],
    targets: [
        .target(name: "RedactoConsentSDK"),
        .testTarget(name: "RedactoConsentSDKTests", dependencies: ["RedactoConsentSDK"]),
    ]
)
