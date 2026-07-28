#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

extension FoundationPaywallFeature {
    public init(_ feature: PurchaseFeature) {
        self.init(
            id: feature.id,
            systemImage: feature.systemImage,
            title: feature.title,
            message: feature.message
        )
    }
}
#endif
