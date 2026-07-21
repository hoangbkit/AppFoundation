import AppFoundation
import SwiftUI

@MainActor
enum DemoConfiguration {
    static let purchases = PurchaseConfiguration(
        productIDs: [
            "com.hoangbkit.appfoundationdemo.pro.monthly",
            "com.hoangbkit.appfoundationdemo.pro.yearly",
        ],
        preferredProductID: "com.hoangbkit.appfoundationdemo.pro.yearly"
    )

    static let simulatedProducts: [PurchaseProduct] = [
        PurchaseProduct(
            id: "com.hoangbkit.appfoundationdemo.pro.monthly",
            displayName: "Demo Pro Monthly",
            description: "Monthly access to every Demo Pro feature.",
            displayPrice: "$2.99",
            price: 2.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        ),
        PurchaseProduct(
            id: "com.hoangbkit.appfoundationdemo.pro.yearly",
            displayName: "Demo Pro Yearly",
            description: "Annual access to every Demo Pro feature.",
            displayPrice: "$19.99",
            price: 19.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
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
            : "Choose monthly or yearly access through StoreKit.",
        planTitle: "Demo Pro",
        planSubtitle: "One entitlement for every premium showcase",
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
        purchaseButtonTitle: "Unlock Demo Pro",
        privacyURL: URL(string: "https://example.com/privacy"),
        termsURL: URL(string: "https://example.com/terms")
    )

    static let legacyPaywall = FoundationPaywallConfiguration(
        title: "Make every app premium",
        subtitle: "Gradient style following the currently selected app theme.",
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
        highlightedProductID: purchases.preferredProductID
    )

    static let legacyClaudePaywall = FoundationPaywallConfiguration(
        title: "Get more Demo",
        subtitle: "Compact style following the currently selected app theme",
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