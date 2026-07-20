# AppFoundation Development Plan

## Purpose

AppFoundation is the shared production infrastructure used across Hoang's iOS apps. It should remove repeated engineering work without forcing every app to share the same product design, navigation, data model, or feature behavior.

The package targets iOS 26+, Swift 6 strict concurrency, and SwiftUI. It should remain small enough to understand, safe enough to use in production, and configurable enough to support different apps.

## Core boundary

AppFoundation owns reusable infrastructure and neutral UI building blocks.

It should include:

- StoreKit 2 purchases and entitlement handling
- Debug-only simulated purchases
- Reusable paywall infrastructure
- Onboarding mechanics
- Composable settings components
- Common loading, empty, error, and confirmation UI
- Backup/import/export infrastructure
- Small production utilities such as logging, app metadata, reviews, URLs, and haptics
- Unit tests and a focused showcase app

It should not include:

- App-specific SwiftData schemas or migrations
- App-specific navigation or tab structures
- Feature limits tied to a particular product
- MiLove, ShotVault, Milesto, MyApps, AppReel, Altself, or Beforely logic
- App-specific themes, copy, illustrations, or terminology
- Widgets, App Intents, Photos workflows, media processing, timelines, notes, cards, or relationship logic
- Analytics event definitions for individual apps
- App Store metadata

## Extraction rule

A feature should move into AppFoundation only when all of these are true:

1. It is already needed by at least two real apps, or is clearly universal production infrastructure.
2. It works without importing an app's models.
3. It can be configured without large app-specific conditionals.
4. Its public API can remain stable across multiple app releases.
5. It can be tested independently from any app.

---

# Phase 1 — Public API cleanup and purchase foundation

## Goal

Make purchases the first stable, production-ready AppFoundation capability and remove package-specific naming from app-facing APIs.

## Work

### Rename and simplify the purchase API

- Rename `PurchaseController` to `PurchaseManager`.
- Expose `hasPro` as the primary app-facing entitlement property.
- Keep richer entitlement details available for diagnostics and settings UI.
- Preserve verified StoreKit transactions as the source of truth.
- Do not mirror entitlement authorization into UserDefaults.
- Keep product configuration app-owned.
- Prepare the model for monthly, yearly, and future lifetime products.

Suggested public surface:

```swift
@MainActor
@Observable
public final class PurchaseManager {
    public private(set) var products: [PurchaseProduct]
    public private(set) var state: PurchaseState
    public private(set) var entitlement: EntitlementState

    public var hasPro: Bool { get }
    public var isBusy: Bool { get }

    public func prepare() async
    public func purchase(_ product: PurchaseProduct) async
    public func restorePurchases() async -> RestoreOutcome
    public func refreshEntitlements() async
}
```

### Keep production StoreKit behavior complete

- Load products with bounded retry.
- Sort products in app-configured order.
- Verify all transactions.
- Observe `Transaction.updates`.
- Refresh entitlements when the app becomes active.
- Finish verified transactions.
- Handle cancelled, pending, failed, and successful purchases.
- Handle restore success, nothing-to-restore, and failure.
- Surface billing retry, grace period, revoked, expired, and active states for UI messaging.
- Map StoreKit failures to user-safe errors.

### Preserve simulated purchases

- Keep simulation available only in Debug builds.
- Keep the existing environment-driven mode selection.
- Preserve simulated entitlement persistence.
- Support reset, pending, cancellation, catalog failure, purchase failure, and restore failure.
- Guarantee that Release builds always use live StoreKit.
- Add tests proving simulated code cannot become the Release source of entitlement.

### Remove duplicate paywall naming

Replace names such as:

- `FoundationPaywallView`
- `FoundationPaywallConfiguration`
- `ClaudePaywallView`

with neutral public names:

- `PaywallView`
- `PaywallConfiguration`
- `PaywallFeature`
- `PaywallTheme`

Keep only one primary paywall style for now: the current compact Claude-inspired layout supporting monthly and yearly subscriptions.

### Paywall requirements

- Localized StoreKit prices
- Yearly plan selected by default when configured
- Monthly and yearly plan cards
- Feature list
- Purchase button with loading state
- Pending purchase messaging
- Product load retry
- Restore purchases
- Manage subscription action
- Privacy and terms links
- Clear error presentation
- Dynamic Type and VoiceOver support
- No hardcoded app name, product ID, or legal URL

