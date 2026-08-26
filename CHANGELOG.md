# Changelog

All notable changes to AppFoundation are documented in this file.

AppFoundation follows semantic versioning.

## Unreleased

### Added

- Added `RestorePurchasesView`, an extremely compact restore control: a single line of text that transitions through every state — "Restoring purchases…" with a trailing cancel affordance mid-flight, then short colored outcome labels (green success, blue nothing-found, red failure, amber timeout) that auto-clear; tapping an outcome retries. The container owns any leading icon (embed inside `Label`'s title slot to inherit list-row alignment); `contentAlignment: .center` suits free-floating placements like paywalls. Nothing is ever presented modally, so the system App Store sign-in prompt can appear without conflict.
- Added `RestorePurchasesRowConfiguration` and `RestorePurchasesRowModel` for hosts building custom restore surfaces, with short single-line labels and a generous 60-second default timeout.
- Added `PurchaseController.restorePurchases(timeout:)`; concurrent calls coalesce into the in-flight attempt, and a timeout stops waiting on an App Store sync that never answers without requiring the request to honor cancellation.
- Added `PurchaseController.cancelRestore()` to stop waiting on an in-flight restore; abandoned requests drain in the background and their late results are discarded.
- Added `PurchaseFailure.timeout` and `PurchaseFailure.userCancelled` with default copy.

### Changed

- **Breaking:** `FoundationPaywallConfiguration` now requires non-optional `privacyURL` and `termsURL`; the `example.com` fallbacks and conditional legal links are gone, so every paywall ships usable legal links or does not compile.
- `ProPaywallView`'s plan-selection recovery now falls back to `highlightedProductID` when no preferred product resolves, instead of leaving the purchase CTA permanently disabled for configurations that set only a highlighted product.
- Onboarding header pills render their title and symbol in the theme's primary accent instead of 30%-opacity secondary text that read as disabled.
- `ProPaywallView`'s purchase CTA dims while a restore is in flight (it stays disabled without implying a purchase is running).
- Added `PurchaseController.isPurchasing` and `isRestoring` so surfaces can tell the two busy states apart; `ProPaywallView`'s purchase button now only shows its spinner for real purchases while still disabling during a restore.
- `ProPaywallView` embeds `RestorePurchasesView` below the purchase CTA (reachable even when the product catalog fails to load) instead of a footer alert-based flow.
- `ProPlanSettingsSection` embeds `RestorePurchasesView` as its restore row, replacing the alert-based flow.

- Restore failures caused by user cancellation now end silently in `idle` instead of surfacing as an error state, and `StoreKitError.userCancelled` maps to `PurchaseFailure.userCancelled` instead of a generic failure.
- Transaction updates no longer reset in-flight purchase or restore activity; only ask-to-buy style pending state is retired.
- `ProPlanSettingsSection` presents restore through `RestorePurchasesRow` instead of an alert.

### Debug

- Restore diagnostics log App Store transactions that match none of the configured entitlement products (which users experience as "No previous purchases were found"), partial matches, and skipped unverified entitlements.

## 1.2.1 - 2026-08-11

### Added

- Added configurable freshness caching to `AppAIStatusStore`, including `defaultFreshnessInterval`, `isFresh`, `refreshIfNeeded`, and `refreshIfNeededAndWait`.
- Added `FoundationOnboardingHeaderProviding` and optional per-step header titles and symbols for standard and custom onboarding page models.

### Changed

- Coalesced concurrent managed-AI status refreshes and avoided redundant follow-up entitlement synchronization when the active request already includes it.
- Fixed onboarding chrome to a stable, high-contrast presentation across themes: the header pill remains visible and the primary action remains white with a black label.
- Preserved `headerTitle: nil`, `FoundationOnboardingButtonAppearance`, and existing onboarding initializers for source compatibility while making their rendered chrome behavior consistent.
- Changed the package's declared support from iOS and macOS to iOS 26 and later only. Existing conditionally compiled macOS implementations remain in source for compatibility but are no longer supported.

### Documentation

- Documented per-step onboarding header metadata, fallback behavior, and fixed onboarding chrome.
- Updated package requirements, product descriptions, and validation guidance for iOS-only support.

## 1.2.0 - 2026-08-05

### Added

- Added generic app-owned SwiftUI pages to `FoundationOnboardingView` while preserving the existing icon-and-copy initializers.
- Added `FoundationOnboardingConfiguration` for header labels, navigation labels, page indicators, content positioning and padding, and action-button appearance.
- Added `FoundationOnboardingPageContext` with page position, selection state, resolved theme, and foreground colors for page-specific layout and animation.
- Exposed the original onboarding layout as `FoundationOnboardingStandardPage` so apps can mix standard and custom pages.
- Added flexible onboarding documentation, compatibility tests, and Demo previews.

### Changed

- Updated `ProPaywallView` to show the yearly savings percentage whenever monthly and yearly plans are both available.
- Preserved explicitly configured savings-percentage badges and replaced `BEST VALUE` when the same plan already shows savings.
- Standardized `ProPaywallView` plan options on the vertical stacked layout and shortened the lifetime subtitle to `Pay once`.
- Simplified `AppAIBackendStatusRow` to a native labeled status row with optional custom status text.
- Rebuilt direct-provider configuration to match DraftX's native Settings design: API-key management, model saving and browsing, then connection testing.
- Updated the Demo provider screens to use the same native form layout and searchable selected-model picker.

### Fixed

- Preserved the onboarding header height when Skip becomes unavailable on the final page, preventing custom page content from jumping vertically.
- Kept draft provider credentials isolated during connection tests and model discovery while restoring the previously saved credential afterward.

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
