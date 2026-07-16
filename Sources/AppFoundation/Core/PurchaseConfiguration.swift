import Foundation

/// Configuration shared by the StoreKit engine and reusable paywall UI.
public struct PurchaseConfiguration: Sendable, Equatable {
    /// Product identifiers in the order they should be presented.
    public let productIDs: [String]

    /// Product identifiers that unlock the app entitlement.
    public let entitledProductIDs: Set<String>

    /// Product selected by default when the catalog is loaded.
    public let preferredProductID: String?

    /// Number of catalog loading attempts before surfacing an error.
    public let productLoadAttempts: Int

    public init(
        productIDs: [String],
        entitledProductIDs: Set<String>? = nil,
        preferredProductID: String? = nil,
        productLoadAttempts: Int = 3
    ) {
        let normalizedProductIDs = Self.uniqueNonEmptyValues(productIDs)
        let normalizedEntitledIDs = Set(
            (entitledProductIDs ?? Set(normalizedProductIDs))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        self.productIDs = normalizedProductIDs
        self.entitledProductIDs = normalizedEntitledIDs
        self.preferredProductID = preferredProductID.flatMap { candidate in
            let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedProductIDs.contains(normalized) ? normalized : nil
        }
        self.productLoadAttempts = max(1, productLoadAttempts)
    }

    private static func uniqueNonEmptyValues(_ values: [String]) -> [String] {
        var seen = Set<String>()

        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }
}
