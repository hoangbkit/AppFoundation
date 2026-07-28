#if canImport(SwiftUI) && canImport(StoreKit)
import AppFoundationScreenshotStudio
import StoreKit
import SwiftUI

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
                initialSelectedProductID: selectedProductID,
                rendersForScreenshot: true
            )
            .environment(purchases)
        }
    }
}
#endif
