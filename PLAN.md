# AppFoundation Development Plan

## Implementation status

Phases 1–5 were implemented on `develop` on July 21, 2026. Phase 6 adds reusable startup resilience without moving app-owned persistence or migration policy into the package.

Apple-platform-only UI, StoreKit, WidgetKit, and UserNotifications code still requires the normal Xcode 26 build and simulator/device validation before a tagged release.

## Purpose

AppFoundation is the shared production infrastructure for Hoang's iOS apps. It should remove repeated engineering work without forcing MiLove, Milesto, ShotVault, Altself, AppReel, MyApps, Onlink, Spokio, or future apps to share the same product design, navigation, or domain models.

A feature belongs here when it is useful in at least two real apps, remains app-neutral, has a stable public API, and can be tested independently.

## Package boundary

AppFoundation should own:

- StoreKit purchases, entitlement state, paywalls, and feature gating
- Shared export and temporary-file infrastructure
- Versioned backup package reading and writing
- App Group snapshot storage and widget reload helpers
- Local notification permission and scheduling helpers
- Small production utilities such as app metadata, safe file replacement, review policy, logging, haptics, and async controls
- Reusable startup resilience orchestration and last-resort recovery presentation
- Focused tests and adoption documentation

AppFoundation should not own:

- MiLove relationship, event, suggestion, or hero-card designs
- Milesto countdown models or event rules
- ShotVault Photos scanning, classification, or deletion workflows
- Altself card formats, wallet behavior, profiles, or card layouts
- AppReel editing, templates, timelines, or video rendering
- MyApps project or note schemas
- Onlink network probes or Spokio-specific logic
- App-specific database schemas, migrations, repair algorithms, or destructive-reset policy
- A mandatory cross-app visual design system

The existing reusable theme module remains supported, but AppFoundation should not grow into a universal UI framework.

---

# Phase 1 — Commerce foundation

## Goal

Make purchases the strongest and simplest public capability.

## Deliverables

- Introduce `PurchaseManager` as the preferred app-facing name while preserving `PurchaseController` compatibility.
- Expose `hasPro` as the normal entitlement check.
- Preserve live StoreKit verification, transaction updates, product retry, restore, and Debug-only simulation.
- Add `PremiumFeature`, `PremiumAccessPolicy`, and access decisions that keep existing user content accessible after expiry.
- Add the primary theme-aware `PaywallView` for weekly, monthly, yearly, and lifetime plans.
- Keep `FoundationPaywallView` and `ProPaywallView` compatible while presenting the same complete product catalog.
- Add normalized recurring/lifetime plan metadata and accurate mixed-catalog legal disclosure.
- Add reusable `PremiumGate`, `PremiumBadge`, `PremiumButton`, `LockedFeatureOverlay`, and `SubscriptionSettingsSection` components.
- Keep localized prices and product ordering app-configured.
- Keep app names, legal URLs, feature copy, highlighted plan, and tint app-owned.

## Completion criteria

A consumer app can integrate subscription or lifetime monetization using `PurchaseManager`, `hasPro`, `PaywallView`, and the feature-gating components without writing another StoreKit manager.

---

# Phase 2 — ExportKit

## Goal

Centralize reliable image/data export used by MiLove, Altself, AppReel, ShotVault, and future apps.

## Deliverables

- Safe filename and file-extension normalization
- Atomic temporary-file creation and cleanup
- PNG and JPEG output definitions
- SwiftUI view-to-image rendering at exact dimensions and scale
- Transparent PNG, rounded output, and JPEG quality support
- Pixel-count preflight to avoid excessive render allocations
- Predictable suggested filenames
- Reusable file share sheet
- Neutral errors for rendering, encoding, validation, and file writes

App-specific artwork and layout remain in each app.

---

# Phase 3 — BackupKit

## Goal

Provide versioned, validated backup packages while keeping every app responsible for its own payload schema and restore policy.

## Deliverables

- Generic `BackupEnvelope<Payload>`
- Manifest with format, version, app identifier, app version/build, creation date, checksum, metadata, and asset paths
- Folder-based custom backup packages with payload and optional assets
- Atomic staging and move into the final package
- Checksum validation and corrupt-payload rejection
- Unsupported-version and cross-app rejection
- Extension, duplicate-path, missing-asset, and path-traversal validation
- Security-scoped URL helpers for Files imports
- Generic reader and writer actors

