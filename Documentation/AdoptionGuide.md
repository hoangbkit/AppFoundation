# Adoption guide

## Recommended boundary

Keep app navigation, feature screens, onboarding, data models, branded artwork, and custom layouts inside each app target.

Use AppFoundation for infrastructure whose behavior should remain consistent across the portfolio:

- purchases and entitlement evaluation
- theme selection, persistence, Pro access, and timed previews
- neutral reusable UI primitives

## StoreKit setup

Create a `PurchaseConfiguration` per app. Product order is preserved and controls paywall order. The optional preferred product becomes the initial paywall selection.

Call `prepare()` through `.managesPurchases` or manually from the app lifecycle. Read `entitlementState.isActive` or `isEntitled` wherever premium access is required.

## Theme setup

Start from the default catalog and customize it in the app:

```swift
let catalog = ThemeCatalog.foundationDefaults
    .excluding(ids: ["champagne"])
    .replacing(FoundationThemes.paper.withAccess(.free))
    .appending(MyThemes.graphite)
```

The catalog fallback is always treated as free. Keep IDs stable after release because persisted selections and widget state use those IDs.

Create one `ThemeManager` near the app root and synchronize it with verified purchase state:

```swift
@State private var themes = ThemeManager(
    catalog: catalog,
    stateStore: UserDefaultsThemeStateStore(
        storageKey: "com.example.app.theme-state",
        suiteName: "group.com.example.app"
    )
)

RootView()
    .environment(themes)
    .appFoundationTheme(themes)
    .synchronizesThemeAccess(themes, hasPro: purchases.isEntitled)
```

The default `.miLoveStyle` preview behavior gives free users five minutes to try Pro themes. Use `.disabled` when tapping a Pro theme should open the paywall immediately.

## Theme customization

Default themes provide semantic colors and gradients, not app-specific decoration. Keep these in the app:

- background artwork and patterns
- branded typography
- app-specific card layouts
- widget composition
- alternate icon assets
- per-feature visuals

Use the default `ThemePickerView` for fast adoption, or supply a custom preview closure while preserving the manager's access and preview behavior.

## Widgets

Use `UserDefaultsThemeStateStore` with an app-group suite. Widgets should call `ThemeResolver.resolve` using the same catalog.

`ThemeResolution.nextAutomaticChangeDate` is the premium-preview expiry. Add a widget timeline entry for that date so the widget returns to the fallback theme even if the app is closed.

`lastKnownHasPro` exists only for consistent rendering in extensions. Never use it as a trusted entitlement source.

## App icons

Set `alternateIconName` only for themes whose icon assets are present in the app target. AppFoundation supplies `ThemeAppIconManager`, but the app decides when icon changes occur and handles errors in its own UI.

## Onboarding

Onboarding remains app-owned. It is usually too specific to permissions, profile setup, initial data entry, branding, and product flow to belong in shared infrastructure.

## Settings

Apps may embed `ThemePickerView` in their settings screen or create a completely custom theme section. The manager and catalog do not require the package's settings view.
