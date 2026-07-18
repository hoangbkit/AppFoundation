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

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(purchases)
                .managesPurchases(purchases)
        }
    }
}
