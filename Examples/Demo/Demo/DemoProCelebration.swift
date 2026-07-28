import AppFoundation

extension DemoConfiguration {
    static func proCelebration(
        for _: PurchaseManager
    ) -> FoundationProCelebrationConfiguration {
        FoundationProCelebrationConfiguration(
            navigationTitle: "AF Pro",
            comparisonAccessibilityLabel: "Demo Free and Demo Pro comparison"
        )
    }
}
