# Validation report

Validated on 2026-07-16 with Swift 6.2.1 on Linux.

## Passed

- `swift package dump-package`
- `swift test`: 12 portable unit tests, 0 failures
- `swift-format lint` across package, tests, and Demo source
- Swift syntax parsing for every `.swift` file
- Privacy manifest plist parsing and required root keys
- StoreKit configuration JSON parsing and product-ID consistency
- Asset catalog JSON parsing
- XcodeGen YAML parsing and checks for iOS 26.0, Team ID, bundle ID, and local package path

## Included for Xcode execution

- 5 StoreKit purchase-controller tests guarded for Apple platforms
- 2 Demo app tests
- Shared Demo scheme with coverage enabled
- XcodeGen project specification and local StoreKit configuration

## Environment limitation

This runtime does not include macOS, Xcode 26, iOS SDKs, or XcodeGen, so the generated `.xcodeproj`, iOS simulator build, StoreKit UI flow, and Apple-platform-only tests could not be executed here. Run `cd Examples/Demo && make test` on a Mac with Xcode 26 to complete those checks.
