import AppFoundation

extension DemoConfiguration {
    static func proCelebration(
        for _: PurchaseManager
    ) -> FoundationProCelebrationConfiguration {
        FoundationProCelebrationConfiguration(
            navigationTitle: "AF Pro",
            title: "You’re an AF Pro",
            message: "Thanks for supporting AppFoundation and unlocking the complete Demo experience.",
            comparisonAccessibilityLabel: "Demo Free and Demo Pro comparison"
        )
    }
}
