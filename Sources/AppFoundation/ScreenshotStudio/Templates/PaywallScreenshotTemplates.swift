#if canImport(SwiftUI)
import SwiftUI

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
#endif
