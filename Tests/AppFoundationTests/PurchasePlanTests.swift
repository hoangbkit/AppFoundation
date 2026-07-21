import XCTest
@testable import AppFoundation

final class PurchasePlanTests: XCTestCase {
    func testWeeklyPlanMetadata() {
        let product = StoreProduct(
            id: "pro.weekly",
            displayName: "Pro Weekly",
            description: "Weekly access",
            displayPrice: "$1.99",
            price: 1.99,
            subscriptionPeriod: .init(value: 1, unit: .week)
        )

        XCTAssertEqual(product.planKind, .recurring(.init(value: 1, unit: .week)))
        XCTAssertTrue(product.isRecurring)
        XCTAssertFalse(product.isLifetime)
        XCTAssertEqual(product.planLabel, "Weekly")
        XCTAssertEqual(product.billingDescription, "Billed every week")
    }

    func testLifetimePlanMetadata() {
        let product = StoreProduct(
            id: "pro.lifetime",
            displayName: "Pro Lifetime",
            description: "Permanent access",
            displayPrice: "$79.99",
            price: 79.99
        )

        XCTAssertEqual(product.planKind, .lifetime)
        XCTAssertFalse(product.isRecurring)
        XCTAssertTrue(product.isLifetime)
        XCTAssertEqual(product.planLabel, "Lifetime")
        XCTAssertEqual(product.billingDescription, "One-time purchase, lifetime access")
    }

    func testMixedCatalogDisclosureMentionsRenewalAndOneTimePurchase() {
        let weekly = StoreProduct(
            id: "pro.weekly",
            displayName: "Weekly",
            description: "",
            displayPrice: "$1.99",
            price: 1.99,
            subscriptionPeriod: .init(value: 1, unit: .week)
        )
        let lifetime = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99
        )

        XCTAssertEqual(
            PurchasePlanDisclosure.text(for: [weekly, lifetime]),
            "Subscriptions renew automatically unless cancelled in App Store settings. Lifetime access is a one-time purchase."
        )
    }

    func testLifetimeEntitlementHasNoExpirationAndRemainsActive() {
        let record = EntitlementRecord(
            productID: "pro.lifetime",
            purchaseDate: Date(timeIntervalSince1970: 1)
        )

        let state = EntitlementEvaluator.evaluate(
            [record],
            entitledProductIDs: ["pro.lifetime"],
            at: Date(timeIntervalSince1970: 10_000)
        )

        guard case .active(let snapshot) = state else {
            return XCTFail("Expected a permanent active entitlement")
        }
        XCTAssertEqual(snapshot.activeProductIDs, ["pro.lifetime"])
        XCTAssertNil(snapshot.latestExpirationDate)
    }
}