Each app still owns its custom extension, migrations, duplicate handling, replace/merge behavior, and restore confirmation UI.

---

# Phase 4 — Widget and notification support

## Goal

Remove repeated low-level App Group and notification plumbing without moving app-specific timeline or reminder logic into the package.

## Deliverables

- Typed Codable App Group snapshots
- Schema version and last-updated metadata
- Shared deep-link construction
- Widget reload throttling
- Widget-kind and reload-all helpers
- Notification authorization status and permission request
- Stable notification identifiers supplied by apps
- Schedule, replace, cancel, and cancel-all operations
- Calendar-based notification triggers

Apps remain responsible for deciding what a widget shows and when a reminder is useful.

---

# Phase 5 — Shared utilities, tests, and release discipline

## Goal

Finish the package with small production utilities and clear adoption guidance.

## Deliverables

- `UserFacingError`
- `AppInfo`
- Atomic safe file replacement
- Async debouncing
- App Store review-request policy
- Structured logging helper
- Haptic helper
- Reusable `AsyncButton`
- Portable tests covering access policy, plan metadata, lifetime entitlements, export filenames and preflight, backup round trips and validation, deep links, and review policy
- README integration examples and migration guidance
- Changelog updates
- GitHub Actions Swift package validation

---

# Phase 6 — Startup resilience

## Goal

Help apps launch into a safe usable state whenever possible, preserve user data before fallback, and reserve full-screen recovery UI for failures that cannot be handled safely in the background.

## Phase 6.1 — Neutral orchestration model

- Add app-neutral startup component descriptors with `required`, `important`, and `optional` criticality.
- Add ordered startup execution with observable progress and structured outcomes.
- Let each app supply its own async load, migration, repair, quarantine, and fallback closures.
- Keep the package unaware of database schemas, filenames, model types, and migration versions.
- Treat successful fallback as a degraded-but-ready launch rather than a fatal startup failure.

## Phase 6.2 — Best-effort recovery policy

- Support an initial operation, optional automatic repair, and optional fallback for each component.
- Preserve the original failure and recovery diagnostics for logs or app-owned telemetry.
- Never require destructive deletion as an automatic recovery strategy.
- Make `required` components fail startup only after configured recovery paths are exhausted.
- Allow `important` and `optional` components to continue startup after safe fallback.
- Expose a concise degraded-startup report so apps may silently log, show a nonblocking notice, or ignore recovered failures.

## Phase 6.3 — Last-resort recovery UI

- Add `StartupRecoveryView` as an intentionally rare safety net.
- Lead with user-readable copy, a clear data-safety message, and a primary retry action.
- Support optional recovery-copy and start-fresh actions with progressive disclosure.
- Keep technical diagnostics out of the primary experience.
- Keep branding, exact copy, storage behavior, and destructive-reset implementation app-owned.
- Handle async busy state, recovery-action errors, destructive confirmation, Dynamic Type, and VoiceOver in the shared view.

## Phase 6.4 — Adoption, Demo, tests, and release readiness

- Add portable tests for ordering, criticality, repair, fallback, degraded readiness, and fatal exhaustion.
- Add a Demo feature that can simulate normal, auto-repaired, degraded, and fatal startup outcomes.
- Document recommended recovery policy and anti-patterns.
- Update README and changelog.
- Prepare the next minor release notes without changing or tagging the release version in this feature PR.

## Completion criteria

An app can register independent startup components and get consistent best-effort startup behavior without exposing its persistence model to AppFoundation. Recoverable failures do not block launch; only an exhausted required component reaches `StartupRecoveryView`.

## Release rules

- Keep semantic versioning and migration notes.
- Pin stable AppFoundation versions in released apps instead of tracking `develop`.
- Add a shared feature only when its API is stable enough for multiple apps.
- Prefer small neutral components over mandatory all-in-one screens.
- Startup resilience must preserve user-owned data by default and must not silently convert corruption into destructive reset.
