import XCTest
@testable import AppFoundation

final class ThemeResolverTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testProSelectionFallsBackWithoutDeletingSelection() {
        let state = ThemeStoredState(selectedThemeID: "midnight")
        let resolution = ThemeResolver.resolve(
            catalog: .foundationDefaults,
            state: state,
            hasPro: false,
            now: now
        )

        XCTAssertEqual(resolution.selectedTheme.id, "midnight")
        XCTAssertEqual(resolution.effectiveTheme.id, "rose")
        XCTAssertTrue(resolution.isUsingFallbackForAccess)
    }

    func testActiveProPreviewOverridesFallbackUntilExpiry() {
        let expiry = now.addingTimeInterval(300)
        let state = ThemeStoredState(
            selectedThemeID: "rose",
            previewThemeID: "paper",
            previewExpiresAt: expiry
        )
        let resolution = ThemeResolver.resolve(
            catalog: .foundationDefaults,
            state: state,
            hasPro: false,
            now: now
        )

        XCTAssertEqual(resolution.effectiveTheme.id, "paper")
        XCTAssertEqual(resolution.previewTheme?.id, "paper")
        XCTAssertEqual(resolution.nextAutomaticChangeDate, expiry)
    }

    func testExpiredPreviewIsIgnored() {
        let state = ThemeStoredState(
            selectedThemeID: "rose",
            previewThemeID: "paper",
            previewExpiresAt: now.addingTimeInterval(-1)
        )
        let resolution = ThemeResolver.resolve(
            catalog: .foundationDefaults,
            state: state,
            hasPro: false,
            now: now
        )

        XCTAssertEqual(resolution.effectiveTheme.id, "rose")
        XCTAssertFalse(resolution.isPreviewActive)
        XCTAssertNil(resolution.nextAutomaticChangeDate)
    }

    func testWidgetStyleResolutionCanUsePersistedLastKnownProState() {
        let state = ThemeStoredState(selectedThemeID: "midnight", lastKnownHasPro: true)
        let resolution = ThemeResolver.resolve(
            catalog: .foundationDefaults,
            state: state,
            now: now
        )

        XCTAssertEqual(resolution.effectiveTheme.id, "midnight")
        XCTAssertTrue(resolution.hasPro)
    }
}
