import AppFoundation
import SwiftUI

@MainActor
struct PaywallScreenshotStudioDemoView: View {
    @State private var purchases = PurchaseManager.screenshotPreview(
        configuration: DemoConfiguration.purchases,
        products: DemoConfiguration.simulatedProducts
    )

    var body: some View {
        ScreenshotStudio(catalog: catalog)
    }

    private var catalog: ScreenshotCatalog {
        ScreenshotCatalog(
            appName: "AppFoundation Demo",
            presets: [
                .iPhone69Portrait,
                .iPhone65Portrait,
            ],
            locales: [.english],
            defaultPresetID: ScreenshotDevicePreset.iPhone69Portrait.id,
            defaultLocaleID: ScreenshotStudioLocale.english.id,
            defaultScreenshotID: "subscription-review"
        ) {
            ScreenshotDefinition(
                id: "subscription-review",
                title: "Subscription Review",
                filename: "Demo Pro subscription paywall"
            ) {
                ClaudePaywallScreenshotTemplate(
                    purchases: purchases,
                    configuration: DemoConfiguration.legacyClaudePaywall
                )
            }
        }
    }
}
