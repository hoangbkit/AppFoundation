import XCTest
@testable import AppFoundation

final class PurchaseConfigurationTests: XCTestCase {
    func testNormalizesProductIdentifiersAndPreservesOrder() {
        let configuration = PurchaseConfiguration(
            productIDs: [" yearly ", "monthly", "yearly", "", "monthly"]
        )

        XCTAssertEqual(configuration.productIDs, ["yearly", "monthly"])
        XCTAssertEqual(configuration.entitledProductIDs, ["yearly", "monthly"])
    }

    func testDropsPreferredIdentifierThatIsNotInCatalog() {
        let configuration = PurchaseConfiguration(
            productIDs: ["monthly"],
            preferredProductID: "yearly"
        )

        XCTAssertNil(configuration.preferredProductID)
    }

    func testClampsProductLoadAttemptsToAtLeastOne() {
        let configuration = PurchaseConfiguration(
            productIDs: ["monthly"],
            productLoadAttempts: 0
        )

        XCTAssertEqual(configuration.productLoadAttempts, 1)
    }
}
