import AppFoundation
import Foundation

@MainActor
enum MacDemoConfiguration {
  static let monthlyProductID = "com.hoangbkit.appfoundationdemo.pro.monthly"
  static let yearlyProductID = "com.hoangbkit.appfoundationdemo.pro.yearly"

  static let purchases = PurchaseConfiguration(
    productIDs: [
      monthlyProductID,
      yearlyProductID,
    ],
    preferredProductID: yearlyProductID
  )

  static let simulatedProducts: [PurchaseProduct] = [
    PurchaseProduct(
      id: monthlyProductID,
      displayName: "Demo Pro Monthly",
      description: "Monthly access to every Demo Pro feature.",
      displayPrice: "$4.99",
      price: 4.99,
      subscriptionPeriod: .init(value: 1, unit: .month)
    ),
    PurchaseProduct(
      id: yearlyProductID,
      displayName: "Demo Pro Yearly",
      description: "Annual access to every Demo Pro feature.",
      displayPrice: "$39.99",
      price: 39.99,
      subscriptionPeriod: .init(value: 1, unit: .year)
    ),
  ]

  static let paywall = FoundationPaywallConfiguration(
    title: "Get more AppFoundation",
    subtitle: "Preview a native Mac paywall powered by AppFoundation purchases.",
    features: [
      FoundationPaywallFeature(
        id: "storekit",
        systemImage: "checkmark.shield.fill",
        title: "Verified entitlements",
        message: "Purchase state comes from AppFoundation's StoreKit manager."
      ),
      FoundationPaywallFeature(
        id: "catalog",
        systemImage: "rectangle.stack.fill",
        title: "Flexible product catalog",
        message: "Present subscriptions and lifetime products from one reusable view."
      ),
      FoundationPaywallFeature(
        id: "native-mac",
        systemImage: "macwindow",
        title: "Native Mac presentation",
        message: "Use a responsive two-column layout designed for desktop windows."
      ),
      FoundationPaywallFeature(
        id: "restore",
        systemImage: "arrow.clockwise",
        title: "Purchase recovery",
        message: "Loading, purchase, restore, and error states are handled for you."
      ),
    ],
    purchaseButtonTitle: "Unlock Demo Pro",
    highlightedProductID: yearlyProductID,
    highlightedProductBadge: "BEST VALUE",
    privacyURL: URL(string: "https://example.com/privacy"),
    termsURL: URL(string: "https://example.com/terms")
  )
}
