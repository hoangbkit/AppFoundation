# AppFoundation

A production-oriented Swift package for shipping consistent iOS apps faster. It targets **iOS 26.0+** and uses **Swift 6** strict concurrency.

## Included

- StoreKit 2 purchase controller with verified in-memory entitlement state
- Transaction update observation and foreground refresh support
- Product loading retry, restore, pending purchase, and error states
- Pure entitlement evaluation that can be unit tested without StoreKit
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchases)
                .managesPurchases(purchases)
        }
    }
}
```

`PurchaseController.entitlementState` is derived from verified StoreKit transactions. Do not mirror it into UserDefaults as an access-control source of truth.

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

For a compact paywall with side-by-side plan cards, use the alternate style:

```swift
ClaudePaywallView(
    purchases: purchases,
    configuration: configuration
)
```

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
3. Update each app's privacy manifest for the APIs and SDKs that app actually uses.
4. Test purchases, restore, upgrades, downgrades, expiry, billing retry, revocation, Ask to Buy, and interrupted network flows.
5. Keep feature authorization tied to `entitlementState`, not a cached Boolean.
6. Add server-side App Store Server API validation when your product requires cross-platform accounts, fraud controls, or server-managed benefits.

## Structure

```text
Sources/AppFoundation/Core       Pure models and entitlement rules
Sources/AppFoundation/Purchases  StoreKit 2 service and observable controller
Sources/AppFoundation/UI         Reusable SwiftUI components
Tests/AppFoundationTests         Portable and iOS-only tests
Examples/Demo                    XcodeGen sample app
```

## License

MIT
