import AppFoundation
import SwiftUI
import UIKit
import XCTest

@MainActor
final class DemoThemeLaunchTests: XCTestCase {
    func testPurchaseAwareModifierCommitsExpiryAndRelaunchStartsFree() async throws {
        let suite = "demo-theme-launch-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite).save(
            ThemeStoredState(
                selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "midnight"
            )
        )

        for launch in 0..<3 {
            let store = UserDefaultsThemeStateStore(storageKey: "theme", suiteName: suite)
            let themes = ThemeManager(stateStore: store)
            let service = DemoThemePurchaseService()
            let purchases = PurchaseManager(
                configuration: PurchaseConfiguration(productIDs: ["theme-test-pro"]), service: service
            )
            var rendered: [String] = []
            let root = ThemeRenderProbe { rendered.append($0) }
                .appFoundationTheme(themes, purchaseManager: purchases)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = UIHostingController(rootView: root)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            try await eventually { !rendered.isEmpty }
            // Allow the root's initial binding effect to finish before the service resolves.
            try await Task.sleep(for: .milliseconds(20))
            XCTAssertEqual(rendered.first, launch == 0 ? "midnight" : "rose")
            await purchases.refreshEntitlements()
            XCTAssertEqual(store.load().committedThemeID, "rose")
            XCTAssertEqual(store.load().selectedThemeID, "midnight")
            XCTAssertFalse(store.load().lastKnownHasPro)
            try await eventually { rendered.last == "rose" }
            if launch > 0 { XCTAssertTrue(rendered.allSatisfy { $0 == "rose" }) }

            // Unmounting the UI must not sever the lifetime purchase binding.
            window.rootViewController = nil
            service.records = [EntitlementRecord(productID: "theme-test-pro")]
            await purchases.refreshEntitlements()
            XCTAssertEqual(store.load().committedThemeID, "midnight")
            service.records = []
            await purchases.refreshEntitlements()
            XCTAssertEqual(store.load().committedThemeID, "rose")
        }
    }

    private func eventually(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("The hosted theme did not update within three seconds")
    }
}

private struct ThemeRenderProbe: View {
    @Environment(\.appFoundationTheme) private var theme
    let didRender: @MainActor (String) -> Void
    var body: some View {
        Text(theme.title)
            .onChange(of: theme.id, initial: true) { _, id in didRender(id) }
    }
}

@MainActor
private final class DemoThemePurchaseService: PurchaseServing {
    var records: [EntitlementRecord] = []
    func products(for identifiers: [String]) async throws -> [StoreProduct] { [] }
    func purchase(productID: String) async throws -> PurchaseOutcome { .userCancelled }
    func currentEntitlements() async -> [EntitlementRecord] { records }
    func entitlementUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func sync() async throws {}
}
