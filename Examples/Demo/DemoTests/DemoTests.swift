import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoTests: XCTestCase {
    func testPurchaseConfigurationUsesAllSupportedPlansInOrder() {
        XCTAssertEqual(
            DemoConfiguration.purchases.productIDs,
            [
                DemoConfiguration.weeklyProductID,
                DemoConfiguration.monthlyProductID,
                DemoConfiguration.yearlyProductID,
                DemoConfiguration.lifetimeProductID,
            ]
        )
        XCTAssertEqual(
            DemoConfiguration.purchases.preferredProductID,
            DemoConfiguration.yearlyProductID
        )
    }

    func testSimulatedCatalogContainsWeeklyAndLifetimePlans() {
        let weekly = DemoConfiguration.simulatedProducts.first {
            $0.id == DemoConfiguration.weeklyProductID
        }
        let lifetime = DemoConfiguration.simulatedProducts.first {
            $0.id == DemoConfiguration.lifetimeProductID
        }

        XCTAssertEqual(weekly?.subscriptionPeriod, .init(value: 1, unit: .week))
        XCTAssertTrue(lifetime?.isLifetime == true)
        XCTAssertNil(lifetime?.subscriptionPeriod)
    }

    func testModernPaywallPrefersAndHighlightsYearlyProduct() {
        XCTAssertEqual(
            DemoConfiguration.modernPaywall.preferredProductID,
            DemoConfiguration.purchases.preferredProductID
        )
        XCTAssertEqual(
            DemoConfiguration.modernPaywall.highlightedProductID,
            DemoConfiguration.yearlyProductID
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