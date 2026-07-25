#if canImport(SwiftUI)
import SwiftUI

/// Renders the host app's real paywall as a full-canvas Screenshot Studio scene.
///
/// This template does not recreate, restyle, or copy the paywall. It only gives the supplied
/// view the complete screenshot canvas, centers it by default, and disables interaction during
/// preview and export.
@MainActor
public struct PaywallScreenshotTemplate<Paywall: View>: View {
    private let alignment: Alignment
    private let paywall: Paywall

    public init(
        alignment: Alignment = .center,
        @ViewBuilder paywall: () -> Paywall
    ) {
        self.alignment = alignment
        self.paywall = paywall()
    }

    public var body: some View {
        ZStack(alignment: alignment) {
            paywall
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .clipped()
        .allowsHitTesting(false)
    }
}
#endif
