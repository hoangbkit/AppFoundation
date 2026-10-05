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
        XCTAssertEqual(store.state.selectedThemeID, "rose")
        XCTAssertEqual(store.state.committedThemeID, "rose")
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
        XCTAssertEqual(store.state.committedThemeID, "rose")
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

    func testCheckingReaderAdoptsNewerCommittedStateWithoutRewritingAccessHistory() {
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

        XCTAssertFalse(manager.hasPro)
        XCTAssertFalse(manager.storedState.lastKnownHasPro)
        XCTAssertFalse(store.state.lastKnownHasPro)
        XCTAssertEqual(manager.selectedTheme.id, "rose")
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
        XCTAssertNil(store.state.committedThemeID)
    }

    func testPreviewPromotionDisabledUsesTheSameThemeBeforeAndAfterSynchronization() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = ThemeManager(
            stateStore: MemoryThemeStore(),
            hasPro: false,
            previewBehavior: ThemePreviewBehavior(
                promotesPreviewOnProUnlock: false, schedulesAutomaticExpiration: false
            ),
            now: { clock.now }
        )
        _ = manager.select(themeID: "paper")

        let projected = manager.effectiveTheme(entitlementState: .inactive, hasPro: true)
        manager.synchronizeProAccess(true, entitlementState: .inactive)

        XCTAssertEqual(projected.id, "rose")
        XCTAssertEqual(manager.effectiveTheme, projected)
        XCTAssertEqual(manager.committedTheme.id, "rose")
        XCTAssertFalse(manager.isPreviewActive)
    }

    func testProPreferenceDoesNotReplaceCommittedFreeBaseWhileChecking() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "rose"
        )
        let manager = makeManager(clock: clock, store: store, hasPro: nil)
        XCTAssertEqual(manager.selectedTheme.id, "midnight")
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
        XCTAssertTrue(manager.isCheckingProAccess)
        XCTAssertFalse(manager.canPreview(FoundationThemes.paper))
        XCTAssertEqual(manager.select(themeID: "paper"), .requiresPro(FoundationThemes.paper))
        XCTAssertEqual(manager.selectedTheme.id, "midnight")
    }

    func testExplicitFreeChoiceWhileCheckingWinsOverOldProPreferenceOnRenewal() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "midnight"
        )
        let manager = makeManager(clock: clock, store: store, hasPro: nil)
        _ = manager.select(themeID: "rose")
        manager.synchronizeProAccess(true)
        XCTAssertEqual(manager.selectedTheme.id, "rose")
        XCTAssertEqual(manager.committedTheme.id, "rose")
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
    }

    func testDisabledPreviewsAreClearedOnRelaunch() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "rose", previewThemeID: "paper",
            previewExpiresAt: clock.now.addingTimeInterval(50), committedThemeID: "rose"
        )
        let manager = ThemeManager(stateStore: store, previewBehavior: .disabled, now: { clock.now })
        XCTAssertEqual(manager.effectiveTheme.id, "rose")
        XCTAssertNil(store.state.previewThemeID)
    }

    func testEndingAndExpiringPreviewNeverCommitIt() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        let manager = makeManager(clock: clock, store: store)
        _ = manager.select(themeID: "paper")
        manager.endPreview()
        XCTAssertEqual(manager.committedTheme.id, "rose")
        _ = manager.select(themeID: "midnight")
        clock.now = clock.now.addingTimeInterval(300)
        manager.refresh()
        XCTAssertNil(store.state.previewThemeID)
        XCTAssertEqual(store.state.committedThemeID, "rose")
        XCTAssertEqual(store.state.selectedThemeID, "rose")
    }

    func testSwitchingPreviewCanRestartDurationWhenConfigured() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let manager = ThemeManager(
            stateStore: MemoryThemeStore(),
            hasPro: false,
            previewBehavior: ThemePreviewBehavior(
                preservesExpiryWhenSwitchingThemes: false, schedulesAutomaticExpiration: false
            ),
            now: { clock.now }
        )
        _ = manager.select(themeID: "paper")
        clock.now = clock.now.addingTimeInterval(40)
        _ = manager.select(themeID: "midnight")
        XCTAssertEqual(manager.previewExpiresAt, clock.now.addingTimeInterval(300))
        XCTAssertEqual(manager.committedTheme.id, "rose")
    }

    func testRemovedThemesAreNormalizedAndResetClearsPreferenceAndPreview() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "removed", previewThemeID: "removed",
            previewExpiresAt: clock.now.addingTimeInterval(50), committedThemeID: "removed"
        )
        let manager = makeManager(clock: clock, store: store)
        XCTAssertEqual(manager.selectedTheme.id, "rose")
        XCTAssertEqual(manager.committedTheme.id, "rose")
        XCTAssertFalse(manager.isPreviewActive)
        manager.synchronizeProAccess(true)
        _ = manager.select(themeID: "midnight")
        manager.reset()
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(store.state.selectedThemeID, "rose")
        XCTAssertEqual(store.state.committedThemeID, "rose")
        XCTAssertNil(store.state.previewThemeID)
    }

    func testPreviewReturnsToCustomFreeBaseAndUnlockRespectsPromotionSetting() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let customFree = FoundationThemes.paper.withAccess(.free)
        let catalog = ThemeCatalog.foundationDefaults.replacing(customFree)
        let manager = ThemeManager(
            catalog: catalog, stateStore: MemoryThemeStore(), hasPro: false,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            now: { clock.now }
        )
        _ = manager.select(customFree)
        _ = manager.select(themeID: "midnight")
        XCTAssertEqual(manager.committedTheme.id, "paper")
        manager.endPreview()
        XCTAssertEqual(manager.effectiveTheme.id, "paper")
        _ = manager.select(themeID: "midnight")
        clock.now = clock.now.addingTimeInterval(300)
        manager.refresh()
        XCTAssertEqual(manager.effectiveTheme.id, "paper")

        for promotes in [false, true] {
            let store = MemoryThemeStore()
            store.state = ThemeStoredState(selectedThemeID: "midnight", committedThemeID: "rose")
            let renewing = ThemeManager(
                stateStore: store, hasPro: false,
                previewBehavior: ThemePreviewBehavior(
                    promotesPreviewOnProUnlock: promotes, schedulesAutomaticExpiration: false
                ),
                now: { clock.now }
            )
            _ = renewing.select(themeID: "paper")
            renewing.synchronizeProAccess(true)
            XCTAssertEqual(renewing.effectiveTheme.id, promotes ? "paper" : "midnight")
            XCTAssertEqual(store.state.committedThemeID, store.state.selectedThemeID)
            XCTAssertNil(store.state.previewThemeID)
        }
    }

    func testZeroDurationAndInvalidPreviewCannotChangeCommittedBase() {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let noPreview = FoundationThemes.paper.withPreviewDuration(0)
        let store = MemoryThemeStore()
        store.state = ThemeStoredState(
            selectedThemeID: "rose", previewThemeID: "midnight", committedThemeID: "rose"
        )
        let manager = ThemeManager(
            catalog: ThemeCatalog.foundationDefaults.replacing(noPreview),
            stateStore: store, hasPro: false,
            previewBehavior: ThemePreviewBehavior(schedulesAutomaticExpiration: false),
            now: { clock.now }
        )
        XCTAssertFalse(manager.isPreviewActive)
        XCTAssertNil(store.state.previewThemeID)
        XCTAssertEqual(manager.select(noPreview), .requiresPro(noPreview))
        XCTAssertEqual(manager.committedTheme.id, "rose")
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
