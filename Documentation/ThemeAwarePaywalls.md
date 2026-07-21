# Theme-aware paywalls

`PaywallView`, `FoundationPaywallView`, and `ClaudePaywallView` automatically follow the active `AppTheme` installed at the app root.

```swift
@State private var themes = ThemeManager(
    catalog: .foundationDefaults,
    stateStore: UserDefaultsThemeStateStore(
        storageKey: "com.example.app.theme-state"
    )
)

WindowGroup {
    RootView()
        .environment(purchaseManager)
        .environment(themes)
        .managesPurchases(purchaseManager)
        .appFoundationTheme(themes)
        .synchronizesThemeAccess(
            themes,
            hasPro: purchaseManager.hasPro
        )
}
```

Present a paywall normally. Do not pass `ThemeManager` into the paywall.

```swift
PaywallView(
    purchaseManager: purchaseManager,
    configuration: paywallConfiguration
)
```

The paywall reads `ThemeManager.effectiveTheme` through the SwiftUI environment. Selected themes, active Pro previews, preview expiry, foreground colors, surfaces, borders, shadows, corner radius, accent gradient, and preferred light or dark appearance update together.

## Overrides

The primary paywall can override the complete theme for one presentation:

```swift
PaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    themeOverride: campaignTheme
)
```

Use `tint` when only the accent should differ:

```swift
PaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    tint: .orange
)
```

`FoundationPaywallConfiguration` follows the active app theme when created without a theme argument:

```swift
FoundationPaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features
)
```

It also accepts a full `AppTheme` override through `themeOverride`.

The older explicit `theme: FoundationTheme` initializer remains available for source compatibility. Passing `theme:` intentionally creates a fixed visual override and does not follow later app-theme changes.

```swift
FoundationPaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    theme: legacyTheme
)
```

Use the fixed initializer only for an app that has not adopted `ThemeManager` yet or for a deliberately static branded paywall.
