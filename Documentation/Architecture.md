# Architecture

## Entitlements

`PurchaseController` is the UI-facing purchase state owner. It never persists a trusted `isPro` Boolean. Instead it asks `PurchaseServing` for current verified transactions and passes normalized `EntitlementRecord` values into the pure `EntitlementEvaluator`.

This separation keeps StoreKit-specific types inside `LiveStoreKitService`, entitlement rules deterministic, and SwiftUI purchase state compact.

## Theme boundary

The theme system is deliberately split into two layers.

### Portable layer

`AppTheme`, `ThemeAppearance`, `ThemeCatalog`, `ThemeStoredState`, and `ThemeResolver` use Foundation-only value types. They can be shared with widgets and tested without SwiftUI.

`ThemeResolver` is the source of truth for deciding which appearance should render:

1. An active Pro preview wins for a free user.
2. A selected free theme or any selected theme for a Pro user renders normally.
3. A selected Pro theme for a free user remains selected but the catalog fallback renders.

Preserving the selected Pro ID lets the app restore the user's preferred appearance when Pro becomes active again.

### App layer

`ThemeManager` is an observable main-actor owner for SwiftUI apps. It persists selection, starts and expires previews, synchronizes verified Pro state, and emits state-change callbacks for widgets or app icons.

The manager consumes a Boolean supplied by the app. It does not import StoreKit or authorize premium features itself.

## Default catalog

`FoundationThemes` contains six polished semantic palettes inspired by MiLove. The values are reusable, but the package does not include app-specific artwork, hearts, fonts, layouts, or icon assets.

`ThemeCatalog` is immutable and composable. Apps create their own catalog by excluding defaults, replacing definitions with the same stable ID, changing access, and adding custom values.

The fallback is normalized to free access. This guarantees a renderable theme when the user does not have Pro.

## Persistence and extensions

`UserDefaultsThemeStateStore` writes one Codable state object. Supplying an app-group suite makes the same state available to widgets.

The cached `lastKnownHasPro` flag is for extension presentation only. Purchase authorization remains owned by verified StoreKit state in the containing app.

## Dependency injection

Production purchases can use:

```swift
PurchaseController(configuration: configuration)
```

Tests can inject any `PurchaseServing` implementation.

Themes can inject any `ThemeStateStoring` implementation and a deterministic clock into `ThemeManager`, allowing preview and expiry behavior to be tested without real UserDefaults or wall-clock delays.

## Lifecycle

Attach `.managesPurchases(controller)` near the app root. Attach `.synchronizesThemeAccess(themeManager, hasPro: controller.isEntitled)` beside it.

When a theme preview is active, the manager schedules local expiry. Apps should also call `refresh()` after lifecycle transitions when they manage the lifecycle manually. Widgets use `ThemeResolution.nextAutomaticChangeDate` to schedule their own fallback timeline entry.

## UI composition

The package provides a default `ThemePickerView`, `AppThemeBackground`, `AppThemeCard`, SwiftUI environment injection, and bridges to the older `FoundationTheme` primitives.

Apps may use these defaults or supply custom theme previews and complete custom screens. Shared code owns theme mechanics; app targets own product identity and visual storytelling.
