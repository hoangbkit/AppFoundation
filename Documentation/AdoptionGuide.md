# Adoption guide

## Recommended boundary

Keep app navigation, feature screens, onboarding, data models, branded artwork, and custom layouts inside each app target.

Use AppFoundation for infrastructure whose behavior should remain consistent across the portfolio:

- purchases and entitlement evaluation
- theme selection, persistence, Pro access, and timed previews
- neutral reusable UI primitives

## StoreKit setup

Create a `PurchaseConfiguration` per app. Product order is preserved and controls paywall order. The optional preferred product becomes the initial paywall selection.

Recurring products use their StoreKit subscription period, including weekly, monthly, and yearly durations. A configured entitlement product without a subscription period is presented as lifetime access; in App Store Connect this should normally be a non-consumable in-app purchase.

All configured products belong in `productIDs`, and all should remain in `entitledProductIDs` unless an app intentionally sells a product that does not unlock Pro:

```swift
let purchases = PurchaseConfiguration(
    productIDs: [
        "com.example.app.pro.weekly",
        "com.example.app.pro.monthly",
        "com.example.app.pro.yearly",
        "com.example.app.pro.lifetime",
    ],
    preferredProductID: "com.example.app.pro.yearly"
)
```

Call `prepare()` through `.managesPurchases` or manually from the app lifecycle. Read `hasPro`, `entitlementState.isActive`, or `isEntitled` wherever premium access is required.

Lifetime does not require a separate entitlement flag. StoreKit returns the verified non-consumable in `Transaction.currentEntitlements` without an expiration date, and the existing evaluator keeps that entitlement active unless it is revoked.

Use `StoreProduct.planKind`, `planLabel`, `billingDescription`, `isRecurring`, and `isLifetime` when building app-owned purchase UI. Use `PurchasePlanDisclosure.text(for:)` instead of showing subscription-renewal wording for lifetime-only catalogs.

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
    .synchronizesThemeAccess(themes, hasPro: purchases.hasPro)
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

Keep alternate icon assets and their `CFBundleAlternateIcons` registration in the app target. AppFoundation supplies the reusable selection UI and performs the `UIApplication` icon change.

Register each primary or alternate icon once:

```swift
private let appIcons = [
    AppIconOption(
        title: "Default",
        alternateIconName: nil,
        previewImageName: "AppIconDefaultPreview",
        accentColor: .blue
    ),
    AppIconOption(
        title: "Midnight",
        alternateIconName: "AppIconMidnight",
        previewImageName: "AppIconMidnightPreview",
        accentColor: .indigo,
        requiresUnlock: true
    ),
]
```

Apps using `AppTheme` can instead create options with `AppIconOption(theme:)`; the initializer uses the theme's `alternateIconName`, `previewImageName`, accent color, and Pro access metadata.

Embed the ready-made section directly in a `Form`:

```swift
AppIconPickerSection(
    icons: appIcons,
    footer: "Alternate icons are included with Pro.",
    isLocked: { icon in
        icon.requiresUnlock && !purchases.hasPro
    },
    onRequestUnlock: { _ in
        isShowingPaywall = true
    }
)
```

Use `AppIconPickerView` when the surrounding app owns the `Section`. `AppIconsPickerView` and `AppIconsPickerSection` are plural-name aliases. `AppIconManager` is available for custom interfaces, while `ThemeAppIconManager` remains source compatible.

## Onboarding

Onboarding remains app-owned. It is usually too specific to permissions, profile setup, initial data entry, branding, and product flow to belong in shared infrastructure.

## Settings

Apps may embed `ThemePickerView` and `AppIconPickerSection` in their settings screen or create completely custom sections. The managers and catalogs do not require the package's settings view.
