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

    private func makeManager(
        clock: TestClock,
        store: MemoryThemeStore = MemoryThemeStore(),
        hasPro: Bool = false
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
