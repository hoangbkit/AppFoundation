# AppFoundation

A focused Swift package for shared iOS infrastructure that is expensive to get wrong in every app. It targets **iOS 26.0+** and uses **Swift 6** strict concurrency.

## Included

### Purchases

- StoreKit 2 purchase controller with verified in-memory entitlement state
- Debug-only in-process purchase simulation for CLI-deployed prototypes
- Transaction update observation and foreground refresh support
- Product loading retry, restore, pending purchase, and error states
- Pure entitlement evaluation that can be unit tested without StoreKit
- Reusable paywall mechanics and default paywall views

### Themes

- Six polished defaults: Rose, Sunset, Lavender, Midnight, Paper, and Champagne
- One free fallback theme and configurable Pro themes
- App-owned catalogs that can remove, replace, reorder, or add themes
- Persisted selection with safe fallback when a theme is removed
- MiLove-style timed Pro previews with one shared countdown session
- Optional promotion of the previewed theme after Pro is unlocked
- Selected Pro theme preservation when a subscription expires
- App-group-compatible state for widgets and extensions
- Reusable horizontal theme picker with custom preview rendering
- SwiftUI environment, background, card, and legacy `FoundationTheme` bridges
- Optional alternate app-icon helper

### Existing UI and project support

- Brandable onboarding, paywall, settings, cards, backgrounds, pills, and buttons
- XcodeGen-powered Demo app using a local StoreKit configuration
- Privacy manifest and package/app tests

## Requirements

- Xcode 26+
- Swift 6.2+
- iOS 26+
- XcodeGen 2.45.4+ for the Demo app

## Add the package

Add this repository as a Swift package, then link the `AppFoundation` product to your app target.

```swift
import AppFoundation
import SwiftUI

@main
@MainActor
struct MyApp: App {
    @State private var purchases = PurchaseController(
        configuration: PurchaseConfiguration(
            productIDs: [
                "com.example.app.pro.yearly",
                "com.example.app.pro.monthly",
            ],
            preferredProductID: "com.example.app.pro.yearly"
        )
    )

    @State private var themes = ThemeManager(
        catalog: .foundationDefaults,
        stateStore: UserDefaultsThemeStateStore(
            storageKey: "com.example.app.theme-state"
        )
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchases)
                .environment(themes)
                .managesPurchases(purchases)
                .appFoundationTheme(themes)
                .synchronizesThemeAccess(
                    themes,
                    hasPro: purchases.isEntitled
                )
        }
    }
}
```

`PurchaseController.entitlementState` is derived from verified StoreKit transactions. Do not mirror it into UserDefaults as an access-control source of truth.

The theme state stores `lastKnownHasPro` only so widgets and extensions can render consistently. It is presentation state, not trusted purchase authorization.

## Default theme catalog

`ThemeCatalog.foundationDefaults` contains:

| Theme | Default access | Appearance |
| --- | --- | --- |
| Rose | Free fallback | Dark rose |
| Sunset | Pro | Dark orange and coral |
| Lavender | Pro | Dark violet |
| Midnight | Pro | Deep indigo |
| Paper | Pro | Warm light neutral |
| Champagne | Pro | Warm light gold |

The fallback theme is always normalized to free access so an app can never lock every usable appearance behind Pro.

### Remove, replace, or add themes

```swift
let catalog = ThemeCatalog.foundationDefaults
    .excluding(ids: ["sunset", "champagne"])
    .replacing(
        FoundationThemes.paper
            .withTitle("Parchment")
            .withAccess(.free)
    )
    .appending(MyThemes.graphite)
    .withFallbackThemeID("paper")
```

A custom theme is a normal value:

```swift
let graphite = AppTheme(
    id: "graphite",
    title: "Graphite",
    symbolName: "circle.lefthalf.filled",
    access: .pro,
    appearance: ThemeAppearance(
        background: ThemeColor(hex: 0x090A0D),
        gradientStart: ThemeColor(hex: 0x30343B),
        gradientEnd: ThemeColor(hex: 0x111318),
        accent: ThemeColor(hex: 0x8EA4C7),
        primaryForeground: .white,
        secondaryForeground: .white.withAlpha(0.68),
        surface: .white.withAlpha(0.06),
        elevatedSurface: .white.withAlpha(0.10),
        border: .white.withAlpha(0.12),
        preferredColorScheme: .dark
    )
)
```

Themes are identified by stable string IDs. Adding a later definition with the same ID replaces the earlier definition without changing its catalog position.

## Theme picker

Use the polished default picker:

```swift
@Environment(ThemeManager.self) private var themes
@State private var showPaywall = false

ThemePickerView(
    manager: themes,
    onRequestUpgrade: { showPaywall = true }
)
```

The default interaction follows MiLove:

- free themes select immediately
- a free user tapping a Pro theme starts a five-minute preview
- switching between Pro themes keeps the original expiry time
- the picker shows a live countdown and End action
- unlocking Pro during a preview permanently selects that theme
- when Pro expires, the selected Pro theme is remembered while the app renders its free fallback

Disable previews when an app should open the paywall immediately:

```swift
let manager = ThemeManager(
    catalog: catalog,
    previewBehavior: .disabled
)
```

Supply an app-specific preview without replacing the picker behavior:

