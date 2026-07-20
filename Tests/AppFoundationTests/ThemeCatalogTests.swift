import XCTest
@testable import AppFoundation

final class ThemeCatalogTests: XCTestCase {
    func testFoundationCatalogProvidesOneFreeAndFiveProThemes() {
        let catalog = ThemeCatalog.foundationDefaults

        XCTAssertEqual(catalog.themes.map(\.id), [
            "rose", "sunset", "lavender", "midnight", "paper", "champagne",
        ])
        XCTAssertEqual(catalog.freeThemes.map(\.id), ["rose"])
        XCTAssertEqual(catalog.proThemes.count, 5)
        XCTAssertEqual(catalog.fallbackThemeID, "rose")
    }

    func testAppCanExcludeDefaultsAndAppendCustomTheme() {
        let custom = FoundationThemes.midnight
            .withTitle("Graphite")
            .withAccess(.free)

        let catalog = ThemeCatalog.foundationDefaults
            .excluding(ids: ["sunset", "champagne"])
            .appending(custom)

        XCTAssertNil(catalog.theme(id: "sunset"))
        XCTAssertNil(catalog.theme(id: "champagne"))
        XCTAssertEqual(catalog.theme(id: "midnight")?.title, "Graphite")
        XCTAssertEqual(catalog.theme(id: "midnight")?.access, .free)
    }

    func testDuplicateThemeIDUsesLatestDefinitionWithoutChangingOrder() {
        let customRose = FoundationThemes.rose.withTitle("Blush")
        let catalog = ThemeCatalog(
            themes: FoundationThemes.all + [customRose],
            fallbackThemeID: "rose"
        )

        XCTAssertEqual(catalog.themes.first?.id, "rose")
        XCTAssertEqual(catalog.themes.first?.title, "Blush")
        XCTAssertEqual(catalog.themes.count, 6)
    }

    func testRemovingFallbackChoosesFirstRemainingTheme() {
        let catalog = ThemeCatalog.foundationDefaults.excluding(ids: ["rose"])

        XCTAssertEqual(catalog.fallbackThemeID, "sunset")
        XCTAssertEqual(catalog.fallbackTheme.id, "sunset")
        XCTAssertEqual(catalog.fallbackTheme.access, .free)
    }
}
