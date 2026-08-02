import AppFoundation
import SwiftUI

enum DemoVisualStyleOption: String, CaseIterable, Identifiable {
    case signature
    case native
    case flat
    case glass

    var id: Self { self }

    var title: String {
        switch self {
        case .signature: "Signature"
        case .native: "Native"
        case .flat: "Flat"
        case .glass: "Glass"
        }
    }

    var systemImage: String {
        switch self {
        case .signature: "sparkles"
        case .native: "iphone"
        case .flat: "rectangle"
        case .glass: "circle.hexagongrid.fill"
        }
    }

    var style: FoundationVisualStyle {
        switch self {
        case .signature: .signature
        case .native: .native
        case .flat: .flat
        case .glass: .glass
        }
    }
}

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

    @AppStorage("appfoundation.demo.visual-style")
    private var visualStyleID = DemoVisualStyleOption.signature.rawValue

    private var visualStyle: FoundationVisualStyle {
        DemoVisualStyleOption(rawValue: visualStyleID)?.style ?? .signature
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .id(purchaseStore.revision)
                .environment(purchaseStore)
                .environment(purchaseStore.purchases)
                .environment(themes)
                .managesPurchases(purchaseStore.purchases)
                .appFoundationTheme(themes)
                .appFoundationStyle(visualStyle)
                .synchronizesThemeAccess(themes, hasPro: purchaseStore.purchases.hasPro)
        }
    }
}
