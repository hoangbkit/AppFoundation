# Architecture

## Entitlements

`PurchaseController` is the UI-facing state owner. It never persists a trusted `isPro` Boolean. Instead it asks `PurchaseServing` for current verified transactions and passes normalized `EntitlementRecord` values into the pure `EntitlementEvaluator`.

This separation provides three useful boundaries:

1. StoreKit-specific types remain inside `LiveStoreKitService`.
2. Entitlement rules remain deterministic and testable.
3. SwiftUI observes a compact state model: checking, inactive, or active.

## Dependency injection

Production apps can use the convenience initializer:

```swift
PurchaseController(configuration: configuration)
```

Tests can inject any `PurchaseServing` implementation:

```swift
PurchaseController(configuration: configuration, service: mockService)
```

The service protocol is main-actor isolated. StoreKit product objects stay inside the live service and are not leaked across concurrency domains.

## Lifecycle

Attach `.managesPurchases(controller)` once near the app root. It calls `prepare()` and refreshes entitlements when the scene becomes active. The controller also observes `Transaction.updates` for changes that arrive while the app is running.

## UI composition

The package intentionally provides complete default screens plus smaller primitives. Apps can ship the default onboarding, paywall, and settings screens or compose their own screens using `FoundationCard`, `FoundationPill`, `FoundationBackground`, and `FoundationPrimaryButtonStyle`.

Brand data belongs in each app. Product identifiers, URLs, copy, and colors are constructor arguments rather than package constants.
