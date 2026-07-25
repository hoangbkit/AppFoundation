#if canImport(SwiftUI)
import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

/// Renders the host app's real paywall as a full-canvas Screenshot Studio scene.
///
/// This template does not recreate, restyle, or copy the paywall. It only gives the supplied
/// view the complete screenshot canvas and disables interaction during preview and export.
@MainActor
public struct PaywallScreenshotTemplate<Paywall: View>: View {
    private let paywall: Paywall

    public init(@ViewBuilder paywall: () -> Paywall) {
        self.paywall = paywall()
    }

    public var body: some View {
        paywall
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .allowsHitTesting(false)
    }
}

#if canImport(StoreKit)
/// A Screenshot Studio template that renders AppFoundation's real `ClaudePaywallView`.
///
/// Pass a deterministic controller created with `PurchaseManager.screenshotPreview` so the
/// product catalog and selected plan are available synchronously to `ImageRenderer`.
@MainActor
public struct ClaudePaywallScreenshotTemplate: View {
    private let purchases: PurchaseController
    private let configuration: FoundationPaywallConfiguration
    private let selectedProductID: String?

    public init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration,
        selectedProductID: String? = nil
    ) {
        self.purchases = purchases
        self.configuration = configuration
        self.selectedProductID = selectedProductID
    }

    public var body: some View {
        PaywallScreenshotTemplate {
            ClaudePaywallView(
                purchases: purchases,
                configuration: configuration,
                initialSelectedProductID: selectedProductID
            )
        }
    }
}
#endif
#endif