## Tests

- Product ordering
- Entitlement evaluation
- Expired and revoked transactions
- Pending and cancelled purchases
- Restore outcomes
- Simulated purchase persistence and reset
- Release-mode service selection
- Failure mapping
- Repeated `prepare()` safety

## Completion criteria

- A real app can integrate purchases using `PurchaseManager` and `hasPro` only.
- Demo code does not need its own StoreKit manager.
- The primary paywall supports the current monthly/yearly subscription strategy.
- Package tests pass under Swift 6 strict concurrency.

---

# Phase 2 — Onboarding and settings composition

## Goal

Provide reusable mechanics for common app setup and settings without dictating app content or information architecture.

## Work

### Onboarding

Add or refine:

- `OnboardingView`
- `OnboardingPage`
- Progress indicator
- Back, next, skip, and completion actions
- Optional skip support
- Configurable button labels
- Configurable SF Symbol, image, or custom page content
- Accessible page announcements
- Reduced-motion behavior
- Preview-friendly configuration

AppFoundation owns page mechanics and presentation behavior. Each app owns titles, descriptions, artwork, page count, completion storage, and post-onboarding routing.

### Settings components

Create small composable sections rather than one mandatory settings screen:

- `SubscriptionSettingsSection`
- `SupportSettingsSection`
- `LegalSettingsSection`
- `AppInformationSection`
- `AppearanceSettingsSection` only if its behavior can remain neutral

Reusable actions and rows should include:

- Upgrade to Pro
- Current Pro status
- Restore purchases
- Manage subscription
- Contact support
- Share app
- Rate app
- Open privacy policy
- Open terms of use
- Display version and build number

### App metadata

Add a small `AppInfo` utility for:

- Display name
- Bundle identifier
- Version
- Build number
- App Store ID when supplied by the app

### Review and URL helpers

- Add an App Store review coordinator.
- Add safe URL-opening helpers.
- Avoid global singletons where dependency injection is practical.
- Return failures instead of silently ignoring invalid URLs.

## Tests

- Onboarding page progression
- Skip and completion behavior
- Settings action availability
- Version/build extraction
- URL validation
- Review request throttling logic where testable
- Accessibility identifiers for key controls

## Completion criteria

- A real app can compose a complete settings screen from reusable sections.
- Onboarding mechanics can be reused without importing app-specific content.
- No package API assumes a particular app name, support address, theme, or navigation structure.

---

# Phase 3 — Neutral UI primitives and production utilities

## Goal

Standardize common interaction quality while preserving each app's visual identity.

## Work

### Neutral UI primitives

Provide configurable components for:

- Primary and secondary buttons
- Destructive confirmation buttons
- Cards and section containers
- Pills and badges
- Loading states
- Empty states
- Error states with retry
- Confirmation sheets
- Simple reusable list rows
- Adaptive backgrounds where configuration remains app-owned

Requirements:

- No app-specific colors or branding in defaults
- Supports light and dark mode
- Supports Dynamic Type
- Supports VoiceOver and button traits
- Avoids fixed heights that break localization
- Allows each app to inject its own theme or styling values

### User-facing errors

Create a small common error representation:

```swift
public struct UserFacingError: Error, Equatable, Sendable {
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
}
```

Use it only where a neutral representation is useful. Do not erase useful domain errors internally.

### Logging

Add a structured logger helper that:

- Uses the app bundle identifier as subsystem
- Supports stable categories
- Avoids logging private user data by default
- Works cleanly under Swift concurrency

### Haptics and task state

- Add a small haptic service.
- Add reusable loading/activity state only when it reduces duplicated state machines.
- Avoid a large dependency-injection framework.

## Tests

- UI state configuration
- Accessibility labels and identifiers
- Error conversion behavior
- Logger category construction
- Sendable and concurrency checks

## Completion criteria

- Common screens no longer reimplement loading, empty, and error presentation.
- Apps can keep distinct design systems.
- The package remains lightweight and does not become a universal UI framework.

---

# Phase 4 — Backup, export, and restore infrastructure

## Goal

Provide reliable shared file infrastructure while leaving each app responsible for its own data format and restore rules.

## Work

### Versioned backup envelope

Add a generic, Codable backup envelope containing:

