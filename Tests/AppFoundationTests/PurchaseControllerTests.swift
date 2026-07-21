#if canImport(StoreKit)
import XCTest
@testable import AppFoundation

@MainActor
final class PurchaseControllerTests: XCTestCase {
    func testPrepareLoadsProductsAndEvaluatesEntitlement() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.entitlements = [EntitlementRecord(productID: Self.monthly.id)]

        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.prepare()

        XCTAssertEqual(controller.products, [Self.monthly])
        XCTAssertEqual(controller.productLoadingState, .loaded)
        XCTAssertTrue(controller.isEntitled)
        XCTAssertEqual(service.productLoadCount, 1)
    }

    func testPurchaseRefreshesEntitlementAfterSuccess() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .success(EntitlementRecord(productID: Self.monthly.id))

        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.loadProducts()
        service.entitlements = [EntitlementRecord(productID: Self.monthly.id)]
        await controller.purchase(Self.monthly)

        XCTAssertTrue(controller.isEntitled)
        XCTAssertEqual(controller.activity, .idle)
    }

    func testPendingPurchaseDoesNotUnlockEntitlement() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .pending

        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.purchase(Self.monthly)

        XCTAssertEqual(controller.activity, .pending(productID: Self.monthly.id))
        XCTAssertFalse(controller.isEntitled)
    }

    func testRestoreReportsNothingWhenNoEntitlementExists() async {
        let service = MockPurchaseService()
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await controller.restorePurchases()

        XCTAssertEqual(outcome, .nothingToRestore)
        XCTAssertEqual(service.syncCount, 1)
        XCTAssertEqual(controller.activity, .idle)
    }

    func testRestoreReturnsFailureWhenSyncThrows() async {
        let service = MockPurchaseService()
        service.syncFailure = .unknown
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await controller.restorePurchases()

        XCTAssertEqual(outcome, .failed(.unknown))
        XCTAssertEqual(controller.activity, .failed(.unknown))
    }

    #if DEBUG
    func testSimulationDefaultsToDisabled() {
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            simulatedProducts: [Self.monthly]
        )

        XCTAssertFalse(controller.isUsingSimulatedPurchases)
    }

    func testSimulationCanBeConfiguredAtInitialization() async {
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            simulated: true,
            simulatedProducts: [Self.monthly],
            simulatedOperationDelay: .milliseconds(0)
        )

        await controller.prepare()

        XCTAssertTrue(controller.isUsingSimulatedPurchases)
        XCTAssertEqual(controller.products, [Self.monthly])
    }

    func testSimulationCanBeEnabledAtRuntime() async {
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            simulatedProducts: [Self.monthly],
            simulatedOperationDelay: .milliseconds(0)
        )

        await controller.setSimulatedPurchasesEnabled(true)

        XCTAssertTrue(controller.isUsingSimulatedPurchases)
        XCTAssertEqual(controller.products, [Self.monthly])
        XCTAssertFalse(controller.isEntitled)
    }
    #endif

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly access",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )
}

@MainActor
private final class MockPurchaseService: PurchaseServing {
    var productsResult: [StoreProduct] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var entitlements: [EntitlementRecord] = []
    var productLoadCount = 0
    var syncCount = 0
    var syncFailure: PurchaseFailure?

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        productLoadCount += 1
        return productsResult.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseOutcome
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        entitlements
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func sync() async throws {
        syncCount += 1
        if let syncFailure {
            throw syncFailure
        }
    }
}
#endif