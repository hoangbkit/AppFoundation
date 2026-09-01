#if DEBUG && canImport(StoreKit)
import XCTest
@testable import AppFoundation

@MainActor
final class FoundationDeveloperPurchaseTests: XCTestCase {
    func testSimulatedCatalogCanChangeWithoutMutatingLiveConfiguration() async {
        let controller = makeController()
        await controller.prepare()

        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        let simulatedConfiguration = PurchaseConfiguration(
            productIDs: [yearly.id],
            preferredProductID: yearly.id
        )

        await controller.configureSimulatedCatalog(
            configuration: simulatedConfiguration,
            products: [yearly]
        )

        XCTAssertEqual(controller.configuration.productIDs, [Self.monthly.id])
        XCTAssertEqual(controller.simulatedConfigurationSnapshot, simulatedConfiguration)
        XCTAssertEqual(controller.simulatedCatalogProducts, [yearly])
        XCTAssertEqual(controller.products, [yearly])
        XCTAssertEqual(controller.preferredProduct, yearly)
    }

    func testDeveloperCanForceSimulatedEntitlement() async {
        let controller = makeController()
        await controller.prepare()

        await controller.setSimulatedPurchasedProductIDs([Self.monthly.id])
        XCTAssertTrue(controller.isEntitled)
        XCTAssertEqual(controller.simulatedPurchasedProductIDs, [Self.monthly.id])

        await controller.setSimulatedPurchasedProductIDs([])
        XCTAssertFalse(controller.isEntitled)
        XCTAssertTrue(controller.simulatedPurchasedProductIDs.isEmpty)
    }

    func testDeveloperCanInjectPurchaseFailure() async {
        let controller = makeController()
        await controller.prepare()
        let failure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated network failure."
        )

        controller.setSimulatedPurchaseResult(
            .failure(failure),
            for: Self.monthly.id
        )
        await controller.purchase(Self.monthly)

        XCTAssertEqual(controller.activity, .failed(failure))
        XCTAssertFalse(controller.isEntitled)
    }

    func testDeveloperCanInjectAndResetCatalogFailure() async {
        let controller = makeController()
        await controller.prepare()

        await controller.setSimulatedProductLoadingFailure(.noProductsAvailable)
        XCTAssertEqual(controller.productLoadingState, .failed(.noProductsAvailable))

        await controller.resetSimulatedFailures()
        XCTAssertEqual(controller.productLoadingState, .loaded)
        XCTAssertEqual(controller.products, [Self.monthly])
    }

    func testDeveloperCanInjectRestoreFailure() async {
        let controller = makeController()
        await controller.prepare()
        let failure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated restore failure."
        )

        controller.setSimulatedRestoreFailure(failure)
        let outcome = await controller.restorePurchases()

        XCTAssertEqual(outcome, .failed(failure))
        XCTAssertEqual(controller.activity, .failed(failure))
    }

    func testResetSimulatedPurchasesAlsoClearsFailureInjection() async {
        let controller = makeController()
        await controller.prepare()
        controller.setSimulatedPurchaseResult(.pending, for: Self.monthly.id)
        await controller.setSimulatedProductLoadingFailure(.noProductsAvailable)
        controller.setSimulatedRestoreFailure(.unknown)

        await controller.resetSimulatedPurchases()
        await controller.purchase(Self.monthly)

        XCTAssertTrue(controller.isEntitled)
        XCTAssertEqual(controller.activity, .idle)
        XCTAssertEqual(controller.productLoadingState, .loaded)
    }

    private func makeController() -> PurchaseController {
        PurchaseController(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                preferredProductID: Self.monthly.id
            ),
            simulated: true,
            simulatedProducts: [Self.monthly],
            simulatedOperationDelay: .milliseconds(0)
        )
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly Pro",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )
}
#endif