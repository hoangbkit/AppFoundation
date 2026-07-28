# Changelog

All notable changes to AppFoundation are documented in this file.

AppFoundation follows semantic versioning while its public API remains in the `0.x` development series.

## Unreleased

### Added

- Added `AppIconOption`, `AppIconPickerView`, and `AppIconPickerSection` for registering and presenting primary and alternate app icons in Settings.
- Added reusable locked-icon, upgrade-routing, loading, error, selection, and accessibility behavior.
- Added `AppIconManager` for app-owned icon interfaces and plural-name picker aliases.

### Changed

- Generalized alternate icon switching while preserving `ThemeAppIconManager` and `ThemeAppIconError` source compatibility.

### Documentation

- Added app-icon picker registration and Settings adoption guidance.
- Rebuilt the changelog from the actual `0.1.0` through `0.1.8` tag history.
- Updated the README for the current package products, macOS support, multi-video Promo Video Studio, and `0.1.8` installation guidance.

## 0.1.8 - 2026-07-24

### Added

- Added complete macOS 15 support to `AppFoundationPromoVideoStudio`.
- Added macOS promo-video models, deterministic composition, frame-by-frame H.264 export, and a native Studio editor.
- Added a three-column macOS Promo Video Studio workspace with registered-video switching, scene selection and thumbnails, live preview, timeline playback and scrubbing, Scene and Video inspectors, output settings, safe-area controls, and full-window preview.
- Added native macOS save-panel export and Finder reveal for generated MP4 files.
- Made all seven Promo Video Studio story templates available on macOS.
- Added `Documentation/PromoVideoStudioMacOS.md`.
- Added macOS Promo Video Studio tests.
- Added a separate `DemoMac` XcodeGen target with native navigation, Screenshot Studio and Promo Video Studio samples, a macOS app icon, and a `make build-mac` command.

### Changed

- Brought the macOS Screenshot Studio editor to parity with the current Studio workflow using a native three-column registered-screenshot, preview, and inspector workspace.
- Expanded macOS Screenshot Studio preview and export behavior, including complete-set review, destination-folder export, and Finder reveal.
- Updated macOS Studio documentation and Demo project configuration.
- Unified the iOS and macOS Demo display name as `AF` and corrected the Demo bundle identifiers and app-icon configuration.

## 0.1.7 - 2026-07-23

### Added

- Added multi-video Promo Video Studio support through `PromoVideoStudio(videos:)`.
- Added toolbar selection between registered promo videos.
- Added reusable support types for video selection and Studio presentation.
- Added three complete Demo promo-video projects covering AppFoundation, Widget Showcase, and Screenshot Studio stories.

### Changed

- Preview, scene selection, scrubbing, configuration, playback, and export now operate on the currently selected promo video only.
- Retained `PromoVideoStudio(project:)` as the source-compatible single-project initializer.
- Split the Demo promo campaign into reusable project and component files.

## 0.1.6 - 2026-07-23

### Added

- Added `ScreenshotStudioStyle` with configurable accent, text, surface, border, background, and gradient colors.
- Added `PromoVideoStudioStyle` with configurable accent, text, surface, border, background, and gradient colors.
- Expanded `WidgetShowcaseStyle` with gradient start, gradient end, and shadow customization.

### Changed

- Applied polished default presentation across Screenshot Studio, Promo Video Studio, and Widget Showcase.
- Refined compact and regular-size Studio layouts, preview surfaces, inspector sections, navigation chrome, and control styling.
- Polished reusable onboarding and `ProPaywallView` presentation.
- Reorganized the Demo from tab-heavy navigation into a focused Home and Settings structure.
- Simplified Developer Tools navigation and standardized the Demo's package showcases.

### Fixed

- Cleaned up Demo and package integration issues and verified successful builds after the presentation refactor.

## 0.1.5 - 2026-07-23

### Added

- Added `AppFoundationWidgetShowcase` as a separate package product and re-exported it through `AppFoundation`.
- Added normalized widget catalogs grouped by small, medium, and large families.
- Added responsive widget previews, gallery and detail views, generated Home Screen setup guidance, and app-owned upgrade actions.
- Added Free and Pro widget presentation without coupling the package to an app's model types or widget extension.
- Added a Demo catalog containing small, medium, and large widget examples.
- Added Widget Showcase model and catalog tests.
- Added `Documentation/WidgetShowcase.md`.

### Changed

- Made `WidgetShowcaseStyle` conform to `Sendable`.

## 0.1.4 - 2026-07-23

### Added

- Added `AppFoundationPromoVideoStudio` as a separate package product and re-exported it through `AppFoundation`.
- Added an AppReel-inspired Scene and Video editor with deterministic SwiftUI playback, scrubbing, scene selection, safe-area preview, app-injected configuration sections, and full-screen preview.
- Added overlapping crossfade, slide, and zoom transitions with shared preview/export timeline evaluation.
- Added logical-point rendering so interactive preview and exact-pixel MP4 output preserve matching typography and geometry.
- Added silent H.264 MP4 export at 30 or 60 fps for vertical, portrait, square, and landscape presets.
- Added `HeroIntroPromoVideoScene`, `DeviceRevealPromoVideoScene`, `FeatureFocusPromoVideoScene`, `LayeredScreensPromoVideoScene`, `AppFlowPromoVideoScene`, `OutroCallToActionPromoVideoScene`, and `ContinuousCanvasPromoVideoScene`.
- Added a six-scene Demo campaign and timing/export tests.
- Added `Documentation/PromoVideoStudio.md`.

