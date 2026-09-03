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

    func testEligibleFreeTrialProducesTrialAwarePaywallCopy() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Pro Yearly",
            description: "Annual access",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )

        XCTAssertEqual(product.eligibleFreeTrial?.durationDescription, "7 days")
        XCTAssertEqual(product.introductoryOfferHeadline, "7 days free")
        XCTAssertEqual(product.recurringPriceDescription, "$39.99/year")
        XCTAssertEqual(product.postIntroductoryOfferBillingDescription, "Then $39.99/year")
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Start Free Trial")
        XCTAssertEqual(
            product.introductoryOfferDisclosure,
            "7 days free, then $39.99/year. Renews automatically until cancelled."
        )
    }

    func testIneligibleFreeTrialFallsBackToNormalSubscriptionCopy() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Pro Yearly",
            description: "Annual access",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: false
            )
        )

        XCTAssertNil(product.eligibleIntroductoryOffer)
        XCTAssertNil(product.eligibleFreeTrial)
        XCTAssertNil(product.introductoryOfferHeadline)
        XCTAssertNil(product.postIntroductoryOfferBillingDescription)
        XCTAssertNil(product.introductoryOfferDisclosure)
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Continue with Yearly")
    }

    func testPayAsYouGoIntroductoryOfferUsesTotalDuration() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .payAsYouGo,
            period: .init(value: 1, unit: .month),
            periodCount: 3,
            displayPrice: "$1.99",
            price: 1.99,
            isEligible: true
        )

        XCTAssertEqual(offer.durationDescription, "3 months")
        XCTAssertEqual(offer.headline, "$1.99/month for 3 months")
    }

    func testPayUpFrontIntroductoryOfferCopy() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .payUpFront,
            period: .init(value: 3, unit: .month),
            displayPrice: "$9.99",
            price: 9.99,
            isEligible: true
        )

        XCTAssertEqual(offer.durationDescription, "3 months")
        XCTAssertEqual(offer.headline, "$9.99 for 3 months")
    }

    func testLifetimeProductIgnoresInjectedIntroductoryOffer() {
        let product = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99,
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )

        XCTAssertNil(product.eligibleIntroductoryOffer)
        XCTAssertNil(product.eligibleFreeTrial)
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Continue with Lifetime")
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
