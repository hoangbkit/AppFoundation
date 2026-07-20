import AppFoundation
import SwiftUI

@main
@MainActor
struct DemoApp: App {
    @State private var purchases = PurchaseController(
        configuration: DemoConfiguration.purchases,
        service: PurchaseServiceFactory.make(
            mode: DemoConfiguration.purchaseServiceMode,
            simulatedProducts: DemoConfiguration.simulatedProducts,
            simulatedPersistenceKey: "appfoundation.demo.simulated-purchases"
        )
    )

    @State private var themes = ThemeManager(
        catalog: .foundationDefaults,
        stateStore: UserDefaultsThemeStateStore(
            storageKey: "appfoundation.demo.theme-state"
        )
    )

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(purchases)
                .environment(themes)
                .managesPurchases(purchases)
                .appFoundationTheme(themes)
                .synchronizesThemeAccess(themes, hasPro: purchases.isEntitled)
        }
    }
}
