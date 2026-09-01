# Foundation Developer Tools

`FoundationDeveloperView` is a Debug-only Settings surface for AppFoundation apps. It gives every app the same baseline developer controls while allowing each app to register its real product flows and app-specific tools.

The design has two rules:

1. Common AppFoundation capabilities appear automatically.
2. App-specific behavior is registered; AppFoundation never needs to know the app's domain models.

## Availability

The developer tools API is compiled only in Debug builds on supported iOS targets.

```swift
#if DEBUG
NavigationLink("Developer") {
    FoundationDeveloperView(purchaseManager: purchases)
}
#endif
```

Release builds do not contain `FoundationDeveloperView`, simulated StoreKit failure controls, or the developer registration types.

## Built-in sections

Supplying only a `PurchaseManager` provides the common baseline.

### App

- App display name
- Version and build
- Bundle identifier
- Debug build indicator
- Simulator versus device
- iOS version

### Purchases

- Switch Live StoreKit / Simulated purchases
- Current Free / Pro entitlement
- Product loading state
- Loaded product names and prices
- Direct simulated entitlement selection
- Simulated plan and price editor
- Force entitlement refresh
- Force product reload
- Reset simulated purchases

The simulated plan editor can add, remove, reorder, enable, and disable products; edit product IDs, names, descriptions, displayed prices, numeric prices, and billing periods; choose which products unlock Pro; and select the preferred plan.

Editing simulated pricing never changes App Store Connect pricing. The controller keeps its original live `PurchaseConfiguration` separate from the Debug simulated configuration.

### Purchase failure simulation

When simulated purchases are enabled, the developer view can set future purchases to:

- Success
- Pending
- User Cancelled
- Network Failure
- Product Unavailable
- System Failure

It can also inject:

- Product-catalog loading failure
- Restore failure
- Instant, 250 ms, 1 second, or 3 second operation latency

`Reset failure simulation` returns future simulator operations to their normal successful behavior without changing the current entitlement.

### Startup and recovery

The common developer view can always present the neutral `StartupRecoveryView` preview without touching app data.

Real app startup scenarios remain app-owned. Register a destination or action in an additional section when an app needs controls such as corrupting a test store, rebuilding an index, or running its real startup simulator.

### Diagnostics

The common view shows current purchase mode, purchase activity, preferred product, and simulated product configuration. `Copy diagnostics` copies a compact app and purchase-state report to the pasteboard.

## Register production flows for replay

The developer view should replay the app's real production UI rather than recreate a fake debug version of it.

```swift
let developerConfiguration = FoundationDeveloperConfiguration(
    replays: [
        FoundationDeveloperReplay(
            id: "paywall",
            title: "Paywall",
            systemImage: "rectangle.portrait.and.arrow.forward"
        ) { _ in
            PaywallView(
                purchaseManager: purchases,
                configuration: appPaywallConfiguration
            )
        },
        FoundationDeveloperReplay(
            id: "onboarding",
            title: "Onboarding",
            systemImage: "rectangle.stack.fill",
            presentation: .fullScreen
        ) { close in
            FoundationOnboardingView(
                pages: onboardingPages
            ) {
                close()
            }
        },
    ]
)
```

Use `.sheet` for normal modal flows and `.fullScreen` when the production experience needs full-screen presentation. The replay receives a `close` callback so completion-driven flows such as onboarding can return to Developer Tools without mutating first-run state.

Typical registered flows include:

- Paywall
- Limit-reached upsell
- Onboarding
- Pro celebration
- App-specific upgrade or education flows

## Reset onboarding separately from replay

Previewing onboarding should not have to alter first-run state. Apps may separately register their real reset behavior:

```swift
FoundationDeveloperConfiguration(
    replays: onboardingReplay,
    resetOnboarding: FoundationDeveloperAction(
        title: "Reset Onboarding",
        systemImage: "arrow.counterclockwise",
        role: .destructive
    ) {
        onboardingStore.reset()
    }
)
```

This keeps two different testing needs explicit:

- **Replay:** show the flow now without changing persistent state.
- **Reset:** make the app behave as not-yet-onboarded according to the app's own storage policy.

## Register app-specific sections

Apps extend the common view with structured native Settings rows.

```swift
FoundationDeveloperSection(
    title: "My App",
    items: [
        .value(
            FoundationDeveloperValue(
                title: "Database",
                value: { database.statusText }
            )
        ),
        .toggle(
            FoundationDeveloperToggle(
                title: "Simulate Slow Sync",
                value: { debugState.slowSync },
                setValue: { debugState.slowSync = $0 }
            )
        ),
        .destination(
            FoundationDeveloperDestination(
                title: "Startup Simulator",
                systemImage: "heart.text.square"
            ) {
                StartupSimulatorView()
            }
        ),
        .action(
            FoundationDeveloperAction(
                title: "Clear Cache",
                systemImage: "trash",
                role: .destructive
            ) {
                try await cache.clear()
            }
        ),
    ]
)
```

Supported registration items are:

- `FoundationDeveloperValue` for live read-only state
- `FoundationDeveloperToggle` for app-owned debug flags
- `FoundationDeveloperDestination` for deeper SwiftUI tools
- `FoundationDeveloperAction` for synchronous or async operations, including destructive actions

AppFoundation renders these with the same native Form hierarchy as its built-in tools.

## Purchase simulation API

`PurchaseController` also exposes Debug-only APIs for custom developer surfaces and tests:

```swift
await purchases.setSimulatedPurchasesEnabled(true)
await purchases.setSimulatedPurchasedProductIDs([productID])
purchases.setSimulatedPurchaseResult(.pending, for: productID)
await purchases.setSimulatedProductLoadingFailure(.noProductsAvailable)
purchases.setSimulatedRestoreFailure(.unknown)
purchases.setSimulatedOperationDelay(.seconds(1))
await purchases.resetSimulatedFailures()
await purchases.resetSimulatedPurchases()
```

A simulated catalog can be replaced without touching the live StoreKit configuration:

```swift
await purchases.configureSimulatedCatalog(
    configuration: simulatedConfiguration,
    products: simulatedProducts
)
```

Switching back to Live StoreKit restores the controller's original production `PurchaseConfiguration`.

## Recommended app integration

Every AppFoundation app should expose a Developer row from its Settings screen in Debug builds:

```swift
#if DEBUG
Section("Developer") {
    NavigationLink {
        FoundationDeveloperView(
            purchaseManager: purchases,
            configuration: developerConfiguration
        )
    } label: {
        Label("Developer Tools", systemImage: "hammer.fill")
    }
}
#endif
```

Keep routine controls in the common view. Register app-specific tools only when they represent real app state or flows that AppFoundation cannot own.