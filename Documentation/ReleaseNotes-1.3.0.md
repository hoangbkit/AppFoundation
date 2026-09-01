# AppFoundation 1.3.0

Startup resilience and reusable developer tooling for apps that should keep launching reliably and remain easy to test across a portfolio.

## Highlights

### Startup resilience

- Added `StartupResilience` for ordered best-effort startup across independent app-owned components.
- Added `StartupComponent` criticality: required, important, and optional.
- Added automatic load → repair → retry → fallback execution.
- Added degraded-but-ready results so noncritical failures do not have to brick the app.
- Added structured per-component diagnostics and progress reporting.
- Added `StartupRecoveryView` as a last-resort full-screen safety net with retry, optional recovery-copy export, and optional destructive start-fresh flow.
- Added a Demo simulator for healthy, auto-repaired, safe-fallback, and fatal startup scenarios.

### Developer tools

- Added Debug-only `FoundationDeveloperView` with common app metadata, purchase state, loaded product prices, diagnostics, and startup-recovery preview.
- Added Live StoreKit / Simulated switching, direct simulated entitlement selection, simulator reset, forced entitlement refresh, and forced product reload.
- Added a reusable simulated plan editor for product ordering, enablement, Pro entitlement mapping, preferred plan, metadata, display/numeric prices, and daily/weekly/monthly/yearly/lifetime periods.
- Added purchase outcome simulation for success, pending, cancellation, network failure, unavailable product, and system failure.
- Added product-catalog failure, restore failure, and simulated StoreKit latency controls.
- Added `FoundationDeveloperReplay` so apps can replay their real paywall, upsell, onboarding, celebration, or other product flows without AppFoundation reimplementing them.
- Added structured app extension points through `FoundationDeveloperSection`, `FoundationDeveloperAction`, `FoundationDeveloperToggle`, `FoundationDeveloperValue`, and `FoundationDeveloperDestination`.
- Expanded the Debug purchase API so custom developer tools and tests can configure the simulated catalog, entitlement, purchase results, product loading failures, restore failures, latency, and reset behavior.
- Wired the Demo Settings screen to the reusable developer view while retaining the existing Demo debug-purchase controls.

## Design boundaries

Startup resilience does not own app databases, schema migrations, repair algorithms, quarantine locations, or reset policy. Apps provide those operations; AppFoundation only coordinates them and presents the rare fatal-recovery experience.

Developer Tools always owns the common AppFoundation baseline. Apps register their real production flows and app-specific state/actions instead of duplicating the common developer UI.

All developer-tool UI and mutation APIs are Debug-only. Editing simulated prices never changes App Store Connect pricing, and switching back to Live StoreKit restores the app's original production purchase configuration.

Existing startup and purchase behavior does not change automatically. Adoption is source-compatible with existing AppFoundation clients.

## Recommended adoption

For startup resilience, start with derived caches, indexes, and independent secondary stores. Make a component non-required only when the app is genuinely safe without it. For user-owned data, preserve or quarantine the original before an app-owned fallback replaces the live store.

For Developer Tools, add one Debug-only Settings row that presents `FoundationDeveloperView(purchaseManager:configuration:)`. Let the built-in sections handle routine purchase testing and register only the app-specific replay flows, reset hooks, diagnostics, and deeper tools.

Use `StartupRecoveryView` only after an essential `required` component has exhausted every configured safe recovery path.

## Validation before tagging

- `swift test`
- `make validate`
- `cd Examples/Demo && make test` on Xcode 26
- Manually exercise all four Startup Resilience Demo scenarios and recovery-copy sharing
- Manually exercise Live/Simulated switching, entitlement forcing, simulated plan edits, all purchase failure presets, restore/catalog failure, and latency controls
- Replay Demo paywall, upsell, onboarding, and Pro celebration from Developer Tools
- Verify app-specific registered Developer items and Startup Resilience destination

This file is release-note copy prepared for the next minor release; the feature PR does not create the tag or publish the release.
