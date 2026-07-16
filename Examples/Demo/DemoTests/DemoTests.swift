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

    func testOnboardingHasStableUniqueIdentifiers() {
        let identifiers = DemoConfiguration.onboardingPages.map(\.id)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertFalse(identifiers.isEmpty)
    }
}
