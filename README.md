# AppFoundation

Shared production infrastructure for Hoang's iOS apps. AppFoundation targets **iOS 26+** and **Swift 6.2 strict concurrency**.

The package centralizes behavior that is expensive to reimplement correctly while keeping each app's navigation, data models, copy, and visual identity app-owned.

## Included

### Commerce

- StoreKit 2 product loading, purchase, restore, and verified entitlement state
- Transaction update observation and foreground refresh support
- Debug-only in-process purchase simulation
- `PurchaseManager` as the preferred app-facing API
- Simple `hasPro` entitlement access
- Theme-aware paywalls supporting weekly, monthly, yearly, and lifetime plans
- Premium feature gates and subscription settings components
- Access policy that can keep existing user-created content available after expiry

### Themes

- Existing reusable theme catalog and manager
- Rose, Sunset, Lavender, Midnight, Paper, and Champagne defaults
- Free fallback themes and timed Pro previews
- App Group-compatible persisted theme state
- SwiftUI environment integration and theme picker
- Optional alternate app-icon helper

### ExportKit

- Safe filenames and predictable suggested filenames
- Atomic temporary-file writing and cleanup
- PNG and JPEG definitions
- SwiftUI view rendering at exact dimensions and scale
- Transparent PNG and JPEG quality support

### BackupKit

- Generic versioned `BackupEnvelope<Payload>`
- Folder-based custom backup packages
- Manifest, payload checksum, and optional assets
- Cross-app and unsupported-version rejection
- Corrupt-payload and path-traversal protection
- Actor-isolated package reader and writer

### Platform support

- Typed App Group snapshot storage
- Schema version and update metadata
- Shared deep-link construction
- Widget reload throttling
- Local notification authorization, scheduling, replacement, and cancellation

### Utilities

- `UserFacingError`
- `AppInfo`
- Atomic file replacement
- Async debouncing
- Review-request policy
- Structured logging and haptics
- Reusable `AsyncButton`

## Requirements

- Xcode 26+
- Swift 6.2+
- iOS 26+
- XcodeGen 2.45.4+ for the Demo app

## Add the package

Add this repository as a Swift package and link the `AppFoundation` product to the app target.

```swift
import AppFoundation
import SwiftUI

@main
@MainActor
struct MyApp: App {
    @State private var purchaseManager = PurchaseManager(
        configuration: PurchaseConfiguration(
            productIDs: [
                "com.example.app.pro.weekly",
                "com.example.app.pro.monthly",
                "com.example.app.pro.yearly",
                "com.example.app.pro.lifetime",
            ],
            preferredProductID: "com.example.app.pro.yearly"
        )
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchaseManager)
                .managesPurchases(purchaseManager)
        }
    }
}
```

`PurchaseManager` is a source-compatible preferred name for the existing `PurchaseController`. Existing apps do not need an immediate migration.

Verified StoreKit transactions remain the source of truth. Do not mirror `hasPro` into UserDefaults as an authorization source.

## Supported purchase plans

AppFoundation presents every configured entitlement product in `PurchaseConfiguration.productIDs` order:

- A one-week subscription appears as **Weekly**.
- A one-month subscription appears as **Monthly**.
- A one-year subscription appears as **Yearly**.
- A configured entitlement product without a subscription period appears as **Lifetime**.

Use an auto-renewable subscription in App Store Connect for recurring plans. Use a non-consumable in-app purchase for lifetime access. A verified non-consumable transaction has no expiration date, so the existing entitlement evaluator keeps it active permanently unless Apple revokes it.

`StoreProduct.planKind`, `planLabel`, `billingDescription`, `isRecurring`, and `isLifetime` are available for app-owned purchase UI. `PurchasePlanDisclosure` provides accurate renewal and one-time-purchase copy for recurring-only, lifetime-only, and mixed catalogs.

## Present the primary paywall

```swift
PaywallView(
    purchaseManager: purchaseManager,
    configuration: PaywallConfiguration(
        title: "Unlock Pro",
        subtitle: "Choose a subscription or lifetime access.",
        features: [
            PaywallFeature(
                id: "unlimited",
                systemImage: "infinity",
                title: "Unlimited access",
                message: "Remove all free-plan limits."
            )
        ],
        preferredProductID: "com.example.app.pro.yearly",
        highlightedProductID: "com.example.app.pro.yearly",
        privacyURL: privacyURL,
        termsURL: termsURL
    )
)
```

`PaywallView`, `FoundationPaywallView`, and `ClaudePaywallView` display the full configured catalog. Their layouts adapt from one to multiple columns and fall back to one column at accessibility text sizes. Prices and periods come from StoreKit; lifetime products are described as one-time purchases and never receive subscription-renewal wording.

The paywalls follow the active `AppTheme`. Copy, legal URLs, preferred and highlighted products, optional tint or full-theme overrides, and custom plan details remain app-configured.

## Gate premium actions safely

