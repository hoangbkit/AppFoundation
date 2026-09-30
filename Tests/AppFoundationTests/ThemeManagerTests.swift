#if canImport(Observation) && canImport(SwiftUI)
import XCTest
@testable import AppFoundation

@MainActor
final class ThemeManagerTests: XCTestCase {
    func testSelectingProThemeStartsMiLoveStylePreview() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        let manager = makeManager(clock: clock, store: store)

        let result = manager.select(themeID: "midnight")

        guard case .previewStarted(let theme, let expiry) = result else {
            return XCTFail("Expected preview")
        }
        XCTAssertEqual(theme.id, "midnight")
        XCTAssertEqual(expiry, clock.now.addingTimeInterval(300))
        XCTAssertEqual(manager.effectiveTheme.id, "midnight")
        XCTAssertEqual(store.state.previewThemeID, "midnight")
    }

    func testSwitchingProThemesPreservesPreviewExpiry() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = makeManager(clock: clock)

        _ = manager.select(themeID: "midnight")
        let originalExpiry = manager.previewExpiresAt
        clock.now = clock.now.addingTimeInterval(30)
        _ = manager.select(themeID: "paper")

        XCTAssertEqual(manager.previewExpiresAt, originalExpiry)
        XCTAssertEqual(manager.effectiveTheme.id, "paper")
    }

    func testUnlockingProPromotesActivePreview() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = makeManager(clock: clock)
        _ = manager.select(themeID: "lavender")

        manager.synchronizeProAccess(true)

        XCTAssertEqual(manager.selectedTheme.id, "lavender")
        XCTAssertEqual(manager.effectiveTheme.id, "lavender")
        XCTAssertFalse(manager.isPreviewActive)
    }

    func testLosingProPreservesSelectionButUsesFallback() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = makeManager(clock: clock, hasPro: true)
        _ = manager.select(themeID: "champagne")

        manager.synchronizeProAccess(false)

        XCTAssertEqual(manager.selectedTheme.id, "champagne")
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
    }

    func testRefreshExpiresPreviewAndRestoresFallback() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = makeManager(clock: clock)
        _ = manager.select(themeID: "paper")
        clock.now = clock.now.addingTimeInterval(301)

        manager.refresh()

        XCTAssertFalse(manager.isPreviewActive)
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
    }

    func testCheckingUsesLastKnownProAndKeepsManagerConsistent() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight",
            lastKnownHasPro: true
        )

        let manager = makeManager(clock: clock, store: store, hasPro: nil)

        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.effectiveTheme.id, "midnight")
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: .checking, hasPro: false).id,
            "midnight"
        )
        XCTAssertTrue(store.state.lastKnownHasPro)
    }

    func testCheckingUsesFreeFallbackWhenLastKnownAccessIsFree() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight",
            lastKnownHasPro: false
        )

        let manager = makeManager(clock: clock, store: store, hasPro: nil)

        XCTAssertFalse(manager.hasPro)
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: .checking, hasPro: false).id,
            "rose"
        )
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: .inactive, hasPro: false).id,
            "rose"
        )
    }

    func testCheckingPreservesValidFreeUserPreview() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "rose",
            previewThemeID: "midnight",
            previewExpiresAt: clock.now.addingTimeInterval(300),
            lastKnownHasPro: false
        )

        let manager = makeManager(clock: clock, store: store, hasPro: nil)

        XCTAssertEqual(manager.effectiveTheme.id, "midnight")
        XCTAssertTrue(manager.isPreviewActive)
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: .checking, hasPro: false).id,
            "midnight"
        )
    }

    func testCheckingDoesNotOverwriteLastKnownProAccess() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight",
            lastKnownHasPro: true
        )
        let manager = makeManager(clock: clock, store: store, hasPro: nil)

        manager.synchronizeProAccess(false, entitlementState: .checking)

        XCTAssertTrue(manager.hasPro)
        XCTAssertTrue(store.state.lastKnownHasPro)
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: .checking, hasPro: false).id,
            "midnight"
        )

        manager.synchronizeProAccess(false, entitlementState: .inactive)

        XCTAssertFalse(manager.hasPro)
        XCTAssertFalse(store.state.lastKnownHasPro)
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
    }

    func testLosingProStaysOnFallbackAcrossRelaunches() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        let manager = makeManager(clock: clock, store: store, hasPro: true)
        _ = manager.select(themeID: "champagne")

        manager.synchronizeProAccess(false, entitlementState: .inactive)

        XCTAssertEqual(store.state.selectedThemeID, "champagne")
        XCTAssertFalse(store.state.lastKnownHasPro)
        XCTAssertEqual(manager.effectiveTheme.id, "rose")

        let relaunched = makeManager(clock: clock, store: store, hasPro: nil)
        XCTAssertFalse(relaunched.hasPro)
        XCTAssertEqual(relaunched.effectiveTheme.id, "rose")
        XCTAssertEqual(
            relaunched.effectiveTheme(entitlementState: .checking, hasPro: false).id,
            "rose"
        )
    }

    func testUnlockingDuringPreviewDoesNotBounceThroughSelectedFreeTheme() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = makeManager(clock: clock)
        _ = manager.select(themeID: "lavender")
        let active = EntitlementState.active(
            EntitlementSnapshot(
                activeProductIDs: Set(["pro"]),
                latestExpirationDate: nil
            )
        )

        XCTAssertEqual(manager.effectiveTheme.id, "lavender")
        XCTAssertEqual(
            manager.effectiveTheme(entitlementState: active, hasPro: true).id,
            "lavender"
        )

        manager.synchronizeProAccess(true, entitlementState: active)

        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.selectedTheme.id, "lavender")
        XCTAssertEqual(manager.effectiveTheme.id, "lavender")
        XCTAssertFalse(manager.isPreviewActive)
    }

    func testRefreshFromPersistenceCannotRewriteResolvedAccessHistory() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight",
            lastKnownHasPro: true
        )
        let manager = makeManager(clock: clock, store: store, hasPro: nil)

        store.state = ThemeStoredState(
            selectedThemeID: "rose",
            lastKnownHasPro: false
        )
        manager.refreshFromPersistence()

        XCTAssertTrue(manager.hasPro)
        XCTAssertTrue(manager.storedState.lastKnownHasPro)
        XCTAssertTrue(store.state.lastKnownHasPro)
        XCTAssertEqual(manager.selectedTheme.id, "rose")
    }

    private func makeManager(
        clock: TestClock,
        store: MemoryThemeStore = MemoryThemeStore(),
        hasPro: Bool? = false
    ) -> ThemeManager {
        ThemeManager(
            stateStore: store,
            hasPro: hasPro,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            now: { clock.now }
        )
    }
}

private final class MemoryThemeStore: ThemeStateStoring, @unchecked Sendable {
    var state = ThemeStoredState()

    func load() -> ThemeStoredState { state }
    func save(_ state: ThemeStoredState) { self.state = state }
}

@MainActor
private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

#endif
