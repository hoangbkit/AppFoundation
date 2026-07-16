import XCTest
@testable import AppFoundation

final class ProductCatalogTests: XCTestCase {
    func testUsesConfigurationOrderInsteadOfPrice() {
        let monthly = StoreProduct(
            id: "monthly",
            displayName: "Monthly",
            description: "",
            displayPrice: "$4.99",
            price: 4.99
        )
        let yearly = StoreProduct(
            id: "yearly",
            displayName: "Yearly",
            description: "",
            displayPrice: "$39.99",
            price: 39.99
        )

        let ordered = ProductCatalog.ordered(
            [monthly, yearly],
            using: ["yearly", "monthly"]
        )

        XCTAssertEqual(ordered.map(\.id), ["yearly", "monthly"])
    }

    func testUnknownProductsSortByPriceAfterConfiguredProducts() {
        let configured = StoreProduct(
            id: "configured",
            displayName: "Configured",
            description: "",
            displayPrice: "$9.99",
            price: 9.99
        )
        let cheapUnknown = StoreProduct(
            id: "cheap",
            displayName: "Cheap",
            description: "",
            displayPrice: "$0.99",
            price: 0.99
        )
        let expensiveUnknown = StoreProduct(
            id: "expensive",
            displayName: "Expensive",
            description: "",
            displayPrice: "$19.99",
            price: 19.99
        )

        let ordered = ProductCatalog.ordered(
            [expensiveUnknown, cheapUnknown, configured],
            using: ["configured"]
        )

        XCTAssertEqual(ordered.map(\.id), ["configured", "cheap", "expensive"])
    }
}
