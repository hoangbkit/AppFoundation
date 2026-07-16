import AppFoundation
import SwiftUI

@main
@MainActor
struct DemoApp: App {
    @State private var purchases = PurchaseController(
        configuration: DemoConfiguration.purchases
    )

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(purchases)
                .managesPurchases(purchases)
        }
    }
}
