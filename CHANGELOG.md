# Changelog

## Unreleased

- Added a reusable monetized theme system modeled on MiLove's production behavior.
- Added Rose, Sunset, Lavender, Midnight, Paper, and Champagne default themes.
- Added immutable theme catalogs that support excluding, replacing, reordering, and appending themes.
- Added persisted selected-theme state, free fallback resolution, and app-group-compatible widget state.
- Added five-minute Pro theme previews, shared preview expiry when switching themes, promotion on unlock, and selected Pro theme preservation after entitlement loss.
- Added a customizable SwiftUI theme picker, environment integration, themed background/card primitives, and bridges to existing `FoundationTheme` components.
- Added optional alternate app-icon application support.
- Added portable catalog/resolver tests and iOS theme-manager tests.
- Added a Debug-only in-process purchase simulator for CLI-deployed prototypes.
- Added `PurchaseController` simulation configuration with `simulated: Bool = false` and runtime switching through `setSimulatedPurchasesEnabled(_:)`.
- Updated the Demo for explicit `mycli --billing simulated` opt-in while preserving local `.storekit` testing in Xcode's Run action.

## 1.0.0 - 2026-07-16

- Initial iOS 26+ release.
- Added StoreKit 2 purchase and entitlement infrastructure.
- Added reusable onboarding, paywall, settings, and design primitives.
- Added XcodeGen Demo app and local StoreKit configuration.
- Added portable core tests and iOS purchase-controller tests.