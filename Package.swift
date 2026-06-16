// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrialPracticeApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TrialPracticeApp",
            targets: ["TrialPracticeApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TrialPracticeApp",
            exclude: [
                "Assets.xcassets",
                "TrialPracticeApp.entitlements"
            ]
        ),
        .testTarget(
            name: "TrialPracticeAppTests",
            dependencies: ["TrialPracticeApp"]
        )
    ]
)
