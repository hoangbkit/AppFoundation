# Changelog

## Unreleased

### Commerce

- Added `PurchaseManager` as the preferred source-compatible name for `PurchaseController`.
- Added the simple `hasPro` entitlement property.
- Added `PremiumFeature`, `PremiumAccessPolicy`, and safe post-expiry access decisions for existing user content.
- Added the primary compact `PaywallView` and neutral paywall configuration API.
- Added premium gates, badges, premium buttons, locked overlays, and a composable subscription settings section.
- Made `PaywallView`, `FoundationPaywallView`, and `ClaudePaywallView` follow the active `AppTheme`, including backgrounds, surfaces, foregrounds, borders, shadows, corner radii, accents, and preferred color scheme.
- Added optional full-theme overrides while retaining the legacy fixed `FoundationTheme` initializer for source compatibility.
- Added weekly, monthly, yearly, and lifetime plan presentation across all paywall styles.
- Added `PurchasePlanKind`, plan labels, billing descriptions, recurring/lifetime helpers, and catalog-aware legal disclosure.
- Updated paywall layouts to show the complete configured product catalog and use one column at accessibility text sizes.
- Replaced custom floating and styled paywall close controls with native navigation toolbar cancellation buttons.
- Preserved live StoreKit verification, transaction observation, restore behavior, non-consumable lifetime entitlements, and Debug-only simulation.

### Shared infrastructure

- Added ExportKit safe filenames and extensions, atomic temporary files, PNG/JPEG definitions, pixel-count preflight, rounded exact-size SwiftUI rendering, and a reusable share sheet.
- Added versioned folder-based backup packages with manifests, metadata, checksums, optional assets, security-scoped URL access, duplicate and missing-asset detection, and path-traversal protection.
- Added typed App Group snapshots, shared deep links, and widget reload throttling.
- Added local notification authorization, scheduling, replacement, and cancellation helpers.
- Added `UserFacingError`, `AppInfo`, safe file replacement, async debouncing, review policy, logging, haptics, and `AsyncButton`.
- Added portable tests covering access policy, export filenames and render preflight, backup round trips and unsafe paths, review policy, deep links, weekly plans, and lifetime entitlements.
- Added a Swift 6.2 GitHub Actions workflow for package manifest and test validation.

### Screenshot and promo studios

- Added the reusable Screenshot Studio engine, exact App Store presets, app-injected Screenshot and App Config sections, full-set preview, and concrete screenshot templates.
- Added `AppFoundationPromoVideoStudio` as a separate package product and re-exported it through `AppFoundation`.
- Added an AppReel-inspired Scene / Video editor with deterministic SwiftUI playback, scrubbing, scene selection, safe-area preview, app-injected configuration sections, and full-screen preview.
- Added overlapping crossfade, slide, and zoom transitions with shared preview/export timeline evaluation.
- Added logical-point rendering so preview and exact pixel MP4 output preserve identical typography and geometry.
- Added H.264 silent MP4 export at 30 or 60 fps for vertical, portrait, square, and landscape presets.
- Added `HeroIntroPromoVideoScene`, `DeviceRevealPromoVideoScene`, `FeatureFocusPromoVideoScene`, `LayeredScreensPromoVideoScene`, `AppFlowPromoVideoScene`, `OutroCallToActionPromoVideoScene`, and `ContinuousCanvasPromoVideoScene`.

### Demo app

- Updated the Demo to use `PurchaseManager`, `hasPro`, and the current `PaywallView` while retaining legacy paywalls for migration comparison.
- Added an interactive New APIs showcase for premium gating, subscription settings, rounded PNG export and sharing, backup package verification, shared snapshots and deep links, local notifications, `AppInfo`, review policy, haptics, and `AsyncButton`.
- Updated all Demo paywall configurations to follow live theme changes and added configuration coverage for that behavior.
- Made the complete Demo theme-aware: first-launch onboarding, Home, package browser, paywall picker, settings, navigation chrome, list rows, cards, statuses, and exported preview artwork now follow `ThemeManager.effectiveTheme`.
- Made reusable onboarding and settings views follow the active app theme by default while preserving explicit fixed `FoundationTheme` initializers.
- Added weekly, monthly, yearly, and non-consumable lifetime products to both the in-process simulator and the Demo StoreKit configuration.
- Standardized the settings sheet and all Demo paywall presentations on native toolbar close buttons.
- Changed only the Demo app's installed display name to `AF`; target, scheme, module, and bundle identifiers remain unchanged.
- Combined all Demo configuration into the Settings tab and removed the Home toolbar Settings shortcut.
- Added a ten-template Screenshot Template Gallery and a six-scene Promo Video Studio campaign under Settings → Developer Tools.
- Added Demo tests for all screenshot templates, the complete promo video story, and overlapping scene timing.

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
