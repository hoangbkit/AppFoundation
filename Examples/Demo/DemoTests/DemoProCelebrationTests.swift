import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoProCelebrationTests: XCTestCase {
    func testPurchaseManagerExposesRegisteredCatalogAndActivePlan() async {
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
        XCTAssertEqual(purchases.activeProduct?.id, lifetime.id)
        XCTAssertEqual(purchases.features.count, 6)
        XCTAssertEqual(purchases.features.first?.title, "Reusable components")
        XCTAssertEqual(purchases.features.last?.title, "Backup history")
        XCTAssertTrue(configuration.planTitle.isEmpty)
        XCTAssertTrue(configuration.rows.isEmpty)
    }
}
