// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppFoundation",
    platforms: [
        .iOS("26.0"),
        .macOS("15.0")
    ],
    products: [
        .library(
            name: "AppFoundation",
            targets: ["AppFoundation"]
        ),
        .library(
            name: "AppFoundationScreenshotStudio",
            targets: ["AppFoundationScreenshotStudio"]
        )
    ],
    targets: [
        .target(
            name: "AppFoundationScreenshotStudio",
            path: "Sources/AppFoundation/ScreenshotStudio"
        ),
        .target(
            name: "AppFoundation",
            dependencies: ["AppFoundationScreenshotStudio"],
            path: "Sources/AppFoundation",
            exclude: ["ScreenshotStudio"]
        ),
        .testTarget(
            name: "AppFoundationTests",
            dependencies: [
                "AppFoundation",
                "AppFoundationScreenshotStudio"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