```swift
let feature = PremiumFeature(
    id: "premiumThemes",
    title: "Premium themes"
)

let decision = PremiumAccessPolicy().decision(
    for: feature,
    requirement: .pro,
    hasPro: purchaseManager.hasPro
)

PremiumGate(decision: decision) {
    PremiumThemePicker()
} locked: { feature in
    LockedFeatureOverlay(feature: feature) {
        showPaywall = true
    }
}
```

For apps containing user-created data, pass `isExistingContent: true` when the user is viewing, exporting, sharing, or deleting content created before expiry. The default policy keeps that content accessible while still allowing creation and premium editing to be gated.

## Debug purchase simulation

```swift
let products: [PurchaseProduct] = [
    PurchaseProduct(
        id: "com.example.app.pro.weekly",
        displayName: "Pro Weekly",
        description: "Weekly access",
        displayPrice: "$1.99",
        price: 1.99,
        subscriptionPeriod: .init(value: 1, unit: .week)
    ),
    PurchaseProduct(
        id: "com.example.app.pro.lifetime",
        displayName: "Pro Lifetime",
        description: "Permanent access",
        displayPrice: "$79.99",
        price: 79.99
    ),
]

let purchaseManager = PurchaseManager(
    configuration: configuration,
    simulated: true,
    simulatedProducts: products,
    simulatedPersistenceKey: "com.example.app.simulated-purchases"
)
```

Simulation code is Debug-only. Release builds always use live StoreKit. Existing runtime switching remains available through `setSimulatedPurchasesEnabled(_:)` in Debug builds.

## Export a SwiftUI view

```swift
let data = try ViewImageExporter.render(
    HeroCardView(),
    size: CGSize(width: 1200, height: 1200),
    scale: 1,
    opaque: false,
    format: .png
)

let file = try await ExportFileWriter().write(
    data,
    filename: "MiLove Hero",
    fileExtension: ExportImageFormat.png.fileExtension
)
```

AppFoundation handles rendering and file creation. The app still owns the actual hero, card, screenshot, or promotional design.

## Create a custom backup package

```swift
struct AppBackup: Codable, Sendable {
    let records: [Record]
}

let configuration = BackupPackageConfiguration(
    format: "com.example.app.backup",
    version: 1,
    appIdentifier: "com.example.app",
    fileExtension: "examplebackup"
)

let envelope = BackupEnvelope(
    format: configuration.format,
    version: configuration.version,
    appIdentifier: configuration.appIdentifier,
    appVersion: "1.0",
    appBuild: "1",
    payload: AppBackup(records: records)
)

let packageURL = try await BackupPackageWriter().write(
    envelope: envelope,
    configuration: configuration,
    assets: imageAssets,
    filename: "My App Backup"
)
```

Restore only after reading and validating the package:

```swift
let result = try await BackupPackageReader().read(
    AppBackup.self,
    from: packageURL,
    configuration: configuration
)
```

Each app remains responsible for migrations, duplicate handling, replace-versus-merge behavior, restore confirmation, and transactional mutation of its own database.

## Share data with widgets

```swift
struct WidgetSnapshot: Codable, Sendable {
    let title: String
    let date: Date
}

let store = try AppGroupStore<WidgetSnapshot>(
    suiteName: "group.com.example.app",
    key: "widget.snapshot"
)

try await store.save(WidgetSnapshot(title: "Anniversary", date: date))
```

Use `WidgetReloadCoordinator` to avoid repeatedly reloading the same widget kind during bursts of changes.

## Schedule local notifications

```swift
let manager = LocalNotificationManager()
let granted = try await manager.requestAuthorization()

if granted {
    try await manager.replace(
        LocalNotificationRequest(
            id: "event.\(eventID)",
            title: event.title,
            body: "Your event is coming up.",
            date: reminderDate
        )
    )
}
```

The app decides what deserves a reminder and when. AppFoundation only handles permission and reliable scheduling mechanics.

## Use the existing theme system

```swift
@State private var themes = ThemeManager(
    catalog: .foundationDefaults,
    stateStore: UserDefaultsThemeStateStore(
        storageKey: "com.example.app.theme-state"
    )
)

RootView()
    .environment(themes)
    .appFoundationTheme(themes)
    .synchronizesThemeAccess(themes, hasPro: purchaseManager.hasPro)
```

Apps may exclude, replace, reorder, or append themes. AppFoundation does not require every app to use the shared themes or design primitives.

## Validation

Run portable package validation:

```bash
swift test
```

Run the existing project validation script:

```bash
make validate
```

The Demo simulator build still requires macOS with Xcode 26.

## Migration notes

- Prefer `PurchaseManager` over `PurchaseController` in new code.
- Prefer `hasPro` over `isEntitled` for normal feature checks.
- Prefer `PaywallView` and `PaywallConfiguration` for new paywalls.
- Existing monthly/yearly configurations continue working without changes.
- Adding weekly or lifetime only requires adding the StoreKit product identifier to the catalog.
- Existing purchase, theme, onboarding, settings, and legacy paywall APIs remain available.
- Move only low-level shared infrastructure into AppFoundation; keep app-specific models and presentation in each app.

See [PLAN.md](PLAN.md) for the package boundary and development phases.

## License

MIT