```swift
ThemePickerView(manager: themes) { theme in
    MyThemePreview(theme: theme)
}
```

## Apply the active theme

The root modifier injects the active theme, tint, and preferred color scheme:

```swift
RootView()
    .appFoundationTheme(themes)
```

Read it in any child view:

```swift
@Environment(\.appFoundationTheme) private var theme
```

Ready-to-use primitives are also included:

```swift
ZStack {
    AppThemeBackground(theme: themes.effectiveTheme)

    AppThemeCard(theme: themes.effectiveTheme) {
        Text("Themed content")
    }
}
```

Existing components accept `AppTheme` directly:

```swift
FoundationBackground(theme: themes.effectiveTheme)
FoundationCard(theme: themes.effectiveTheme) { content }
FoundationPrimaryButtonStyle(theme: themes.effectiveTheme)
```

## Widgets and app groups

Use the same suite name in the app and widget:

```swift
let store = UserDefaultsThemeStateStore(
    storageKey: "com.example.app.theme-state",
    suiteName: "group.com.example.app"
)
```

A widget resolves the same effective theme without creating a `ThemeManager`:

```swift
let state = store.load()
let resolution = ThemeResolver.resolve(
    catalog: MyThemeCatalog.value,
    state: state
)

let theme = resolution.effectiveTheme
let previewExpiry = resolution.nextAutomaticChangeDate
```

When `previewExpiry` exists, add a widget timeline entry at that date using the fallback theme. In the app, use `stateDidChange` to reload timelines:

```swift
let manager = ThemeManager(
    catalog: catalog,
    stateStore: store,
    stateDidChange: { _ in
        WidgetCenter.shared.reloadAllTimelines()
    }
)
```

## Alternate app icons

Theme definitions may carry app-owned icon metadata:

```swift
let midnight = FoundationThemes.midnight
    .withAlternateIconName("AppIconMidnight")
    .withPreviewImageName("AppIconMidnightPreview")
```

Apply it explicitly after a theme change:

```swift
try await ThemeAppIconManager.apply(themes.effectiveTheme)
```

AppFoundation does not ship icon assets. Each app remains responsible for adding and configuring its alternate icons.

## Prototype purchases without StoreKit

Debug builds can use an in-process simulator while keeping the same controller and paywall UI:

```swift
let mode = PurchaseServiceMode.fromEnvironment(fallback: .live)
let service = PurchaseServiceFactory.make(
    mode: mode,
    simulatedProducts: products,
    simulatedPersistenceKey: "com.example.app.simulated-purchases"
)

let purchases = PurchaseController(
    configuration: configuration,
    service: service
)
```

`SimulatedPurchaseService` loads app-defined products, grants local entitlements, supports restore persistence, and can simulate pending, cancelled, catalog-failure, purchase-failure, and restore-failure states. Its implementation is excluded from Release builds; `PurchaseServiceFactory` always returns `LiveStoreKitService` in Release.

Set `APPFOUNDATION_PURCHASE_MODE` to `live` or `simulated` at launch. With `devicectl`, prefix the variable with `DEVICECTL_CHILD_` in the calling environment.

## Present the paywall

```swift
FoundationPaywallView(
    purchases: purchases,
    configuration: FoundationPaywallConfiguration(
        title: "Unlock Pro",
        subtitle: "Get every premium feature.",
        features: [
            FoundationPaywallFeature(
                id: "unlimited",
                systemImage: "infinity",
                title: "Unlimited access",
                message: "Remove all free-plan limits."
            )
        ],
        privacyURL: privacyURL,
        termsURL: termsURL,
        theme: .indigo
    )
)
```

For a compact paywall with side-by-side plan cards, use `ClaudePaywallView`.

## Run the Demo

```bash
brew install xcodegen
cd Examples/Demo
make open
```

The generated project uses:

- Team ID `J458WW3452`
- Bundle identifier `com.hoangbkit.demo`
- iOS deployment target `26.0`
- Local `Configuration.storekit` attached to the shared scheme

## Testing

Run package tests:

```bash
swift test
```

Run all portable validation available outside Xcode:

```bash
make validate
```

Run the Demo simulator tests on macOS with Xcode 26:

```bash
cd Examples/Demo
make test
```

## Production checklist

Before using this in a released app:

1. Replace Demo product identifiers with products created in App Store Connect.
2. Provide real privacy, terms, support, and share URLs.
3. Give every theme a stable ID and keep migration aliases when renaming IDs.
4. Configure an app-group theme store when widgets need the active theme.
5. Add app-owned alternate icon assets before assigning `alternateIconName`.
6. Test preview expiry while the app is backgrounded and while widgets are visible.
7. Test purchases, restore, upgrades, downgrades, expiry, billing retry, revocation, Ask to Buy, and interrupted network flows.
8. Keep feature authorization tied to `PurchaseController.entitlementState`, not cached theme state.

## Structure

```text
Sources/AppFoundation/Core       Pure models and entitlement rules
Sources/AppFoundation/Purchases  StoreKit 2 service and observable controller
Sources/AppFoundation/Themes     Theme definitions, catalog, state, and resolver
Sources/AppFoundation/UI         SwiftUI components, picker, and theme bridges
Tests/AppFoundationTests         Portable and iOS-only tests
Examples/Demo                    XcodeGen sample app
```

## License

MIT