### Fixed

- Fixed upside-down exported promo-video frames while preserving the correct live-preview orientation.

## 0.1.3 - 2026-07-23

### Added

- Added `AppFoundationScreenshotStudio` as a separate package product and re-exported it through `AppFoundation`.
- Added macOS 15 package support for compatible AppFoundation APIs.
- Added the initial native macOS Screenshot Studio editor and reusable `ScreenshotMacWindowFrame` presentation.
- Added hero, feature, layered, and gallery screenshot templates.
- Added a ten-template Screenshot Template Gallery to the Demo app.
- Added `Documentation/ScreenshotStudioMacOS.md`.

### Changed

- Expanded and reorganized Screenshot Studio and reusable-component documentation.
- Refined Screenshot Studio export compatibility and preview behavior across iOS and macOS.
- Consolidated Demo configuration into Settings and simplified Home navigation.

## 0.1.2 - 2026-07-22

### Added

- Added the initial reusable Screenshot Studio engine for app-owned SwiftUI screenshot definitions.
- Added exact App Store device presets, locale support, full-set preview, app-injected Screenshot and App Config sections, and exact-size export.
- Added reusable backgrounds, device frames, system chrome, promotional components, and visual effects.
- Added Screenshot Studio examples and tests.
- Added `Documentation/ScreenshotStudio.md` and `Documentation/ScreenshotStudioComponents.md`.

### Fixed

- Fixed contextual resolution of default App Store screenshot presets in `ScreenshotStudioProject` initialization.

## 0.1.1 - 2026-07-21

### Added

- Added `ProPlanSettingsSection` and configurable Pro-plan settings presentation.
- Added `ProUpsellView`, comparison rows, and `LimitReachedUpsellFlow` for reusable Free-versus-Pro upgrade flows.
- Added optional paywall configuration to `FoundationSettingsView`.
- Added a Demo screen covering Pro settings and limit-reached upsells.

### Changed

- Updated `FoundationSettingsView` to use the reusable Pro-plan section and app-owned paywall presentation.

## 0.1.0 - 2026-07-21

### Commerce

- Added StoreKit 2 product loading, purchase, restore, verified entitlement evaluation, transaction observation, and foreground refresh.
- Added `PurchaseManager` as the preferred source-compatible name for `PurchaseController` and added the simple `hasPro` entitlement property.
- Added Debug-only in-process purchase simulation and runtime switching.
- Added weekly, monthly, yearly, and non-consumable lifetime plan support.
- Added `PurchasePlanKind`, plan labels, billing descriptions, recurring/lifetime helpers, and catalog-aware legal disclosure.
- Added `PaywallView`, `FoundationPaywallView`, and `ProPaywallView` with active-theme support and adaptive catalog layouts.
- Added premium gates, badges, buttons, locked overlays, and safe post-expiry access decisions for existing user content.

### Themes and reusable UI

- Added the Rose, Sunset, Lavender, Midnight, Paper, and Champagne theme defaults.
- Added immutable theme catalogs, persisted selected-theme state, free fallback resolution, and App Group-compatible widget state.
- Added timed Pro theme previews, promotion on unlock, and selected Pro theme preservation after entitlement loss.
- Added SwiftUI environment integration, a customizable theme picker, themed background/card primitives, and bridges to `FoundationTheme` components.
- Added optional alternate app-icon application support.
- Added reusable onboarding, settings, paywall, and design primitives.

### Shared infrastructure

- Added ExportKit safe filenames and extensions, atomic temporary files, PNG/JPEG definitions, pixel-count preflight, exact-size SwiftUI rendering, and reusable sharing support.
- Added versioned folder-based backup packages with manifests, metadata, checksums, optional assets, security-scoped URL access, duplicate and missing-asset detection, and path-traversal protection.
- Added typed App Group snapshots, schema metadata, shared deep links, and widget reload throttling.
- Added local notification authorization, scheduling, replacement, and cancellation helpers.
- Added `UserFacingError`, `AppInfo`, safe file replacement, async debouncing, review policy, logging, haptics, and `AsyncButton`.
- Added portable package tests and a Swift 6.2 GitHub Actions validation workflow.

### Demo app

- Added the XcodeGen Demo app and local StoreKit configuration.
- Added interactive examples for commerce, themes, premium gating, settings, exports, backups, App Group snapshots, deep links, notifications, review policy, haptics, and reusable controls.
- Added weekly, monthly, yearly, and non-consumable lifetime products to both the in-process simulator and Demo StoreKit configuration.
- Added theme-aware onboarding, navigation, settings, paywall, list, card, and exported-preview presentation.
- Standardized paywall and settings dismissal on native navigation toolbar cancellation actions.
