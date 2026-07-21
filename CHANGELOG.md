# Changelog

## Unreleased

### Commerce

- Added `PurchaseManager` as the preferred source-compatible name for `PurchaseController`.
- Added the simple `hasPro` entitlement property.
- Added `PremiumFeature`, `PremiumAccessPolicy`, and safe post-expiry access decisions for existing user content.
- Added the primary compact `PaywallView` and neutral paywall configuration API.
- Added premium gates, badges, premium buttons, locked overlays, and a composable subscription settings section.
- Preserved live StoreKit verification, transaction observation, restore behavior, and Debug-only simulation.

### Shared infrastructure

- Added ExportKit safe filenames and extensions, atomic temporary files, PNG/JPEG definitions, pixel-count preflight, rounded exact-size SwiftUI rendering, and a reusable share sheet.
- Added versioned folder-based backup packages with manifests, metadata, checksums, optional assets, security-scoped URL access, duplicate and missing-asset detection, and path-traversal protection.
- Added typed App Group snapshots, shared deep links, and widget reload throttling.
- Added local notification authorization, scheduling, replacement, and cancellation helpers.
- Added `UserFacingError`, `AppInfo`, safe file replacement, async debouncing, review policy, logging, haptics, and `AsyncButton`.
- Added portable tests covering access policy, export filenames and render preflight, backup round trips and unsafe paths, review policy, and deep links.
- Added a Swift 6.2 GitHub Actions workflow for package manifest and test validation.

### Demo app

- Updated the Demo to use `PurchaseManager`, `hasPro`, and the current `PaywallView` while retaining legacy paywalls for migration comparison.
- Added an interactive New APIs showcase for premium gating, subscription settings, rounded PNG export and sharing, backup package verification, shared snapshots and deep links, local notifications, `AppInfo`, review policy, haptics, and `AsyncButton`.
- Added Demo configuration tests for the modern paywall, backup package, and stable deep link.

### Existing theme and simulation work

- Added a reusable monetized theme system modeled on MiLove's production behavior.
- Added Rose, Sunset, Lavender, Midnight, Paper, and Champagne default themes.
- Added immutable theme catalogs that support excluding, replacing, reordering, and appending themes.
- Added persisted selected-theme state, free fallback resolution, and App Group-compatible widget state.
- Added five-minute Pro theme previews, shared preview expiry when switching themes, promotion on unlock, and selected Pro theme preservation after entitlement loss.
- Added a customizable SwiftUI theme picker, environment integration, themed background/card primitives, and bridges to existing `FoundationTheme` components.
- Added optional alternate app-icon application support.
- Added a Debug-only in-process purchase simulator for CLI-deployed prototypes.
- Added `PurchaseController` simulation configuration with `simulated: Bool = false` and runtime switching through `setSimulatedPurchasesEnabled(_:)`.

## 1.0.0 - 2026-07-16

- Initial iOS 26+ release.
- Added StoreKit 2 purchase and entitlement infrastructure.
- Added reusable onboarding, paywall, settings, and design primitives.
- Added XcodeGen Demo app and local StoreKit configuration.
- Added portable core tests and iOS purchase-controller tests.
