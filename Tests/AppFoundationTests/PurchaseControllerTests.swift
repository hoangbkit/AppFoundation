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

    func testRestoreTimesOutWhenSyncNeverAnswers() async throws {
        let service = MockPurchaseService()
        service.hangSync = true
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let task = Task { await controller.restorePurchases(timeout: .milliseconds(150)) }
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(controller.activity, .failed(.timeout))
        XCTAssertEqual(await task.value, .failed(.timeout))
        XCTAssertEqual(service.syncCount, 1)

        // The abandoned sync drains in the background; settle it so the test ends
        // without a leaked continuation.
        service.resumeHangingSync()
        try await Task.sleep(for: .milliseconds(50))
    }

    func testCancelRestoreStopsWaitingAndEndsSilently() async throws {
        let service = MockPurchaseService()
        service.hangSync = true
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let task = Task { await controller.restorePurchases() }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(controller.activity, .restoring)

        controller.cancelRestore()

        XCTAssertEqual(controller.activity, .idle)

        service.resumeHangingSync()
        let outcome = await task.value
        XCTAssertEqual(outcome, .failed(.userCancelled))
        XCTAssertEqual(controller.activity, .idle)
    }

    func testRestoreExposesIsRestoringDistinctFromIsPurchasing() async throws {
        let service = MockPurchaseService()
        service.hangSync = true
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        XCTAssertFalse(controller.isRestoring)
        XCTAssertFalse(controller.isPurchasing)

        let task = Task { await controller.restorePurchases(timeout: .seconds(2)) }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(controller.isRestoring)
        XCTAssertFalse(controller.isPurchasing)
        XCTAssertTrue(controller.isBusy)

        service.resumeHangingSync()
        _ = await task.value

        XCTAssertFalse(controller.isRestoring)
        XCTAssertEqual(controller.activity, .idle)
    }

    func testConcurrentRestoreCallsJoinASingleAttempt() async {
        let service = MockPurchaseService()
        service.entitlements = [EntitlementRecord(productID: Self.monthly.id)]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        async let first = controller.restorePurchases()
        async let second = controller.restorePurchases()

        let outcomes = await [first, second]

        XCTAssertEqual(outcomes, [.restored, .restored])
        XCTAssertEqual(service.syncCount, 1)
    }

    func testCancelledSyncEndsIdleWithoutPoisoningActivity() async {
        let service = MockPurchaseService()
        service.syncFailure = .userCancelled
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await controller.restorePurchases()

        XCTAssertEqual(outcome, .failed(.userCancelled))
        XCTAssertEqual(controller.activity, .idle)
    }

    func testTransactionUpdateDoesNotClearInFlightRestore() async throws {
        let service = MockPurchaseService()
        service.hangSync = true
        service.productsResult = [Self.monthly]
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.prepare()

        let task = Task { await controller.restorePurchases(timeout: .seconds(5)) }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(controller.activity, .restoring)

        service.yieldEntitlementUpdate()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(controller.activity, .restoring)

        service.resumeHangingSync()
        let outcome = await task.value
        XCTAssertEqual(outcome, .nothingToRestore)
        XCTAssertEqual(controller.activity, .idle)
    }

    func testTransactionUpdateStillClearsPendingAskToBuy() async throws {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .pending
        let controller = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await controller.prepare()

        await controller.purchase(Self.monthly)
        XCTAssertEqual(controller.activity, .pending(productID: Self.monthly.id))

        service.yieldEntitlementUpdate()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(controller.activity, .idle)
    }

    func testScreenshotPreviewPreloadsProductsSynchronously() {
        let configuration = PurchaseConfiguration(
            productIDs: [Self.monthly.id, Self.yearly.id],
            preferredProductID: Self.yearly.id
        )

        let controller = PurchaseController.screenshotPreview(
            configuration: configuration,
            products: [Self.yearly, Self.monthly]
        )

        XCTAssertEqual(controller.products, [Self.monthly, Self.yearly])
        XCTAssertEqual(controller.productLoadingState, .loaded)
        XCTAssertEqual(controller.preferredProduct?.id, Self.yearly.id)
        XCTAssertFalse(controller.isEntitled)
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

    private static let yearly = StoreProduct(
        id: "pro.yearly",
        displayName: "Yearly",
        description: "Yearly access",
        displayPrice: "$39.99",
        price: 39.99,
        subscriptionPeriod: .init(value: 1, unit: .year)
    )
}

@MainActor
final class MockPurchaseService: PurchaseServing {
    var productsResult: [StoreProduct] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var entitlements: [EntitlementRecord] = []
    var productLoadCount = 0
    var syncCount = 0
    var syncFailure: PurchaseFailure?
    /// When true, `sync()` blocks until `resumeHangingSync()` is called — a stand-in
    /// for an App Store that never answers.
    var hangSync = false

    private var syncContinuation: CheckedContinuation<Void, Error>?
    private var updateContinuations: [AsyncStream<Void>.Continuation] = []

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
            self.updateContinuations.append(continuation)
        }
    }

    func yieldEntitlementUpdate() {
        for continuation in updateContinuations {
            continuation.yield()
        }
    }

    func sync() async throws {
        syncCount += 1
        if let syncFailure {
            throw syncFailure
        }
        if hangSync {
            try await withCheckedThrowingContinuation { continuation in
                syncContinuation = continuation
            }
        }
    }

    func resumeHangingSync() {
        syncContinuation?.resume(returning: ())
        syncContinuation = nil
    }
}
#endif
