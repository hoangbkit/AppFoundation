# Adoption guide

## Recommended extraction strategy

Keep each app's navigation, analytics, feature screens, and assets in the app target. Reuse AppFoundation for stable infrastructure and components.

## StoreKit setup

Create a `PurchaseConfiguration` per app. Product order is preserved and controls paywall order. The optional preferred product becomes the initial paywall selection.

Call `prepare()` through `.managesPurchases` or manually from your app lifecycle. Read `entitlementState.isActive` or `isEntitled` wherever premium access is required.

## Onboarding

Store completion in the app target with `@AppStorage`, then pass app-specific pages to `FoundationOnboardingView`. This keeps the package independent of each app's onboarding key and routing.

## Settings

Provide only the URLs available for the app. Missing URLs are omitted from the settings screen. App Store review requests use SwiftUI's system request-review action.

## Customization

Create a `FoundationTheme` once per app and pass it to package components. Avoid adding app-specific colors or copy to the package itself.