- Format identifier
- Format version
- App bundle identifier
- App version/build
- Creation date
- Payload
- Optional metadata
- Optional checksum

Example direction:

```swift
public struct BackupEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let format: String
    public let version: Int
    public let appIdentifier: String
    public let createdAt: Date
    public let payload: Payload
}
```

### File operations

Provide:

- Atomic writes
- Temporary-file cleanup
- Security-scoped URL handling
- File import reading
- Optional checksum generation and validation
- Common import/export errors
- Share/export presentation helpers

### Explicit app responsibilities

Each app must still define:

- Payload schema
- Custom file extension and UTType
- Format identifier
- Supported versions
- Migration strategy
- Duplicate handling
- Replace, merge, or cancel behavior
- Validation rules
- User confirmation and restore UI

AppFoundation must not define `.milove`, `.myapps`, or any other app-specific file type.

## Tests

- Encode/decode round trips
- Unsupported format version
- Corrupted payload
- Checksum mismatch
- Atomic replacement
- Temporary-file cleanup
- Cross-app identifier rejection when configured

## Completion criteria

- Apps can implement backup and restore without rebuilding low-level file handling.
- Restore remains predictable and app-controlled.
- A malformed or incompatible backup fails safely without mutating app data.

---

# Phase 5 — Showcase, documentation, and release discipline

## Goal

Make AppFoundation easy to validate, adopt, and update across many apps.

## Work

### Rename the example

Rename:

```text
Examples/Demo
```

to:

```text
Examples/Showcase
```

The Showcase exists only to exercise AppFoundation's public APIs. It should not become the canonical app starter.

It should demonstrate:

- Live and simulated purchase modes
- Paywall states
- Onboarding variants
- Settings sections
- Loading, empty, and error components
- Backup envelope round trip
- Debug reset controls

### Documentation

Update the README with:

- Installation
- Minimum requirements
- Purchase setup
- Debug simulation
- Paywall setup
- Onboarding setup
- Settings composition
- Backup infrastructure
- Production checklist
- Migration notes for public API changes

Add focused documentation files when useful:

```text
Docs/Purchases.md
Docs/Onboarding.md
Docs/Settings.md
Docs/Backup.md
Docs/Migration.md
```

### Versioning

- Use semantic versioning.
- Tag stable releases.
- Keep a changelog.
- Avoid breaking public API changes without migration notes.
- Pin AppFoundation versions in released apps rather than tracking an unstable branch.

### Validation

Maintain commands for:

- `swift test`
- Swift format/lint if adopted
- Showcase generation
- Simulator build
- Release configuration build
- Package privacy-manifest validation

### Adoption test

Before declaring 1.0, integrate the package into at least two real apps and confirm:

- Purchases work in TestFlight.
- Restore and entitlement refresh work after expiration or account changes.
- Onboarding and settings remain app-configurable.
- Updating the package does not force unrelated design changes.
- Release builds cannot use simulated purchases.

## Completion criteria

- `AppFoundation` has a stable 1.0 public API.
- `Examples/Showcase` validates the package without duplicating the separate Demo starter repository.
- At least two real apps use the same package release successfully.
- Documentation is sufficient to integrate the package without reading its internal implementation.

---

# Recommended implementation order

1. Finish AppFoundation Phase 1 before modernizing the separate Demo repository.
2. Update Demo to consume the new purchase API.
3. Build AppFoundation Phase 2 and adopt it in Demo.
4. Add UI primitives only after repeated patterns are confirmed.
5. Add backup infrastructure after one or two app-specific backup formats are proven.
6. Stabilize and tag AppFoundation 1.0 only after real TestFlight adoption.

# Definition of done for AppFoundation 1.0

AppFoundation 1.0 is ready when:

- Purchase logic has one production source of truth.
- `PurchaseManager.hasPro` is safe to use for feature authorization.
- Monthly and yearly subscriptions work in live, StoreKit configuration, and simulated Debug modes.
- Restore, pending, expiry, billing retry, revocation, and foreground refresh are covered.
- Onboarding and settings APIs are composable and app-neutral.
- Shared UI primitives are accessible and themeable.
- Backup infrastructure fails safely.
- Release builds cannot activate simulated purchases.
- The package has tests, documentation, a changelog, and a focused Showcase.
- At least two real apps have shipped or completed TestFlight validation using the same tagged release.
