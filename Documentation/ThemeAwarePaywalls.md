# Theme-aware paywalls

`ProPaywallView` is the canonical AppFoundation paywall. It follows the active `AppTheme` installed at the app root and stays consistent with the rest of the Pro view family, including `ProPlanSettingsSection`, `ProUpsellView`, `ProCelebrationView`, `ProBadgeView`, and `ProCrownIcon`.

`PaywallView` and `FoundationPaywallView` remain public for source compatibility but are deprecated. Existing apps may continue using them; new integrations should use `ProPaywallView`.

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

Present the primary paywall normally. Do not pass `ThemeManager` into the paywall.

```swift
ProPaywallView(
    purchases: purchaseManager,
    configuration: proPaywallConfiguration
)
```

The paywall reads the active theme through the SwiftUI environment. Selected themes, active Pro previews, preview expiry, foreground colors, surfaces, borders, shadows, corner radius, accent gradient, and preferred light or dark appearance update together.

## Configuration and overrides

`ProPaywallView` uses `FoundationPaywallConfiguration`. The configuration follows the active app theme when created without a theme argument:

```swift
FoundationPaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    privacyURL: privacyURL,
    termsURL: termsURL
)
```

Use `themeOverride` when one paywall presentation needs a complete `AppTheme` override:

```swift
FoundationPaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    privacyURL: privacyURL,
    termsURL: termsURL,
    themeOverride: campaignTheme
)
```

The older explicit `theme: FoundationTheme` initializer remains available for source compatibility. Passing `theme:` intentionally creates a fixed visual override and does not follow later app-theme changes.

```swift
FoundationPaywallConfiguration(
    title: "Unlock Pro",
    subtitle: "Access every feature.",
    features: features,
    privacyURL: privacyURL,
    termsURL: termsURL,
    theme: legacyTheme
)
```

Use the fixed initializer only for an app that has not adopted `ThemeManager` yet or for a deliberately static branded paywall.

## Legacy paywalls

`PaywallView` and `FoundationPaywallView` are deprecated rather than removed because AppFoundation is a public package. Their existing APIs remain intact so current clients keep compiling, while compiler deprecation messages direct new code to `ProPaywallView`.
