import AppFoundation

extension DemoConfiguration {
    static func proCelebration(
        for purchases: PurchaseManager
    ) -> FoundationProCelebrationConfiguration {
        FoundationProCelebrationConfiguration(
            navigationTitle: "AF Pro",
            title: "You’re an AF Pro",
            message: "Thanks for supporting AppFoundation and unlocking the complete Demo experience.",
            planTitle: activePlanTitle(in: purchases),
            statusMessage: proStatusMessage(for: purchases),
            rows: [
                FoundationProComparisonRow(
                    feature: "Projects",
                    freeValue: "Up to 3",
                    proValue: "Unlimited"
                ),
                FoundationProComparisonRow(
                    feature: "Exports",
                    freeValue: "3 / week",
                    proValue: "Unlimited"
                ),
                FoundationProComparisonRow(
                    feature: "Themes",
                    freeValue: "1",
                    proValue: "All"
                ),
                FoundationProComparisonRow(
                    feature: "Backup history",
                    freeValue: "Latest",
                    proValue: "Complete"
                ),
            ],
            comparisonAccessibilityLabel: "Demo Free and Demo Pro comparison"
        )
    }

    private static func activePlanTitle(in purchases: PurchaseManager) -> String {
        guard case .active(let snapshot) = purchases.entitlementState else {
            return "Demo Pro"
        }

        return purchases.products.first { product in
            snapshot.activeProductIDs.contains(product.id)
        }?.displayName ?? "Demo Pro"
    }

    private static func proStatusMessage(for purchases: PurchaseManager) -> String {
        #if DEBUG
        if purchases.isUsingSimulatedPurchases {
            return "Pro is active through the local purchase simulator."
        }
        #endif

        return "Your purchase is active and every Demo Pro feature is unlocked."
    }
}
