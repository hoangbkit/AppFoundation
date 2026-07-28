#if canImport(Observation) && canImport(StoreKit)
import Observation
import StoreKit

extension PurchaseController {
    /// Registered capabilities used by AppFoundation purchase surfaces.
    public var features: [PurchaseFeature] {
        configuration.features
    }

    /// The loaded product currently responsible for the active entitlement, when available.
    public var activeProduct: StoreProduct? {
        guard case .active(let snapshot) = entitlementState else {
            return nil
        }

        return products.first { snapshot.activeProductIDs.contains($0.id) }
    }
}
#endif
