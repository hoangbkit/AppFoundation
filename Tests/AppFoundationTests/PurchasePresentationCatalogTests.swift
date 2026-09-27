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
        let legacy = FoundationPaywallConfiguration(
            title: "Pro",
            subtitle: "Unlock",
            privacyURL: URL(string: "https://example.com/privacy")!,
            termsURL: URL(string: "https://example.com/terms")!
        )
        let upsell = LimitReachedUpsellConfiguration(title: "Limit", message: "Upgrade")
        let celebration = FoundationProCelebrationConfiguration(
            title: "You’re Pro",
            message: "Thanks"
        )

        XCTAssertTrue(modern.features.isEmpty)
        XCTAssertTrue(legacy.features.isEmpty)
        XCTAssertTrue(legacy.showsRedeemCode)
        XCTAssertTrue(upsell.rows.isEmpty)
        XCTAssertTrue(celebration.rows.isEmpty)
        XCTAssertTrue(celebration.planTitle.isEmpty)
        XCTAssertTrue(celebration.statusMessage.isEmpty)
    }

    func testFoundationPaywallDefaultsToAppSpecificCopy() {
        let configuration = FoundationPaywallConfiguration(
            privacyURL: URL(string: "https://example.com/privacy")!,
            termsURL: URL(string: "https://example.com/terms")!
        )
        let appName = AppMetadata.current().name

        XCTAssertEqual(configuration.title, "\(appName) Pro")
        XCTAssertEqual(
            configuration.subtitle,
            "Unlock all Pro features,\nchoose the plan that fits you."
        )
    }
    @MainActor
    func testCanonicalPaywallAcceptsCommerceCallbacksAndRedeemConfiguration() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [product.id]),
            simulated: true,
            simulatedProducts: [product],
            simulatedOperationDelay: .milliseconds(0)
        )
        let configuration = FoundationPaywallConfiguration(
            privacyURL: URL(string: "https://example.com/privacy")!,
            termsURL: URL(string: "https://example.com/terms")!,
            showsRedeemCode: false
        )

        _ = ProPaywallView(
            purchases: manager,
            configuration: configuration,
            onPurchased: { _ in },
            onRestored: {},
            onClose: {}
        )

        XCTAssertFalse(configuration.showsRedeemCode)
    }

}
#endif
