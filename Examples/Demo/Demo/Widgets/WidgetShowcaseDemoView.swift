import AppFoundation
import SwiftUI

struct WidgetShowcaseDemoView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes

    @State private var isShowingPaywall = false

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        WidgetShowcaseView(
            catalog: DemoWidgetCatalog.make(theme: theme),
            guide: WidgetInstallGuideConfiguration(
                appName: "AF",
                widgetSearchName: "AF",
                gallerySubtitle: "Package features at a glance",
                tip: "These previews are supplied by the Demo app. AppFoundation owns the gallery, sizing, access, navigation, and setup instructions."
            ),
            hasPro: purchases.hasPro,
            style: WidgetShowcaseStyle(
                accentColor: theme.accentColor,
                primaryTextColor: theme.primaryForegroundColor,
                secondaryTextColor: theme.secondaryForegroundColor,
                surfaceColor: theme.surfaceColor,
                elevatedSurfaceColor: theme.elevatedSurfaceColor,
                borderColor: theme.borderColor
            ),
            onRequestUpgrade: { isShowingPaywall = true },
            background: { AppThemeBackground(theme: theme) }
        )
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(
                purchaseManager: purchases,
                configuration: DemoConfiguration.modernPaywall
            )
        }
        .animation(.smooth, value: theme.id)
    }
}
