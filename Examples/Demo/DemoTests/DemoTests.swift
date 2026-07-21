import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoTests: XCTestCase {
    func testPurchaseConfigurationUsesMonthlyThenYearly() {
        XCTAssertEqual(
            DemoConfiguration.purchases.productIDs,
            [
                "com.hoangbkit.appfoundationdemo.pro.monthly",
                "com.hoangbkit.appfoundationdemo.pro.yearly",
            ]
        )
        XCTAssertEqual(
            DemoConfiguration.purchases.preferredProductID,
            "com.hoangbkit.appfoundationdemo.pro.yearly"
        )
    }

    func testModernPaywallPrefersYearlyProduct() {
        XCTAssertEqual(
            DemoConfiguration.modernPaywall.preferredProductID,
            DemoConfiguration.purchases.preferredProductID
        )
        XCTAssertFalse(DemoConfiguration.modernPaywall.features.isEmpty)
    }

    func testAllPaywallsFollowActiveThemeByDefault() {
        XCTAssertNil(DemoConfiguration.modernPaywall.tint)
        XCTAssertNil(DemoConfiguration.modernPaywall.themeOverride)

        XCTAssertTrue(DemoConfiguration.legacyPaywall.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.legacyPaywall.themeOverride)

        XCTAssertTrue(DemoConfiguration.legacyClaudePaywall.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.legacyClaudePaywall.themeOverride)
    }

    func testSettingsFollowActiveThemeByDefault() {
        XCTAssertTrue(DemoConfiguration.settings.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.settings.themeOverride)
    }

    func testExplicitFoundationThemeRemainsFixed() {
        let paywall = FoundationPaywallConfiguration(
            title: "Fixed",
            subtitle: "Compatibility",
            features: [],
            theme: .indigo
        )
        let settings = FoundationSettingsConfiguration(
            appName: "Fixed",
            theme: .indigo
        )

        XCTAssertFalse(paywall.followsActiveTheme)
        XCTAssertNil(paywall.themeOverride)
        XCTAssertFalse(settings.followsActiveTheme)
        XCTAssertNil(settings.themeOverride)
    }

    func testBackupConfigurationMatchesDemoBundle() {
        XCTAssertEqual(
            DemoConfiguration.backupConfiguration.appIdentifier,
            "com.hoangbkit.appfoundationdemo"
        )
        XCTAssertEqual(DemoConfiguration.backupConfiguration.fileExtension, "afdemo")
    }

    func testSampleDeepLinkIsStable() {
        XCTAssertEqual(
            DemoConfiguration.sampleDeepLink.url?.absoluteString,
            "appfoundation-demo://showcase/exports/latest?source=widget"
        )
    }

    func testOnboardingHasStableUniqueIdentifiers() {
        let identifiers = DemoConfiguration.onboardingPages.map(\.id)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertFalse(identifiers.isEmpty)
    }
}