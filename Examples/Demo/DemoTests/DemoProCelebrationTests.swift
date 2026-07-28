import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoProCelebrationTests: XCTestCase {
    func testCelebrationUsesActivePurchasedPlan() async {
        let purchases = PurchaseManager(
            configuration: DemoConfiguration.purchases,
            simulated: true,
            simulatedProducts: DemoConfiguration.simulatedProducts,
            simulatedOperationDelay: .milliseconds(0)
        )

        await purchases.prepare()
        guard let lifetime = purchases.product(withID: DemoConfiguration.lifetimeProductID) else {
            return XCTFail("Missing lifetime product")
        }

        await purchases.purchase(lifetime)
        let configuration = DemoConfiguration.proCelebration(for: purchases)

        XCTAssertTrue(purchases.hasPro)
        XCTAssertEqual(configuration.navigationTitle, "AF Pro")
        XCTAssertEqual(configuration.planTitle, lifetime.displayName)
        XCTAssertEqual(configuration.rows.count, 4)
        XCTAssertEqual(configuration.rows.last?.feature, "Backup history")
    }
}
