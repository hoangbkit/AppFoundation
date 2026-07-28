import AppFoundation
import Foundation
import Observation

enum DemoProductID {
    static let monthly = "com.hoangbkit.appfoundationdemo.pro.monthly"
    static let yearly = "com.hoangbkit.appfoundationdemo.pro.yearly"
    static let lifetime = "com.hoangbkit.appfoundationdemo.pro.lifetime"
}

@MainActor
@Observable
final class DemoPurchaseStore {
    private(set) var purchases: PurchaseManager
    private(set) var revision = UUID()

    init() {
        let simulatedConfiguration = DemoSimulatedPlanConfiguration.load()
        purchases = PurchaseManager(
            configuration: simulatedConfiguration.purchaseConfiguration,
            simulated: DemoConfiguration.purchaseServiceMode == .simulated,
            simulatedProducts: simulatedConfiguration.products,
            simulatedPersistenceKey: "appfoundation.demo.simulated-purchases"
        )
    }

    #if DEBUG
    func apply(_ configuration: DemoSimulatedPlanConfiguration) {
        let normalized = configuration.normalized()
        let usesSimulator = purchases.isUsingSimulatedPurchases

        normalized.save()
        purchases = PurchaseManager(
            configuration: normalized.purchaseConfiguration,
            simulated: usesSimulator,
            simulatedProducts: normalized.products,
            simulatedPersistenceKey: "appfoundation.demo.simulated-purchases"
        )
        revision = UUID()
    }
    #endif
}

struct DemoSimulatedPlanConfiguration: Codable, Equatable {
    static let storageKey = "appfoundation.demo.simulated-plan-configuration"

    var plans: [DemoSimulatedPlan]
    var preferredProductID: String

    static var defaults: DemoSimulatedPlanConfiguration {
        DemoSimulatedPlanConfiguration(
            plans: [
                DemoSimulatedPlan(
                    productID: DemoProductID.monthly,
                    displayName: "Demo Pro Monthly",
                    productDescription: "Monthly access to every Demo Pro feature.",
                    displayPrice: "$4.99",
                    price: 4.99,
                    period: .monthly,
                    isEnabled: true
                ),
                DemoSimulatedPlan(
                    productID: DemoProductID.yearly,
                    displayName: "Demo Pro Yearly",
                    productDescription: "Annual access to every Demo Pro feature.",
                    displayPrice: "$39.99",
                    price: 39.99,
                    period: .yearly,
                    isEnabled: true
                ),
                DemoSimulatedPlan(
                    productID: DemoProductID.lifetime,
                    displayName: "Demo Pro Lifetime",
                    productDescription: "Pay once and keep Demo Pro forever.",
                    displayPrice: "$79.99",
                    price: 79.99,
                    period: .lifetime,
                    isEnabled: true
                ),
            ],
            preferredProductID: DemoProductID.yearly
        )
    }

    var enabledPlans: [DemoSimulatedPlan] {
        plans.filter(\.isEnabled)
    }

    var purchaseConfiguration: PurchaseConfiguration {
        let normalized = normalized()
        let productIDs = normalized.enabledPlans.map(\.productID)
        return PurchaseConfiguration(
            productIDs: productIDs,
            preferredProductID: normalized.preferredProductID,
            features: DemoPurchaseFeatureCatalog.features
        )
    }

    var products: [PurchaseProduct] {
        normalized().enabledPlans.map(\.purchaseProduct)
    }

    var validationMessage: String? {
        let enabledPlans = enabledPlans
        guard !enabledPlans.isEmpty else {
            return "Enable at least one simulated plan."
        }

        let productIDs = enabledPlans.map {
            $0.productID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard productIDs.allSatisfy({ !$0.isEmpty }) else {
            return "Every enabled plan needs a product identifier."
        }
        guard Set(productIDs).count == productIDs.count else {
            return "Enabled plans must use unique product identifiers."
        }
        guard enabledPlans.allSatisfy({ $0.price >= 0 }) else {
            return "Plan prices cannot be negative."
        }
        return nil
    }

    func normalized() -> DemoSimulatedPlanConfiguration {
        var copy = self
        copy.plans = plans.map { $0.normalized() }

        let enabledIDs = copy.enabledPlans.map(\.productID)
        if !enabledIDs.contains(copy.preferredProductID) {
            copy.preferredProductID = enabledIDs.first ?? ""
        }
        return copy
    }

    func save() {
        guard let data = try? JSONEncoder().encode(normalized()) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func load() -> DemoSimulatedPlanConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let configuration = try? JSONDecoder().decode(Self.self, from: data),
            configuration.validationMessage == nil
        else {
            return .defaults
        }
        return configuration.normalized()
    }
}

struct DemoSimulatedPlan: Identifiable, Codable, Equatable {
    var id: UUID
    var productID: String
    var displayName: String
    var productDescription: String
    var displayPrice: String
    var price: Double
    var period: DemoSimulatedPlanPeriod
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        productID: String,
        displayName: String,
        productDescription: String,
        displayPrice: String,
        price: Double,
        period: DemoSimulatedPlanPeriod,
        isEnabled: Bool
    ) {
        self.id = id
        self.productID = productID
        self.displayName = displayName
        self.productDescription = productDescription
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
        self.isEnabled = isEnabled
    }

    var purchaseProduct: PurchaseProduct {
        PurchaseProduct(
            id: productID,
            displayName: displayName,
            description: productDescription,
            displayPrice: displayPrice,
            price: price,
            subscriptionPeriod: period.subscriptionPeriod
        )
    }

    func normalized() -> DemoSimulatedPlan {
        var copy = self
        copy.productID = productID.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.productDescription = productDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayPrice = displayPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.price = max(0, price)
        return copy
    }

    static func newPlan(index: Int) -> DemoSimulatedPlan {
        DemoSimulatedPlan(
            productID: "com.hoangbkit.appfoundationdemo.pro.plan\(index)",
            displayName: "Demo Pro Plan \(index)",
            productDescription: "Simulated premium access.",
            displayPrice: "$9.99",
            price: 9.99,
            period: .monthly,
            isEnabled: true
        )
    }
}

enum DemoSimulatedPlanPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var subscriptionPeriod: PurchaseProduct.SubscriptionPeriod? {
        switch self {
        case .weekly:
            PurchaseProduct.SubscriptionPeriod(value: 1, unit: .week)
        case .monthly:
            PurchaseProduct.SubscriptionPeriod(value: 1, unit: .month)
        case .yearly:
            PurchaseProduct.SubscriptionPeriod(value: 1, unit: .year)
        case .lifetime:
            nil
        }
    }
}
