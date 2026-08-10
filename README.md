# AppFoundation

Shared production infrastructure for SwiftUI apps. AppFoundation targets **iOS 26+** and **Swift 6.2 strict concurrency**.

The package centralizes behavior that is expensive to reimplement correctly while keeping each app's navigation, models, copy, branding, fixtures, and visual identity app-owned.

## Package products

| Product | Purpose |
| --- | --- |
| `AppFoundation` | Commerce, themes, onboarding, settings, exports, backups, App Group storage, notifications, and shared utilities. It also re-exports the Studio and Showcase products. |
| `AppFoundationScreenshotStudio` | Exact-size SwiftUI screenshot composition, preview, templates, and export on iOS. |
| `AppFoundationPromoVideoStudio` | Deterministic SwiftUI promo-video editing and silent H.264 MP4 export on iOS. |
| `AppFoundationWidgetShowcase` | In-app widget catalogs, previews, detail screens, installation guidance, and Free/Pro presentation. |

Individual APIs use conditional compilation when a framework or platform is unavailable.

## Requirements

- Xcode 26+
- Swift 6.2+
- iOS 26+
- XcodeGen 2.45.4+ for the Demo projects

## Installation

Add the package in Xcode using:

```text
https://github.com/hoangbkit/AppFoundation.git
```

The latest tagged release is **0.1.8**. Because AppFoundation is still in the `0.x` development series, prefer **Up to Next Minor Version** from `0.1.8` or pin an exact version for reproducible app releases.

For a package manifest:

```swift
dependencies: [
    .package(
        url: "https://github.com/hoangbkit/AppFoundation.git",
        .upToNextMinor(from: "0.1.8")
    )
]
```

Link `AppFoundation` for the complete package, or link one of the narrower products when an isolated Studio or Showcase dependency is preferred.

## Commerce quick start

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

`PurchaseManager` is the preferred source-compatible name for the existing `PurchaseController`. Existing apps do not need an immediate migration.

Verified StoreKit transactions remain the source of truth. Do not mirror `hasPro` into `UserDefaults` as an authorization source.

## Included infrastructure

### Commerce

- StoreKit 2 product loading, purchase, restore, and verified entitlement state
- Transaction update observation and foreground refresh
- Debug-only in-process purchase simulation
- `PurchaseManager` and simple `hasPro` entitlement access
- Weekly, monthly, yearly, and non-consumable lifetime plans
- Theme-aware `PaywallView`, `FoundationPaywallView`, and `ProPaywallView`
- Premium gates, badges, locked overlays, settings sections, and limit-reached upsells
- Access policy that can keep existing user-created content available after entitlement expiry

AppFoundation presents configured entitlement products in `PurchaseConfiguration.productIDs` order. Subscription prices and periods come from StoreKit. A configured entitlement product without a subscription period is treated as lifetime access and uses one-time-purchase disclosure instead of renewal wording.

### Themes

- Reusable immutable theme catalogs and `ThemeManager`
- Rose, Sunset, Lavender, Midnight, Paper, and Champagne defaults
- Persisted selected-theme state and free fallback resolution
- Timed Pro previews and entitlement-aware selection behavior
- App Group-compatible widget theme state
- SwiftUI environment integration and theme picker
- Optional alternate app-icon helper

Apps may exclude, replace, reorder, or append themes. AppFoundation does not require every app to share the same visual design.

### ExportKit

- Safe filenames and predictable suggested filenames
- Atomic temporary-file writing and cleanup
- PNG and JPEG definitions
- Exact-dimension SwiftUI rendering
- Transparent PNG and JPEG quality support
- Pixel-count preflight and reusable sharing support

### BackupKit

- Generic versioned `BackupEnvelope<Payload>`
- Folder-based custom backup packages
- Manifest, payload checksum, and optional assets
- Cross-app and unsupported-version rejection
- Missing-asset, corrupt-payload, duplicate-path, and path-traversal protection
- Actor-isolated package reader and writer

Each app remains responsible for migrations, duplicate handling, replace-versus-merge behavior, restore confirmation, and transactional mutation of its own database.

### App and platform support

- Typed App Group snapshot storage
- Schema version and update metadata
- Shared deep-link construction
- Widget reload throttling
- Local notification authorization, scheduling, replacement, and cancellation
- `UserFacingError`, `AppInfo`, safe file replacement, and async debouncing
- Review-request policy, structured logging, haptics, and `AsyncButton`

