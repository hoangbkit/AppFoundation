#if canImport(StoreKit)
import Foundation
import StoreKit

@MainActor
public protocol PurchaseServing: AnyObject {
    func products(for identifiers: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    func currentEntitlements() async -> [EntitlementRecord]
    func entitlementUpdates() -> AsyncStream<Void>
    func sync() async throws
}

@MainActor
public final class LiveStoreKitService: PurchaseServing {
    private var productsByID: [String: Product] = [:]

    public init() {}

    public func products(for identifiers: [String]) async throws -> [StoreProduct] {
        let products = try await Product.products(for: identifiers)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return products.map(Self.makeStoreProduct)
    }

    public func purchase(productID: String) async throws -> PurchaseOutcome {
        let product: Product
        if let cachedProduct = productsByID[productID] {
            product = cachedProduct
        } else if let fetchedProduct = try await Product.products(for: [productID]).first {
            productsByID[productID] = fetchedProduct
            product = fetchedProduct
        } else {
            throw PurchaseFailure.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            let record = Self.makeEntitlementRecord(transaction)
            await transaction.finish()
            return .success(record)
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw PurchaseFailure.unknown
        }
    }

    public func currentEntitlements() async -> [EntitlementRecord] {
        var records: [EntitlementRecord] = []

        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else {
                continue
            }
            records.append(Self.makeEntitlementRecord(transaction))
        }

        return records
    }

    public func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    guard !Task.isCancelled else {
                        break
                    }

                    guard case .verified(let transaction) = verification else {
                        continue
                    }

                    await transaction.finish()
                    continuation.yield()
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func sync() async throws {
        try await AppStore.sync()
    }

    private static func verified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseFailure.verificationFailed
        }
    }

    private static func makeEntitlementRecord(_ transaction: Transaction) -> EntitlementRecord {
        EntitlementRecord(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded
        )
    }

    private static func makeStoreProduct(_ product: Product) -> StoreProduct {
        StoreProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            price: NSDecimalNumber(decimal: product.price).doubleValue,
            subscriptionPeriod: product.subscription.map { subscription in
                let period = subscription.subscriptionPeriod
                return StoreProduct.SubscriptionPeriod(
                    value: period.value,
                    unit: makePeriodUnit(period.unit)
                )
            }
        )
    }

    private static func makePeriodUnit(_ unit: Product.SubscriptionPeriod.Unit) -> StoreProduct.SubscriptionPeriod.Unit {
        switch unit {
        case .day:
            .day
        case .week:
            .week
        case .month:
            .month
        case .year:
            .year
        @unknown default:
            .unknown
        }
    }
}
#endif
