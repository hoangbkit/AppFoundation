import AppFoundation
import SwiftUI

@MainActor
enum DemoConfiguration {
    static let theme = FoundationTheme(
        primary: Color(red: 0.20, green: 0.35, blue: 0.98),
        secondary: Color(red: 0.82, green: 0.27, blue: 0.87)
    )

    static let purchases = PurchaseConfiguration(
        productIDs: [
            "com.hoangbkit.appfoundationdemo.pro.monthly",
            "com.hoangbkit.appfoundationdemo.pro.yearly",
        ],
        preferredProductID: "com.hoangbkit.appfoundationdemo.pro.yearly"
    )

    static let simulatedProducts: [StoreProduct] = [
        StoreProduct(
            id: "com.hoangbkit.appfoundationdemo.pro.monthly",
            displayName: "Demo Pro Monthly",
            description: "Monthly access to every Demo Pro feature.",
            displayPrice: "$2.99",
            price: 2.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        ),
        StoreProduct(
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
            id: "components",
            systemImage: "wand.and.stars",
            eyebrow: "Beautiful components",
            title: "A consistent design language",
            message:
                "Compose onboarding, paywalls, settings, cards, buttons, and backgrounds while keeping every app brandable."
        ),
    ]

    static let paywall = FoundationPaywallConfiguration(
        title: "Make every app premium",
        subtitle: purchaseServiceMode == .simulated
            ? "This Debug build uses AppFoundation's in-process purchase simulator."
            : "This sample uses StoreKit. Replace the product identifiers and copy for each real app.",
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
            FoundationPaywallFeature(
                id: "customizable",
                systemImage: "paintpalette.fill",
                title: "Fully brandable",
                message: "Change colors, benefits, legal links, and product ordering per app."
            ),
        ],
        purchaseButtonTitle: "Unlock Demo Pro",
        highlightedProductID: "com.hoangbkit.appfoundationdemo.pro.yearly",
        theme: theme
    )

    static let claudePaywall = FoundationPaywallConfiguration(
        title: "Get more Demo",
        subtitle: "Choose the plan that's right for you",
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
            FoundationPaywallFeature(
                id: "limits",
                systemImage: "checkmark",
                title: "Limits",
                message: "Remove usage limits"
            ),
        ],
        purchaseButtonTitle: "Get Pro plan",
        privacyURL: URL(string: "https://example.com/privacy"),
        termsURL: URL(string: "https://example.com/terms"),
        theme: FoundationTheme(
            primary: .black,
            secondary: .black
        )
    )

    static let settings = FoundationSettingsConfiguration(
        appName: "Demo",
        supportURL: URL(string: "https://github.com/hoangbkit"),
        shareURL: URL(string: "https://github.com/hoangbkit"),
        theme: theme
    )
}
