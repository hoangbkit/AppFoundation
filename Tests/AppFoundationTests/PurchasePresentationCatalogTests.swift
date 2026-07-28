#if canImport(SwiftUI) && canImport(StoreKit)
import XCTest
@testable import AppFoundation

final class PurchasePresentationCatalogTests: XCTestCase {
    private let feature = PurchaseFeature(
        id: "exports",
        systemImage: "square.and.arrow.up",
        title: "Exports",
        message: "Export without limits.",
        freeValue: "3 / week",
        proValue: "Unlimited"
    )

    func testPurchaseFeatureConvertsToEveryPresentationModel() {
        let paywall = PaywallFeature(feature)
        let legacyPaywall = FoundationPaywallFeature(feature)
        let upsell = LimitReachedComparisonRow(feature)
        let celebration = FoundationProComparisonRow(feature)

        XCTAssertEqual(paywall.id, feature.id)
        XCTAssertEqual(paywall.message, feature.message)
        XCTAssertEqual(legacyPaywall.title, feature.title)
        XCTAssertEqual(upsell.freeValue, feature.freeValue)
        XCTAssertEqual(celebration.proValue, feature.proValue)
    }

    func testPurchaseSurfaceConfigurationsDefaultToCatalogFallback() {
        let modern = PaywallConfiguration(title: "Pro", subtitle: "Unlock")
        let legacy = FoundationPaywallConfiguration(title: "Pro", subtitle: "Unlock")
        let upsell = LimitReachedUpsellConfiguration(title: "Limit", message: "Upgrade")
        let celebration = FoundationProCelebrationConfiguration(
            title: "You’re Pro",
            message: "Thanks"
        )

        XCTAssertTrue(modern.features.isEmpty)
        XCTAssertTrue(legacy.features.isEmpty)
        XCTAssertTrue(upsell.rows.isEmpty)
        XCTAssertTrue(celebration.rows.isEmpty)
        XCTAssertTrue(celebration.planTitle.isEmpty)
        XCTAssertTrue(celebration.statusMessage.isEmpty)
    }

    func testFoundationPaywallDefaultsToAppSpecificCopy() {
        let configuration = FoundationPaywallConfiguration()
        let appName = AppMetadata.current().name

        XCTAssertEqual(configuration.title, "\(appName) Pro")
        XCTAssertEqual(
            configuration.subtitle,
            "Unlock all Pro features, choose the plan that fits you."
        )
    }
}
#endif
