import AppFoundation
import SwiftUI

@MainActor
enum DemoConfiguration {
    static let monthlyProductID = DemoProductID.monthly
    static let yearlyProductID = DemoProductID.yearly
    static let lifetimeProductID = DemoProductID.lifetime

    static let purchases = PurchaseConfiguration(
        productIDs: [
            monthlyProductID,
            yearlyProductID,
            lifetimeProductID,
        ],
        preferredProductID: yearlyProductID,
        features: [
            PurchaseFeature(
                id: "projects",
                systemImage: "square.grid.2x2.fill",
                title: "Projects",
                message: "Create and manage as many projects as you need.",
                freeValue: "Up to 3",
                proValue: "Unlimited"
            ),
            PurchaseFeature(
                id: "exports",
                systemImage: "square.and.arrow.up",
                title: "Exports",
                message: "Export polished images and reusable project output without weekly limits.",
                freeValue: "3 / week",
                proValue: "Unlimited"
            ),
            PurchaseFeature(
                id: "themes",
                systemImage: "paintpalette.fill",
                title: "Themes",
                message: "Use every AppFoundation theme and entitlement-aware preview.",
                freeValue: "1",
                proValue: "All"
            ),
            PurchaseFeature(
                id: "backup-history",
                systemImage: "archivebox.fill",
                title: "Backup history",
                message: "Keep complete validated backup history instead of only the latest package.",
                freeValue: "Latest",
                proValue: "Complete"
            ),
        ]
    )

    static let simulatedProducts: [PurchaseProduct] = [
        PurchaseProduct(
            id: monthlyProductID,
            displayName: "Demo Pro Monthly",
            description: "Monthly access to every Demo Pro feature.",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        ),
        PurchaseProduct(
            id: yearlyProductID,
            displayName: "Demo Pro Yearly",
            description: "Annual access to every Demo Pro feature.",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        ),
        PurchaseProduct(
            id: lifetimeProductID,
            displayName: "Demo Pro Lifetime",
            description: "Pay once and keep Demo Pro forever.",
            displayPrice: "$79.99",
            price: 79.99
        ),
    ]

    static let purchaseServiceMode = PurchaseServiceFactory.effectiveMode(
        for: PurchaseServiceMode.fromEnvironment(fallback: .simulated)
    )

    static let premiumExportFeature = PremiumFeature(
        id: "premium-export",
        title: "Premium export"
    )

    static let backupConfiguration = BackupPackageConfiguration(
        format: "com.hoangbkit.appfoundationdemo.backup",
        version: 1,
        appIdentifier: "com.hoangbkit.afdemo",
        fileExtension: "afdemo"
    )

    static let sharedSuiteName = "appfoundation.demo.shared-preview"

    static let sampleDeepLink = SharedDeepLink(
        scheme: "appfoundation-demo",
        host: "showcase",
        pathComponents: ["exports", "latest"],
        queryItems: [URLQueryItem(name: "source", value: "widget")]
    )

    static let onboardingPages: [FoundationOnboardingPage] = [
        FoundationOnboardingPage(
            id: "foundation",
            systemImage: "square.stack.3d.up.fill",
            eyebrow: "Reusable by design",
            title: "Ship your next app faster",
            message:
                "AppFoundation gives every project a polished starting point without coupling your business logic to one app."
        ),
        FoundationOnboardingPage(
            id: "purchases",
            systemImage: "crown.fill",
            eyebrow: "StoreKit 2",
            title: "Purchases that stay trustworthy",
            message:
                "Entitlements are verified from StoreKit, observed for changes, and exposed as simple observable state for SwiftUI."
        ),
        FoundationOnboardingPage(
            id: "infrastructure",
            systemImage: "shippingbox.fill",
            eyebrow: "Shared infrastructure",
            title: "Export, backup, widgets, and reminders",
            message:
                "Use the same safe building blocks across apps while each product keeps its own data models and visual identity."
        ),
    ]

    private static var activePreferredProductID: String {
        DemoSimulatedPlanConfiguration.load().preferredProductID
    }

    static var modernPaywall: PaywallConfiguration {
        PaywallConfiguration(
            title: "Unlock Demo Pro",
            subtitle: purchaseServiceMode == .simulated
                ? "This Debug build uses the in-process purchase simulator."
                : "Choose monthly, yearly, or lifetime access through StoreKit.",
            planTitle: "Demo Pro",
            planSubtitle: "Monthly, yearly, or lifetime access",
            preferredProductID: activePreferredProductID,
            highlightedProductID: activePreferredProductID,
            purchaseButtonTitle: "Unlock Demo Pro",
            privacyURL: URL(string: "https://example.com/privacy"),
            termsURL: URL(string: "https://example.com/terms")
        )
    }

    static let limitReachedUpsell = LimitReachedUpsellConfiguration(
        title: "Free limit reached",
        message: "The Demo free plan has reached its sample creation limit. Existing content remains available, or you can unlock Demo Pro for unlimited access.",
        symbolName: "shippingbox.and.arrow.backward.fill",
        unlockButtonTitle: "Unlock Demo Pro",
        comparisonAccessibilityLabel: "Demo Free and Demo Pro comparison"
    )

    static var legacyPaywall: FoundationPaywallConfiguration {
        FoundationPaywallConfiguration(
            title: "Make every app premium",
            subtitle: "Monthly, yearly, and lifetime plans in the gradient style.",
            features: purchases.features.map(FoundationPaywallFeature.init),
            purchaseButtonTitle: "Unlock Demo Pro",
            highlightedProductID: activePreferredProductID
        )
    }

    static var legacyClaudePaywall: FoundationPaywallConfiguration {
        FoundationPaywallConfiguration(
            title: "Get more Demo",
            subtitle: "Choose monthly, yearly, or lifetime access",
            features: purchases.features.map(FoundationPaywallFeature.init),
            purchaseButtonTitle: "Continue",
            highlightedProductID: activePreferredProductID,
            privacyURL: URL(string: "https://example.com/privacy"),
            termsURL: URL(string: "https://example.com/terms")
        )
    }

    static var settings: FoundationSettingsConfiguration {
        FoundationSettingsConfiguration(
            appName: "Demo",
            supportURL: URL(string: "https://github.com/hoangbkit"),
            privacyURL: URL(string: "https://example.com/privacy"),
            termsURL: URL(string: "https://example.com/terms"),
            shareURL: URL(string: "https://github.com/hoangbkit/AppFoundation"),
            proPlanConfiguration: ProPlanSettingsConfiguration(
                sectionTitle: "Demo Pro",
                activePlanTitle: "Demo Pro",
                unlockTitle: "Unlock Demo Pro"
            ),
            paywallConfiguration: modernPaywall
        )
    }
}
