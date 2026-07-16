// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppFoundation",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "AppFoundation",
            targets: ["AppFoundation"]
        )
    ],
    targets: [
        .target(
            name: "AppFoundation"
        ),
        .testTarget(
            name: "AppFoundationTests",
            dependencies: ["AppFoundation"]
        )
    ],
    swiftLanguageModes: [.v6]
)
