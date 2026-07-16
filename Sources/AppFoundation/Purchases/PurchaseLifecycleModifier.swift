#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

public extension View {
    /// Prepares StoreKit once and refreshes entitlements whenever the app becomes active.
    func managesPurchases(_ controller: PurchaseController) -> some View {
        modifier(PurchaseLifecycleModifier(controller: controller))
    }
}

private struct PurchaseLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let controller: PurchaseController

    func body(content: Content) -> some View {
        content
            .task {
                await controller.prepare()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                Task {
                    await controller.refreshEntitlements()
                }
            }
    }
}
#endif
