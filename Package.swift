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
        ),
        .library(
            name: "AppFoundationPromoVideoStudio",
            targets: ["AppFoundationPromoVideoStudio"]
        )
    ],
    targets: [
        .target(
            name: "AppFoundationScreenshotStudio",
            path: "Sources/AppFoundation/ScreenshotStudio"
        ),
        .target(
            name: "AppFoundationPromoVideoStudio",
            path: "Sources/AppFoundation/PromoVideoStudio"
        ),
        .target(
            name: "AppFoundation",
            dependencies: [
                "AppFoundationScreenshotStudio",
                "AppFoundationPromoVideoStudio"
            ],
            path: "Sources/AppFoundation",
            exclude: [
                "ScreenshotStudio",
                "PromoVideoStudio"
            ]
        ),
        .testTarget(
            name: "AppFoundationTests",
            dependencies: [
                "AppFoundation",
                "AppFoundationScreenshotStudio",
                "AppFoundationPromoVideoStudio"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
