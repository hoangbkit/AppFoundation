import AppFoundation
import SwiftUI

@MainActor
enum DemoConfiguration {
    static let weeklyProductID = "com.hoangbkit.appfoundationdemo.pro.weekly"
    static let monthlyProductID = "com.hoangbkit.appfoundationdemo.pro.monthly"
    static let yearlyProductID = "com.hoangbkit.appfoundationdemo.pro.yearly"
    static let lifetimeProductID = "com.hoangbkit.appfoundationdemo.pro.lifetime"

    static let purchases = PurchaseConfiguration(
        productIDs: [
            weeklyProductID,
            monthlyProductID,
            yearlyProductID,
            lifetimeProductID,
        ],
        preferredProductID: yearlyProductID
    )

    static let simulatedProducts: [PurchaseProduct] = [
        PurchaseProduct(
            id: weeklyProductID,
            displayName: "Demo Pro Weekly",
            description: "Weekly access to every Demo Pro feature.",
            displayPrice: "$1.99",
            price: 1.99,
            subscriptionPeriod: .init(value: 1, unit: .week)
        ),
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
            description: "Permanent access with one purchase.",
            displayPrice: "$79.99",
            price: 79.99
        ),
    ]

    static let purchaseServiceMode = PurchaseServiceFactory.effectiveMode(
        for: PurchaseServiceMode.fromEnvironment(fallback: .live)
    )

    static let premiumExportFeature = PremiumFeature(
        id: "premium-export",
        title: "Premium export"
    )

    static let backupConfiguration = BackupPackageConfiguration(
        format: "com.hoangbkit.appfoundationdemo.backup",
        version: 1,
        appIdentifier: "com.hoangbkit.appfoundationdemo",
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

    static let modernPaywall = PaywallConfiguration(
        title: "Unlock Demo Pro",
        subtitle: purchaseServiceMode == .simulated
            ? "This Debug build uses the in-process purchase simulator."
            : "Choose weekly, monthly, yearly, or lifetime access through StoreKit.",
        planTitle: "Demo Pro",
        planSubtitle: "Subscriptions or one-time lifetime access",
        features: [
            PaywallFeature(
                id: "exports",
                systemImage: "square.and.arrow.up",
                title: "Premium exports",
                message: "Exercise image rendering, rounded PNG output, and sharing."
            ),
            PaywallFeature(
                id: "backups",
                systemImage: "archivebox",
                title: "Validated backups",
                message: "Create and verify versioned packages with assets and checksums."
            ),
            PaywallFeature(
                id: "themes",
                systemImage: "paintpalette",
                title: "Pro themes",
                message: "Try the existing reusable theme preview and entitlement flow."
            ),
        ],
        preferredProductID: purchases.preferredProductID,
        highlightedProductID: yearlyProductID,
        purchaseButtonTitle: "Unlock Demo Pro",
        privacyURL: URL(string: "https://example.com/privacy"),
        termsURL: URL(string: "https://example.com/terms")
    )

    static let legacyPaywall = FoundationPaywallConfiguration(
        title: "Make every app premium",
        subtitle: "Weekly, monthly, yearly, and lifetime plans in the gradient style.",
        features: [
            FoundationPaywallFeature(
                id: "storekit",
                systemImage: "checkmark.shield.fill",
                title: "Verified entitlements",
                message: "No UserDefaults boolean as the source of truth."
            ),
            FoundationPaywallFeature(
                id: "lifecycle",
                systemImage: "arrow.triangle.2.circlepath",
                title: "Automatic refresh",
                message: "Refreshes at launch, after transactions, restores, and app activation."
            ),
        ],
        purchaseButtonTitle: "Unlock Demo Pro",
        highlightedProductID: yearlyProductID
    )

    static let legacyClaudePaywall = FoundationPaywallConfiguration(
        title: "Get more Demo",
        subtitle: "Compare all recurring options with lifetime access",
        features: [
            FoundationPaywallFeature(
                id: "pro-features",
                systemImage: "checkmark",
                title: "Pro",
                message: "Unlock every Pro feature in Demo"
            ),
            FoundationPaywallFeature(
                id: "updates",
                systemImage: "checkmark",
                title: "Updates",
                message: "Priority access to new updates"
            ),
        ],
        purchaseButtonTitle: "Get Pro plan",
        highlightedProductID: yearlyProductID,
        privacyURL: URL(string: "https://example.com/privacy"),
        termsURL: URL(string: "https://example.com/terms")
    )

    static let settings = FoundationSettingsConfiguration(
        appName: "Demo",
        supportURL: URL(string: "https://github.com/hoangbkit"),
        privacyURL: URL(string: "https://example.com/privacy"),
        termsURL: URL(string: "https://example.com/terms"),
        shareURL: URL(string: "https://github.com/hoangbkit/AppFoundation")
    )
}