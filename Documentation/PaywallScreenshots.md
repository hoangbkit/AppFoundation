# Paywall screenshots

Screenshot Studio can render an app's real subscription paywall for App Store Connect review. The package does not recreate the paywall or copy its layout.

## Custom paywalls

Wrap the app-owned view directly:

```swift
ScreenshotDefinition(
    id: "subscription-review",
    title: "Subscription Review",
    filename: "My App subscription paywall"
) {
    PaywallScreenshotTemplate {
        MyPaywallView()
            .environment(screenshotPurchases)
            .environmentObject(previewStore)
    }
}
```

`PaywallScreenshotTemplate` fills the screenshot canvas, centers the supplied paywall by default, clips overflow, and disables interaction. The supplied view remains the source of truth. Pass a different `Alignment` when an app-owned paywall intentionally uses another placement.

## ProPaywallView

Apps that use AppFoundation's Pro paywall can use the dedicated template:

```swift
@State private var screenshotPurchases = PurchaseManager.screenshotPreview(
    configuration: AppPurchases.configuration,
    products: [
        PurchaseProduct(
            id: AppPurchases.monthlyProductID,
            displayName: "My App Pro Monthly",
            description: "Monthly access to every Pro feature.",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        ),
        PurchaseProduct(
            id: AppPurchases.yearlyProductID,
            displayName: "My App Pro Yearly",
            description: "Annual access to every Pro feature.",
            displayPrice: "$24.99",
            price: 24.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        ),
    ]
)

ScreenshotDefinition(
    id: "subscription-review",
    title: "Subscription Review",
    filename: "My App Pro subscription paywall"
) {
    ProPaywallScreenshotTemplate(
        purchases: screenshotPurchases,
        configuration: AppPurchases.paywallConfiguration
    )
}
```

`ProPaywallScreenshotTemplate` instantiates the real `ProPaywallView`. It does not maintain a separate screenshot implementation. During screenshot rendering, the same paywall content is shown without its interactive `NavigationStack`, toolbar, alerts, or asynchronous setup. The content is vertically centered on the final screenshot canvas so `ImageRenderer` exports the complete review asset reliably.

## Deterministic products

Screenshot Studio exports with `ImageRenderer`, so asynchronous StoreKit loading cannot be relied on during export. `PurchaseManager.screenshotPreview(configuration:products:)` exposes the supplied products synchronously, keeps the entitlement inactive, and avoids network or App Store dependencies.

Use the same product identifiers, plan order, display prices, paywall configuration, theme, and supporting environment values that the app expects. Keep the screenshot controller separate from the app's normal purchase controller.

The highlighted or preferred product is selected synchronously when `ProPaywallView` is created. A different plan can be selected explicitly:

```swift
ProPaywallScreenshotTemplate(
    purchases: screenshotPurchases,
    configuration: AppPurchases.paywallConfiguration,
    selectedProductID: AppPurchases.monthlyProductID
)
```

The Demo registers Subscription Review directly in the Screenshot Studio opened from Home. It renders the real Pro paywall alongside the normal App Store screenshot examples.
