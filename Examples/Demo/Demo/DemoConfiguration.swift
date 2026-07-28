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
        preferredProductID: lifetimeProductID,
        features: DemoPurchaseFeatureCatalog.features
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
        message: "The Demo free plan has reached its sample limit. Existing work remains available, or you can unlock Demo Pro for the complete AppFoundation showcase.",
        symbolName: "shippingbox.and.arrow.backward.fill",
        comparisonTitle: "Demo Free vs Demo Pro",
        comparisonSubtitle: "Unlock the complete component, export, theme, widget, and backup experience.",
        unlockButtonTitle: "Unlock Demo Pro",
        comparisonAccessibilityLabel: "Demo Free and Demo Pro feature comparison"
    )

    static var legacyPaywall: FoundationPaywallConfiguration {
        FoundationPaywallConfiguration(
            title: "Make every app premium",
            subtitle: "Monthly, yearly, and lifetime plans in the gradient style.",
            purchaseButtonTitle: "Unlock Demo Pro",
            highlightedProductID: activePreferredProductID
        )
    }

    static var legacyClaudePaywall: FoundationPaywallConfiguration {
        FoundationPaywallConfiguration(
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
