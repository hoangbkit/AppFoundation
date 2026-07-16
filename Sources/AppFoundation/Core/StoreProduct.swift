import Foundation

public struct StoreProduct: Identifiable, Sendable, Equatable {
    public struct SubscriptionPeriod: Sendable, Equatable {
        public enum Unit: String, Sendable, Equatable {
            case day
            case week
            case month
            case year
            case unknown
        }

        public let value: Int
        public let unit: Unit

        public init(value: Int, unit: Unit) {
            self.value = max(1, value)
            self.unit = unit
        }

        public var shortLabel: String {
            let singular: String
            switch unit {
            case .day:
                singular = "day"
            case .week:
                singular = "week"
            case .month:
                singular = "month"
            case .year:
                singular = "year"
            case .unknown:
                singular = "period"
            }

            return value == 1 ? singular : "\(value) \(singular)s"
        }
    }

    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let price: Double
    public let subscriptionPeriod: SubscriptionPeriod?

    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        price: Double,
        subscriptionPeriod: SubscriptionPeriod? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
        self.subscriptionPeriod = subscriptionPeriod
    }
}

public enum ProductCatalog {
    public static func ordered(
        _ products: [StoreProduct],
        using productIDs: [String]
    ) -> [StoreProduct] {
        let positions = Dictionary(uniqueKeysWithValues: productIDs.enumerated().map { ($1, $0) })

        return products.sorted { lhs, rhs in
            let lhsPosition = positions[lhs.id] ?? .max
            let rhsPosition = positions[rhs.id] ?? .max

            if lhsPosition == rhsPosition {
                return lhs.price < rhs.price
            }
            return lhsPosition < rhsPosition
        }
    }
}
