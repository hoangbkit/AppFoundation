# Architecture

## Entitlements

`PurchaseController` is the UI-facing purchase state owner. It never persists a trusted `isPro` Boolean. Instead it asks `PurchaseServing` for current verified transactions, normalizes them into `EntitlementRecord` values, and keeps live `EntitlementState` separate from binary app-facing `PurchaseAccessState`.

Live verified StoreKit remains authoritative. When the app opts into verified offline entitlements, the package may persist account-scoped verified entitlement evidence—not a Boolean—to preserve only access that can still be justified safely while StoreKit is temporarily unavailable. Normal feature gates should read `hasPro`.

## Theme boundary

The theme system is deliberately split into two layers.

### Portable layer

`AppTheme`, `ThemeAppearance`, `ThemeCatalog`, `ThemeStoredState`, and `ThemeResolver` use Foundation-only value types. They can be shared with widgets and tested without SwiftUI.

`ThemeResolver` is the source of truth for deciding which appearance should render:

1. An active Pro preview wins for a free user without replacing the base theme.
2. Startup and widgets restore `committedThemeID`, the last applied base theme.
3. A newly resolved access result applies the remembered `selectedThemeID` when allowed, or commits the Free fallback when the preference requires unavailable Pro access.

Preserving the selected Pro ID lets the app restore the user's preferred appearance when Pro becomes active again.

### App layer

`ThemeManager` is an observable main-actor owner for SwiftUI apps. It persists selection, starts and expires previews, synchronizes verified Pro state, and emits state-change callbacks for widgets or app icons.

The manager consumes verified access supplied by the app. `ThemeManager.bind(to:)` subscribes to the purchase owner's effective access. Each resolved result commits the base, access presentation flag, and any preview promotion synchronously before entitlement refresh returns. The purchase-aware SwiftUI modifier establishes this lifetime binding and renders only the manager's effective theme, as the picker does. Theme state never authorizes premium features itself.

While checking, the committed base and any valid preview remain visible. The Pro picker is temporarily disabled, and programmatic Pro selections return `requiresPro` without changing state; callers may retry after checking resolves. Free selections remain available and replace the remembered preference.

See [Theme resolution cases](ThemeResolution.md) for launch, selection, preview, migration, and ownership behavior.

## Default catalog

`FoundationThemes` contains six polished semantic palettes inspired by MiLove. The values are reusable, but the package does not include app-specific artwork, hearts, fonts, layouts, or icon assets.

`ThemeCatalog` is immutable and composable. Apps create their own catalog by excluding defaults, replacing definitions with the same stable ID, changing access, and adding custom values.

The fallback is normalized to free access. This guarantees a renderable theme when the user does not have Pro.

## Persistence and extensions

`UserDefaultsThemeStateStore` writes one Codable state object. Supplying an app-group suite makes the same state available to widgets.

`selectedThemeID` remains the source-compatible user preference. `committedThemeID` is the saved base appearance, and preview fields are a temporary override. Older JSON without a committed base is migrated from the old selection and access presentation flag. The cached `lastKnownHasPro` flag is retained for compatibility, preview presentation, and migration; it must not override an existing committed Free base merely because the preference is Pro. Purchase authorization remains owned by `PurchaseManager.hasPro`.

Use one theme manager per storage key. Widgets should resolve snapshots without writing them. `refreshFromPersistence()` reads shared preference/preview state without writing an old access snapshot back to disk.

## Dependency injection

Production purchases can use:

```swift
PurchaseController(configuration: configuration)
```

Tests can inject any `PurchaseServing` implementation.

Themes can inject any `ThemeStateStoring` implementation and a deterministic clock into `ThemeManager`, allowing preview and expiry behavior to be tested without real UserDefaults or wall-clock delays.

## Lifecycle

Attach `.managesPurchases(controller)` near the app root and use `.appFoundationTheme(themeManager, purchaseManager: controller)` when the catalog contains Pro themes. Apps may instead call `themeManager.bind(to: controller)` when constructing their owners, then use the plain theme modifier. The binding uses effective `hasPro`, including verified offline access when raw StoreKit state is inactive. It survives unmounting themed content; dead theme owners are weakly held and discarded. The Boolean-only `.synchronizesThemeAccess(...)` overload remains available for apps that already have a resolved access value.

When a theme preview is active, the manager schedules local expiry. Apps should also call `refresh()` after lifecycle transitions when they manage the lifecycle manually. Widgets use `ThemeResolution.nextAutomaticChangeDate` to schedule their own fallback timeline entry.

## UI composition

The package provides a default `ThemePickerView`, `AppThemeBackground`, `AppThemeCard`, SwiftUI environment injection, and bridges to the older `FoundationTheme` primitives.

Apps may use these defaults or supply custom theme previews and complete custom screens. Shared code owns theme mechanics; app targets own product identity and visual storytelling.
