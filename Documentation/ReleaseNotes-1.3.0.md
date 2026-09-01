# AppFoundation 1.3.0

Startup resilience for apps that should keep launching even when one piece of local state goes wrong.

## Highlights

- Added `StartupResilience` for ordered best-effort startup across independent app-owned components.
- Added `StartupComponent` criticality: required, important, and optional.
- Added automatic load → repair → retry → fallback execution.
- Added degraded-but-ready results so noncritical failures do not have to brick the app.
- Added structured per-component diagnostics and progress reporting.
- Added `StartupRecoveryView` as a last-resort full-screen safety net with retry, optional recovery-copy export, and optional destructive start-fresh flow.
- Added a Demo simulator for healthy, auto-repaired, safe-fallback, and fatal startup scenarios.

## Design boundary

AppFoundation does not own app databases, schema migrations, repair algorithms, quarantine locations, or reset policy. Apps provide those operations; AppFoundation only coordinates them and presents the rare fatal-recovery experience.

No existing startup behavior changes automatically. Adoption is opt-in and source-compatible with existing AppFoundation clients.

## Recommended adoption

Start with derived caches, indexes, and independent secondary stores. Make a component non-required only when the app is genuinely safe without it. For user-owned data, preserve or quarantine the original before an app-owned fallback replaces the live store.

Use `StartupRecoveryView` only after an essential `required` component has exhausted every configured safe recovery path.

## Validation before tagging

- `swift test`
- `make validate`
- `cd Examples/Demo && make test` on Xcode 26
- Manually exercise all four Startup Resilience Demo scenarios and recovery-copy sharing

This file is release-note copy prepared for the next minor release; the feature PR does not create the tag or publish the release.
