import XCTest
@testable import AppFoundation

final class FoundationProCelebrationViewTests: XCTestCase {
    func testConfigurationUsesCelebrationDefaults() {
        let rows = [
            FoundationProComparisonRow(
                feature: "Projects",
                freeValue: "3",
                proValue: "Unlimited"
            )
        ]
        let configuration = FoundationProCelebrationConfiguration(
            title: "You’re Pro",
            message: "Thanks for supporting the app.",
            planTitle: "Lifetime Pro",
            statusMessage: "Every Pro feature is unlocked.",
            rows: rows
        )

        XCTAssertEqual(configuration.navigationTitle, "Pro")
        XCTAssertEqual(configuration.doneButtonTitle, "Done")
        XCTAssertEqual(configuration.symbolName, "diamond.fill")
        XCTAssertEqual(configuration.statusSymbolName, "checkmark.seal.fill")
        XCTAssertEqual(configuration.featureColumnTitle, "Feature")
        XCTAssertEqual(configuration.freeColumnTitle, "Free")
        XCTAssertEqual(configuration.proColumnTitle, "Pro")
        XCTAssertEqual(configuration.rows, rows)
        XCTAssertNil(configuration.themeOverride)
    }

    func testConfigurationDefaultsToPlanAwareThankYouCopy() {
        let configuration = FoundationProCelebrationConfiguration()

        XCTAssertTrue(configuration.title.isEmpty)
        XCTAssertEqual(
            configuration.message,
            "Thanks for supporting \(AppMetadata.current().name) and unlocking the complete Pro experience"
        )
    }

    func testComparisonRowUsesFeatureAsDefaultIdentifier() {
        let row = FoundationProComparisonRow(
            feature: "Themes",
            freeValue: "1",
            proValue: "All"
        )

        XCTAssertEqual(row.id, "Themes")
    }
}
