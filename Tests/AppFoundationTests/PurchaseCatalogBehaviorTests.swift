#if canImport(StoreKit)
import XCTest
@testable import AppFoundation

@MainActor
final class PurchaseCatalogBehaviorTests: XCTestCase {
    func testPresentationRefreshReplacesCachedProductMetadata() async {
        let service = CatalogTestPurchaseService()
        service.productsResult = [Self.monthly]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.loadProducts()

        let refreshedMonthly = StoreProduct(
            id: Self.monthly.id,
            displayName: "Monthly",
            description: "Monthly access",
            displayPrice: "$5.99",
            price: 5.99,
            subscriptionPeriod: .init(value: 1, unit: .month),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 1, unit: .week),
                displayPrice: "Free",
                price: 0,
                isEligible: false
            )
        )
        service.productsResult = [refreshedMonthly]

        await controller.refreshProductsForPresentation()

        XCTAssertEqual(controller.products, [refreshedMonthly])
        XCTAssertEqual(controller.productLoadingState, .loaded)
        XCTAssertEqual(service.productLoadCount, 2)
    }

    func testPresentationRefreshKeepsCachedProductsWhenRefreshFails() async {
        let service = CatalogTestPurchaseService()
        service.productsResult = [Self.monthly]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                productLoadAttempts: 1
            ),
            service: service
        )

        await controller.loadProducts()
        service.productLoadingFailure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Offline"
        )

        await controller.refreshProductsForPresentation()

        XCTAssertEqual(controller.products, [Self.monthly])
        XCTAssertEqual(controller.productLoadingState, .loaded)
        XCTAssertEqual(service.productLoadCount, 2)
    }

    func testEntitlementProductsExcludeNonEntitledAndUnsupportedProducts() async {
        let bonus = StoreProduct(
            id: "bonus",
            displayName: "Bonus",
            description: "",
            displayPrice: "$1.99",
            price: 1.99
        )
        let credits = StoreProduct(
            id: "credits",
            displayName: "Credits",
            description: "",
            displayPrice: "$0.99",
            price: 0.99,
            type: .consumable
        )
        let service = CatalogTestPurchaseService()
        service.productsResult = [Self.monthly, bonus, credits]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, bonus.id, credits.id],
                entitledProductIDs: [Self.monthly.id, credits.id]
            ),
            service: service
        )

        await controller.loadProducts()

        XCTAssertEqual(controller.entitlementProducts.map(\.id), [Self.monthly.id])
        XCTAssertEqual(controller.preferredEntitlementProduct?.id, Self.monthly.id)
    }

    func testActiveProductPrefersLifetimeAndKeepsSubscriptionManageable() async {
        let service = CatalogTestPurchaseService()
        service.productsResult = [Self.monthly, Self.lifetime]
        service.entitlements = [
            EntitlementRecord(productID: Self.monthly.id),
            EntitlementRecord(productID: Self.lifetime.id)
        ]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, Self.lifetime.id]
            ),
            service: service
        )

        await controller.prepare()

        XCTAssertEqual(controller.activeProduct?.id, Self.lifetime.id)
        XCTAssertEqual(controller.activeSubscriptionProduct?.id, Self.monthly.id)
    }

    func testUnsupportedProductIsRejectedBeforePurchaseService() async {
        let consumable = StoreProduct(
            id: "credits",
            displayName: "Credits",
            description: "",
            displayPrice: "$0.99",
            price: 0.99,
            type: .consumable
        )
        let service = CatalogTestPurchaseService()
        service.productsResult = [consumable]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [consumable.id]),
            service: service
        )

        await controller.loadProducts()
        let outcome = await controller.purchase(consumable)

        XCTAssertNil(outcome)
        XCTAssertEqual(controller.activity, .failed(.productUnavailable))
        XCTAssertEqual(service.purchaseCount, 0)
    }

    func testPendingPurchaseBlocksAnotherPurchase() async {
        let service = CatalogTestPurchaseService()
        service.purchaseOutcome = .pending
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let first = await controller.purchase(Self.monthly)
        let second = await controller.purchase(Self.monthly)

        XCTAssertEqual(first, .pending)
        XCTAssertNil(second)
        XCTAssertTrue(controller.isPurchasePending)
        XCTAssertEqual(controller.pendingProductID, Self.monthly.id)
        XCTAssertEqual(service.purchaseCount, 1)
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly access",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )

    private static let lifetime = StoreProduct(
        id: "pro.lifetime",
        displayName: "Lifetime",
        description: "Lifetime access",
        displayPrice: "$79.99",
        price: 79.99
    )
}

@MainActor
private final class CatalogTestPurchaseService: PurchaseServing {
    var productsResult: [StoreProduct] = []
    var entitlements: [EntitlementRecord] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var productLoadingFailure: PurchaseFailure?
    var productLoadCount = 0
    var purchaseCount = 0

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        productLoadCount += 1
        if let productLoadingFailure { throw productLoadingFailure }
        return productsResult.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseCount += 1
        return purchaseOutcome
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        entitlements
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in continuation.finish() }
    }

    func sync() async throws {}
}
#endif
