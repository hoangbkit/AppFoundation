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
