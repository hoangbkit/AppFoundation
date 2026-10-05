#if canImport(StoreKit) && canImport(SwiftUI)
import XCTest
@testable import AppFoundation

@MainActor
final class ThemePurchaseBindingTests: XCTestCase {
    func testExpiryIsSavedBeforeRefreshReturnsAndSurvivesRepeatedRelaunches() async {
        let suite = "theme-expiry-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite)
        store.save(
            ThemeStoredState(
                selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "midnight"
            ))

        for launch in 0..<5 {
            // Reopen the actual store and recreate both owners, without directly
            // invoking ThemeManager synchronization as the old regression test did.
            let reopened = UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite)
            let themes = ThemeManager(stateStore: reopened)
            let purchases = makePurchases(service: ThemeBindingService())
            themes.bind(to: purchases)
            XCTAssertEqual(themes.effectiveTheme.id, launch == 0 ? "midnight" : "rose")
            XCTAssertTrue(themes.isCheckingProAccess)

            await purchases.refreshEntitlements()

            XCTAssertEqual(purchases.entitlementState, .inactive)
            XCTAssertFalse(purchases.hasPro)
            XCTAssertFalse(themes.isCheckingProAccess)
            XCTAssertEqual(themes.effectiveTheme.id, "rose")
            XCTAssertEqual(reopened.load().selectedThemeID, "midnight")
            XCTAssertEqual(reopened.load().committedThemeID, "rose")
            XCTAssertFalse(reopened.load().lastKnownHasPro)
        }
    }

    func testRenewalRestoresPreferenceButDoesNotUndoANewFreeChoice() async {
        let store = BindingThemeStore()
        store.state = ThemeStoredState(selectedThemeID: "midnight", committedThemeID: "rose")
        let service = ThemeBindingService()
        let purchases = makePurchases(service: service)
        let themes = ThemeManager(stateStore: store)
        themes.bind(to: purchases)
        await purchases.refreshEntitlements()
        service.records = [EntitlementRecord(productID: "pro")]
        await purchases.refreshEntitlements()
        XCTAssertEqual(themes.effectiveTheme.id, "midnight")
        XCTAssertEqual(store.state.committedThemeID, "midnight")

        _ = themes.select(themeID: "rose")
        service.records = []
        await purchases.refreshEntitlements()
        service.records = [EntitlementRecord(productID: "pro")]
        await purchases.refreshEntitlements()
        XCTAssertEqual(themes.effectiveTheme.id, "rose")
        XCTAssertEqual(store.state.selectedThemeID, "rose")
    }

    func testPurchaseDuringPreviewCommitsOnceWithoutAnIntermediateTheme() async {
        let store = BindingThemeStore()
        let service = ThemeBindingService()
        let purchases = makePurchases(service: service)
        var displayed: [String] = []
        let themes = ThemeManager(
            stateStore: store,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            stateDidChange: { displayed.append($0.effectiveTheme.id) }
        )
        themes.bind(to: purchases)
        await purchases.refreshEntitlements()
        _ = themes.select(themeID: "paper")
        displayed.removeAll()
        service.records = [EntitlementRecord(productID: "pro")]
        await purchases.refreshEntitlements()

        XCTAssertEqual(displayed, ["paper"])
        XCTAssertEqual(store.state.selectedThemeID, "paper")
        XCTAssertEqual(store.state.committedThemeID, "paper")
        XCTAssertNil(store.state.previewThemeID)
        XCTAssertNil(store.state.previewExpiresAt)
    }

    func testPurchasePendingCancellationAndFailureLeavePreviewUntouched() async {
        let store = BindingThemeStore()
        let service = ThemeBindingService()
        let purchases = makePurchases(service: service)
        let themes = ThemeManager(
            stateStore: store,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false)
        )
        themes.bind(to: purchases)
        await purchases.refreshEntitlements()
        _ = themes.select(themeID: "paper")
        let preview = store.state

        service.purchaseOutcome = .userCancelled
        await purchases.purchase(Self.product)
        XCTAssertEqual(store.state, preview)
        service.purchaseFailure = .verificationFailed
        await purchases.purchase(Self.product)
        XCTAssertEqual(store.state, preview)
        service.purchaseFailure = nil
        service.purchaseOutcome = .pending
        await purchases.purchase(Self.product)
        XCTAssertEqual(store.state, preview)
        XCTAssertFalse(purchases.hasPro)
    }

    func testBindingDoesNotWaitForTheProductCatalogAndCanChangeOwners() async {
        let store = BindingThemeStore()
        let firstService = ThemeBindingService()
        firstService.records = [EntitlementRecord(productID: "pro")]
        let first = makePurchases(service: firstService)
        let themes = ThemeManager(stateStore: store)
        themes.bind(to: first)
        await first.prepare()
        XCTAssertTrue(themes.hasPro)
        if case .failed = first.productLoadingState {
        } else {
            XCTFail("Catalog failure should not affect resolved access")
        }

        let second = makePurchases(service: ThemeBindingService())
        themes.bind(to: second)
        await second.refreshEntitlements()
        XCTAssertFalse(themes.hasPro)
        await first.refreshEntitlements()
        XCTAssertFalse(themes.hasPro, "The old purchase owner must no longer change the theme")
    }

    func testPreviewRelaunchKeepsOriginalDeadlineAndExpiresToBase() {
        let suite = "theme-preview-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite)
        let start = Date(timeIntervalSince1970: 1_000)
        let themes = ThemeManager(
            stateStore: store, hasPro: false,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            now: { start }
        )
        _ = themes.select(themeID: "paper")
        let reopened = UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite)
        let resumed = ThemeManager(
            stateStore: reopened,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            now: { start.addingTimeInterval(40) }
        )
        XCTAssertEqual(resumed.effectiveTheme.id, "paper")
        XCTAssertEqual(resumed.previewExpiresAt, start.addingTimeInterval(300))
        XCTAssertEqual(resumed.previewRemainingSeconds, 260)

        let expired = ThemeManager(stateStore: reopened, now: { start.addingTimeInterval(300) })
        XCTAssertEqual(expired.effectiveTheme.id, "rose")
        XCTAssertEqual(reopened.load().committedThemeID, "rose")
        XCTAssertNil(reopened.load().previewThemeID)
    }

    private func makePurchases(service: ThemeBindingService) -> PurchaseController {
        PurchaseController(configuration: PurchaseConfiguration(productIDs: ["pro"]), service: service)
    }

    private static let product = StoreProduct(
        id: "pro", displayName: "Pro", description: "Test", displayPrice: "$1", price: 1,
        type: .nonConsumable
    )
}

private final class BindingThemeStore: ThemeStateStoring, @unchecked Sendable {
    var state = ThemeStoredState()
    func load() -> ThemeStoredState { state }
    func save(_ state: ThemeStoredState) { self.state = state }
}

@MainActor
private final class ThemeBindingService: PurchaseServing {
    var records: [EntitlementRecord] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var purchaseFailure: PurchaseFailure?
    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        throw PurchaseFailure(code: .networkUnavailable, message: "Test catalog unavailable")
    }
    func purchase(productID: String) async throws -> PurchaseOutcome {
        if let purchaseFailure { throw purchaseFailure }
        return purchaseOutcome
    }
    func currentEntitlements() async -> [EntitlementRecord] { records }
    func entitlementUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func sync() async throws {}
}
#endif
