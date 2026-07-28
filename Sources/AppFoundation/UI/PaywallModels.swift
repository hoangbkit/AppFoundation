#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

public struct PaywallFeature: Identifiable, Hashable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let message: String

    public init(id: String, systemImage: String, title: String, message: String) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public init(_ feature: PurchaseFeature) {
        self.init(
            id: feature.id,
            systemImage: feature.systemImage,
            title: feature.title,
            message: feature.message
        )
    }
}

public struct PaywallConfiguration {
    public var title: String
    public var subtitle: String
    public var planTitle: String
    public var planSubtitle: String

    /// Optional local override. Leave empty to use `PurchaseManager.features`.
    public var features: [PaywallFeature]

    public var preferredProductID: String?
    public var highlightedProductID: String?
    public var highlightedProductBadge: String
    public var purchaseButtonTitle: String
    public var privacyURL: URL?
    public var termsURL: URL?
    public var showsCloseButton: Bool
    public var tint: Color?
    public var themeOverride: AppTheme?
    public var planDetail: (PurchaseProduct) -> String?

    public init(
        title: String,
        subtitle: String,
        planTitle: String = "Pro",
        planSubtitle: String = "Unlock every premium feature",
        features: [PaywallFeature] = [],
        preferredProductID: String? = nil,
        highlightedProductID: String? = nil,
        highlightedProductBadge: String = "BEST VALUE",
        purchaseButtonTitle: String = "Continue",
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        showsCloseButton: Bool = true,
        tint: Color? = nil,
        themeOverride: AppTheme? = nil,
        planDetail: @escaping (PurchaseProduct) -> String? = { _ in nil }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.planTitle = planTitle
        self.planSubtitle = planSubtitle
        self.features = features
        self.preferredProductID = preferredProductID
        self.highlightedProductID = highlightedProductID
        self.highlightedProductBadge = highlightedProductBadge
        self.purchaseButtonTitle = purchaseButtonTitle
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.showsCloseButton = showsCloseButton
        self.tint = tint
        self.themeOverride = themeOverride
        self.planDetail = planDetail
    }
}
#endif
