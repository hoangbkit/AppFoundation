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

    func testCommittedFreeBaseWinsOverRememberedProPreferenceDuringChecking() {
        let state = ThemeStoredState(
            selectedThemeID: "midnight",
            lastKnownHasPro: true,
            committedThemeID: "rose"
        )

        let checking = ThemeResolver.resolve(catalog: .foundationDefaults, state: state, now: now)
        let renewed = ThemeResolver.resolve(
            catalog: .foundationDefaults, state: state, hasPro: true, now: now
        )

        XCTAssertEqual(checking.selectedTheme.id, "midnight")
        XCTAssertEqual(checking.effectiveTheme.id, "rose")
        XCTAssertEqual(renewed.effectiveTheme.id, "midnight")
    }

    func testExplicitFreeAccessOverridesCommittedProBase() {
        let state = ThemeStoredState(
            selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "midnight"
        )
        let resolution = ThemeResolver.resolve(
            catalog: .foundationDefaults, state: state, hasPro: false, now: now
        )
        XCTAssertEqual(resolution.effectiveTheme.id, "rose")
    }

    func testLegacyStateDecodesWithoutCommittedThemeOrAccessFlag() throws {
        let json = Data(#"{"selectedThemeID":"midnight"}"#.utf8)
        let state = try JSONDecoder().decode(ThemeStoredState.self, from: json)

        XCTAssertNil(state.committedThemeID)
        XCTAssertFalse(state.lastKnownHasPro)
        XCTAssertEqual(
            ThemeResolver.resolve(catalog: .foundationDefaults, state: state, now: now)
                .effectiveTheme.id,
            "rose"
        )
    }

    func testAccessTransitionPersistsBaseSeparatelyAndRoundTrips() throws {
        let pro = ThemeStoredState(
            selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "midnight"
        )
        let free = ThemeResolver.applyingAccess(
            false, to: pro, catalog: .foundationDefaults, now: now,
            promotesPreviewOnProUnlock: true
        )
        let decoded = try JSONDecoder().decode(
            ThemeStoredState.self, from: JSONEncoder().encode(free)
        )

        XCTAssertEqual(decoded.selectedThemeID, "midnight")
        XCTAssertEqual(decoded.committedThemeID, "rose")
        XCTAssertFalse(decoded.lastKnownHasPro)
        XCTAssertEqual(
            ThemeResolver.resolve(catalog: .foundationDefaults, state: decoded, now: now)
                .effectiveTheme.id,
            "rose"
        )
    }

    func testPurchasePreviewPromotionMatrix() {
        for promotes in [false, true] {
            for secondsRemaining in [-1.0, 0.0, 1.0] {
                let free = ThemeStoredState(
                    selectedThemeID: "rose", previewThemeID: "paper",
                    previewExpiresAt: now.addingTimeInterval(secondsRemaining),
                    committedThemeID: "rose"
                )
                let pro = ThemeResolver.applyingAccess(
                    true, to: free, catalog: .foundationDefaults, now: now,
                    promotesPreviewOnProUnlock: promotes
                )
                let expected = promotes && secondsRemaining > 0 ? "paper" : "rose"
                XCTAssertEqual(pro.selectedThemeID, expected)
                XCTAssertEqual(pro.committedThemeID, expected)
                XCTAssertNil(pro.previewThemeID)
                XCTAssertNil(pro.previewExpiresAt)
            }
        }
    }

    func testFreeResolutionPreservesPreviewAndItsDeadline() {
        let free = ThemeStoredState(
            selectedThemeID: "midnight", previewThemeID: "paper",
            previewExpiresAt: now.addingTimeInterval(50), committedThemeID: "rose"
        )
        let next = ThemeResolver.applyingAccess(
            false, to: free, catalog: .foundationDefaults, now: now,
            promotesPreviewOnProUnlock: true
        )
        XCTAssertEqual(next.previewThemeID, "paper")
        XCTAssertEqual(next.previewExpiresAt, free.previewExpiresAt)
        XCTAssertEqual(next.committedThemeID, "rose")
        XCTAssertEqual(
            ThemeResolver.resolve(catalog: .foundationDefaults, state: next, now: now)
                .effectiveTheme.id,
            "paper"
        )
    }

    func testRemovedCommittedBaseDoesNotResurrectProPreferenceInWidget() {
        let state = ThemeStoredState(
            selectedThemeID: "midnight", lastKnownHasPro: true, committedThemeID: "removed"
        )
        XCTAssertEqual(
            ThemeResolver.resolve(catalog: .foundationDefaults, state: state, now: now)
                .effectiveTheme.id,
            "rose"
        )
    }
}
