#if canImport(SwiftUI) && canImport(StoreKit)
import XCTest
@testable import AppFoundation

@MainActor
final class RestorePurchasesModelTests: XCTestCase {
    private let configuration = RestorePurchasesRowConfiguration(
        timeout: .milliseconds(200),
        successDuration: .milliseconds(80),
        messageDuration: .milliseconds(80)
    )

    // MARK: - Outcomes

    func testRestoredShowsResultThenAutoClears() async throws {
        let (model, manager) = makeModel(
            entitlements: [EntitlementRecord(productID: Self.monthly.id)]
        )

        model.start(using: manager, configuration: configuration)
        XCTAssertEqual(model.phase, .restoring)

        try await waitUntil(model.phase != .restoring)
        XCTAssertEqual(model.phase, .result(.restored))
        XCTAssertTrue(manager.hasPro)

        try await waitUntil(model.phase != .result(.restored))
    }

    func testNothingToRestoreShowsInfoThenAutoClears() async throws {
        let (model, manager) = makeModel()

        model.start(using: manager, configuration: configuration)

        try await waitUntil(model.phase != .restoring)
        XCTAssertEqual(model.phase, .result(.nothingToRestore))
        XCTAssertEqual(manager.activity, .idle)

        try await waitUntil(model.phase == .idle)
    }

    func testFailureStaysScopedToTheSurface() async throws {
        let service = MockPurchaseService()
        service.syncFailure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Check your internet connection and try again."
        )
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        let model = RestorePurchasesRowModel()

        model.start(using: manager, configuration: configuration)

        try await waitUntil(model.phase != .restoring)
        guard case .result(.failure(let failure)) = model.phase else {
            return XCTFail("Expected failure result, got \(model.phase)")
        }
        XCTAssertEqual(failure.code, .networkUnavailable)
        // The failure is cleared on the shared controller so other surfaces bound
        // to `activity` never replay it.
        XCTAssertEqual(manager.activity, .idle)

        try await waitUntil(model.phase == .idle)
    }

    func testUserCancelledEndsSilentlyWithoutMessage() async throws {
        let service = MockPurchaseService()
        service.syncFailure = .userCancelled
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        let model = RestorePurchasesRowModel()

        model.start(using: manager, configuration: configuration)

        try await waitUntil(!model.hasLocalAttemptInFlight)
        XCTAssertEqual(model.phase, .idle)
    }

    // MARK: - Interaction

    func testRetappingWhileMessageVisibleStartsFreshAttempt() async throws {
        let service = MockPurchaseService()
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        let model = RestorePurchasesRowModel()

        model.start(using: manager, configuration: configuration)
        try await waitUntil(model.phase == .result(.nothingToRestore))

        model.start(using: manager, configuration: configuration)
        XCTAssertEqual(model.phase, .restoring)

        try await waitUntil(model.phase == .result(.nothingToRestore))
        XCTAssertEqual(service.syncCount, 2)
    }

    func testCancelImmediatelyReturnsToIdle() throws {
        let service = MockPurchaseService()
        service.hangSync = true
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        let model = RestorePurchasesRowModel()

        model.start(using: manager, configuration: configuration)
        XCTAssertEqual(model.phase, .restoring)

        model.cancel(using: manager)

        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.hasLocalAttemptInFlight)
        XCTAssertEqual(manager.activity, .idle)

        service.resumeHangingSync()
    }

    // MARK: - Reconciliation

    func testReconcileDropsOrphanedRestoringState() {
        let (_, manager) = makeModel()
        let model = RestorePurchasesRowModel()

        model._debugSetRestoring(localAttemptInFlight: false)
        model.reconcile(using: manager)

        XCTAssertEqual(model.phase, .idle)
    }

    func testReconcileKeepsRestoringWhileManagerIsBusy() throws {
        let service = MockPurchaseService()
        service.hangSync = true
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        let model = RestorePurchasesRowModel()

        Task { await manager.restorePurchases() }
        guard spinUntil(manager.isBusy) else {
            return XCTFail("Restore never became busy")
        }

        model._debugSetRestoring(localAttemptInFlight: false)
        model.reconcile(using: manager)

        XCTAssertEqual(model.phase, .restoring)

        manager.cancelRestore()
        service.resumeHangingSync()
    }

    // MARK: - Fixtures

    private func makeModel(
        entitlements: [EntitlementRecord] = []
    ) -> (model: RestorePurchasesRowModel, manager: PurchaseController) {
        let service = MockPurchaseService()
        service.entitlements = entitlements
        let manager = PurchaseController(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )
        return (RestorePurchasesRowModel(), manager)
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly access",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )

    // MARK: - Polling helpers

    /// Polls `condition` on the main actor until it holds or times out.
    private func waitUntil(
        _ condition: @autoclosure () -> Bool,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Condition not met within \(timeout)s", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func spinUntil(_ condition: () -> Bool, timeout: TimeInterval = 2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}
#endif
