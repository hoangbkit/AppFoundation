import AppFoundation
import SwiftUI

@main
@MainActor
struct DemoApp: App {
    @State private var purchaseStore = DemoPurchaseStore()

    @State private var themes = ThemeManager(
        catalog: .foundationDefaults,
        stateStore: UserDefaultsThemeStateStore(
            storageKey: "appfoundation.demo.theme-state"
        )
    )

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .id(purchaseStore.revision)
                .environment(purchaseStore)
                .environment(purchaseStore.purchases)
                .environment(themes)
                .managesPurchases(purchaseStore.purchases)
                .appFoundationTheme(themes)
                .synchronizesThemeAccess(themes, hasPro: purchaseStore.purchases.hasPro)
        }
    }
}
