# Changelog

All notable changes to AppFoundation are documented in this file.

AppFoundation follows semantic versioning.

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

## 1.2.0 - 2026-08-05

### Added

- Added generic app-owned SwiftUI pages to `FoundationOnboardingView` while preserving the existing icon-and-copy initializers.
- Added `FoundationOnboardingConfiguration` for header labels, navigation labels, page indicators, content positioning and padding, and action-button appearance.
- Added `FoundationOnboardingPageContext` with page position, page count, selection state, resolved theme, and foreground colors for page-specific layout and animation.
- Exposed the original onboarding layout as `FoundationOnboardingStandardPage` so apps can mix standard and custom pages.
- Added flexible onboarding documentation, compatibility tests, and Demo previews.
- Added `AppAIProviderConfigurationDraft` for normalized provider credentials, dirty-state tracking, save eligibility, and discarding unsaved edits.

### Changed

- Updated `ProPaywallView` to show the yearly savings percentage whenever monthly and yearly plans are both available.
- Preserved explicitly configured savings-percentage badges and replaced `BEST VALUE` when the same plan already shows savings.
- Standardized `ProPaywallView` plan options on the vertical stacked layout and shortened the lifetime subtitle to `Pay once`.
- Simplified the AI Providers overview to a default-provider picker and compact provider-status list while making the selected default provider visually explicit.
- Enhanced `AppAIBackendStatusRow` with provider symbols, subtitles, visible default-provider state, connected status, and optional custom status text.
- Rebuilt direct-provider setup around editable API-key and model-ID fields, reveal, paste and clear actions, recommended-model guidance, model browsing, primary saving, secondary connection testing, removal confirmation, and unsaved-change feedback.
- Updated the Demo provider flow with save-or-discard navigation protection plus searchable model browsing and a selected-model checkmark.

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

- Added `AppAIClient` and the shared managed-AI request, response, error, status, attestation, receipt, idempotency, and retry contracts.
- Added managed AI provider configuration, endpoint resolution, status refresh, usage reporting, and signed-transaction synchronization.
- Added direct-provider support for OpenRouter, OpenAI, Anthropic, Gemini, DeepSeek, and NVIDIA Build.
- Added Keychain credential storage and provider/model preferences.
- Added AI provider settings components, model discovery, provider connection testing, and direct request/response models.
- Added App Attest and DeviceCheck adapters for managed requests.
- Added backend selection and routing through `AppAIBackendManager`.
- Added AppFoundation Demo screens for managed and direct AI configuration.
- Added AI backend and request-contract tests.

### Changed

- Expanded the Demo home screen with AI provider examples and status surfaces.

## 0.1.6 - 2026-07-22

### Added

- Added `ClaudePaywallView` as a focused, production-ready paywall style.
- Added configurable feature rows, legal links, trial messaging, restore handling, and loading states.
- Added `ProPaywallView` with compact plan selection and optional savings badges.
- Added paywall previews and Demo integration.

### Changed

- Refined shared subscription presentation and purchase-state handling.

## 0.1.5 - 2026-07-21

### Added

- Added `AppFoundationScreenshotStudio` for building, previewing, and exporting App Store screenshot sets.
- Added screenshot templates, device frames, text styling, gradients, and export layouts.
- Added a reusable Demo editor for Screenshot Studio.

## 0.1.4 - 2026-07-20

### Added

- Added `AppFoundationPromoVideoStudio` for composing short promotional videos from registered screenshots and videos.
- Added story templates, scene timing, transitions, captions, and export configuration.
- Added Demo preview and export flows.

## 0.1.3 - 2026-07-19

### Added

- Added shared StoreKit purchase management and subscription entitlement helpers.
- Added reusable purchase, restore, loading, and error presentation state.

## 0.1.2 - 2026-07-18

### Added

- Added AppFoundation onboarding views, page models, completion handling, and Demo integration.
- Added theme-aware onboarding presentation and standard icon-and-copy pages.

## 0.1.1 - 2026-07-17

### Added

- Added shared theme models, color resolution, gradients, backgrounds, and theme management.
- Added reusable themed surfaces for AppFoundation UI.

## 0.1.0 - 2026-07-16

### Added

- Initial AppFoundation package structure and Demo application.
