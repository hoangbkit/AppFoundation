# AppFoundation 1.4.0

AppFoundation 1.4.0 helps apps launch more reliably, centralizes reusable Debug tooling, and refreshes the Pro purchase experience while preserving existing integrations.

## Highlights

### Resilient startup

- Added `StartupResilience` for ordered startup across independent app-owned components.
- Added required, important, and optional component criticality.
- Added automatic load → repair → retry → fallback execution with structured diagnostics and progress reporting.
- Added degraded-but-ready results so a safe noncritical failure does not have to prevent launch.
- Added `StartupRecoveryView` as a last-resort retry experience with optional recovery-copy export and an optional confirmed start-fresh action.
- Added documentation, portable policy tests, and Demo scenarios for healthy, auto-repaired, safe-fallback, and fatal startup outcomes.

Apps continue to own their storage, migrations, repair and quarantine logic, fallback policy, and destructive reset behavior. AppFoundation coordinates only the operations explicitly provided by the app.

### Reusable Developer Tools

- Added Debug-only `FoundationDeveloperView` with app/runtime information, purchase state, loaded products and prices, diagnostics, and startup-recovery preview.
- Added Live StoreKit and Simulated switching, direct Free/Pro entitlement selection, editable simulated plans, configurable purchase outcomes, product-load and restore failures, latency controls, reset actions, entitlement refresh, and product reload.
- Added `FoundationDeveloperReplay` for replaying real app paywalls, upsells, onboarding, celebrations, and other production flows.
- Added `FoundationDeveloperSection` and reusable value, toggle, destination, and action items for app-specific extensions.
- Kept the editable simulated catalog separate from the live `PurchaseConfiguration`, so returning to Live StoreKit restores the production product identifiers and entitlement policy.
- Simplified the Demo around one shared Developer Tools entry instead of app-specific duplicate simulator state.

All developer-tool UI and purchase mutation APIs are compiled only in Debug builds. Simulated products and prices never change App Store Connect configuration.

### Refreshed Pro surfaces

- Made `ProPaywallView` the canonical AppFoundation paywall.
- Flattened the paywall presentation into the active themed surface and moved Restore Purchases into the legal footer with inline progress and result feedback.
- Redesigned `ProPlanSettingsSection` with a clearer two-line current-plan identity and compact horizontal actions.
- Added Settings actions for plan comparison and code redemption alongside restore, upgrade, and subscription management.
- Added `ProPlansComparisonView` for a dedicated Free-versus-Pro comparison that can continue into the app's existing paywall flow.

## Backward compatibility

This release requires no mandatory source migration:

- Startup resilience is opt-in; existing startup behavior is unchanged until an app adopts it.
- `PaywallView` and `FoundationPaywallView` remain public and source-compatible. They are deprecated to guide new integrations toward `ProPaywallView`.
- The `ProPlanSettingsConfiguration` initializer remains source-compatible, and new comparison and redemption options have defaults. Its refreshed plan identity no longer shows the old `currentPlanLabel`; active plan copy is derived from the StoreKit plan duration.
- Core StoreKit behavior is unchanged by Developer Tools; the expanded mutation controls are Debug-only.

Apps already using `ProPlanSettingsSection` will receive its refreshed presentation automatically. Use `ProPaywallView` for new paywall integrations, and migrate deprecated paywall views when convenient.

## Recommended adoption

1. Introduce `StartupResilience` first for rebuildable caches, indexes, and independent secondary stores. Mark a component non-required only when the app can genuinely launch safely without it.
2. Add one Debug-only Settings destination for `FoundationDeveloperView`, then register the app's real production flows through `FoundationDeveloperReplay`.
3. Use `ProPaywallView` as the primary paywall and connect `ProPlanSettingsSection` to the same upgrade presentation.
4. Present `StartupRecoveryView` only after a required component has exhausted every app-provided safe recovery path.

## Validation

- Portable package tests cover startup policies and Debug purchase simulation.
- The Demo includes deterministic startup-recovery scenarios and reusable Developer Tools integrations.
- Legacy paywall types remain available to protect existing clients from a forced migration.