## Screenshot Studio

`AppFoundationScreenshotStudio` lets an app register deterministic SwiftUI screenshots, preview them at exact output geometry, inject app-owned controls, and export the complete set.

```swift
import AppFoundationScreenshotStudio

ScreenshotStudio(
    catalog: screenshotCatalog,
    style: .standard
) { context in
    Section("Screenshot") {
        Text(context.selectedScreenshotTitle)
    }
} appConfigurationControls: { context in
    Section("Campaign") {
        Text(context.preset.title)
    }
}
```

The Studio supports App Store presets, locale and appearance selection, full-set preview, and sharing.

See:

- [Screenshot Studio](Documentation/ScreenshotStudio.md)
- [Reusable Screenshot Components](Documentation/ScreenshotStudioComponents.md)

## Promo Video Studio

`AppFoundationPromoVideoStudio` renders registered SwiftUI scenes using the same deterministic timeline for interactive preview and exact frame-by-frame export.

```swift
import AppFoundationPromoVideoStudio

PromoVideoStudio(
    videos: [launchVideo, widgetVideo],
    style: .standard
) { context in
    Section("Scene Controls") {
        Text(context.selectedSceneTitle)
    }
} videoConfigurationControls: { context in
    Section("Campaign") {
        Text(context.preset.title)
    }
}
```

A single project can still be supplied with `PromoVideoStudio(project:)`. With `videos:`, the toolbar switches among registered videos while preview, scrubbing, configuration, and export remain scoped to the selected video.

The iOS implementation supports deterministic playback, scrubbing, scene selection, safe-area preview, 30 or 60 fps output, and silent H.264 MP4 export.

Included story templates:

- `HeroIntroPromoVideoScene`
- `DeviceRevealPromoVideoScene`
- `FeatureFocusPromoVideoScene`
- `LayeredScreensPromoVideoScene`
- `AppFlowPromoVideoScene`
- `OutroCallToActionPromoVideoScene`
- `ContinuousCanvasPromoVideoScene`

See:

- [Promo Video Studio](Documentation/PromoVideoStudio.md)

## Widget Showcase

`AppFoundationWidgetShowcase` owns the reusable in-app experience around app-owned WidgetKit views. The host app still owns its widget extension, timeline provider, intents, App Group data, production widget views, preview data, and upgrade flow.

```swift
import AppFoundationWidgetShowcase

WidgetShowcaseView(
    catalog: widgetCatalog,
    guide: WidgetInstallGuideConfiguration(appName: "My App"),
    hasPro: purchaseManager.hasPro,
    style: WidgetShowcaseStyle(accentColor: theme.accentColor),
    onRequestUpgrade: { showPaywall = true }
) {
    AppBackground(theme: theme)
}
```

See [Widget Showcase](Documentation/WidgetShowcase.md) for catalog registration, preview sizing, detail presentation, and generated Home Screen setup guidance.

## Debug purchase simulation

```swift
let purchaseManager = PurchaseManager(
    configuration: configuration,
    simulated: true,
    simulatedProducts: products,
    simulatedPersistenceKey: "com.example.app.simulated-purchases"
)
```

Simulation code is Debug-only. Release builds always use live StoreKit. Runtime switching remains available through `setSimulatedPurchasesEnabled(_:)` in Debug builds.

## Validation

Run portable package validation:

```bash
swift test
```

Run the repository validation script:

```bash
make validate
```

Generate and test the iOS Demo:

```bash
cd Examples/Demo
make test
```

The simulator build requires macOS with Xcode 26.

## Migration notes

- Prefer `PurchaseManager` over `PurchaseController` in new code.
- Prefer `hasPro` over `isEntitled` for normal feature checks.
- Prefer `PaywallView` and `PaywallConfiguration` for new paywalls.
- Existing monthly/yearly purchase configurations continue working.
- Adding weekly or lifetime access only requires adding the StoreKit product identifier to the entitlement catalog.
- Existing purchase, theme, onboarding, settings, and legacy paywall APIs remain available.
- Move only reusable infrastructure into AppFoundation; keep app-specific models, navigation, copy, branding, and final presentation in each app.

See [CHANGELOG.md](CHANGELOG.md) for tagged release history and [PLAN.md](PLAN.md) for package boundaries and development phases.

## License

MIT
