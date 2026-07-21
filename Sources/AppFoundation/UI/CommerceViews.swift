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
}

public struct PaywallConfiguration {
    public var title: String
    public var subtitle: String
    public var planTitle: String
    public var planSubtitle: String
    public var features: [PaywallFeature]
    public var preferredProductID: String?
    public var purchaseButtonTitle: String
    public var privacyURL: URL?
    public var termsURL: URL?
    public var showsCloseButton: Bool
    public var tint: Color?
    public var planDetail: (PurchaseProduct) -> String?

    public init(
        title: String,
        subtitle: String,
        planTitle: String = "Pro",
        planSubtitle: String = "Unlock every premium feature",
        features: [PaywallFeature],
        preferredProductID: String? = nil,
        purchaseButtonTitle: String = "Continue",
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        showsCloseButton: Bool = true,
        tint: Color? = nil,
        planDetail: @escaping (PurchaseProduct) -> String? = { _ in nil }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.planTitle = planTitle
        self.planSubtitle = planSubtitle
        self.features = features
        self.preferredProductID = preferredProductID
        self.purchaseButtonTitle = purchaseButtonTitle
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.showsCloseButton = showsCloseButton
        self.tint = tint
        self.planDetail = planDetail
    }
}

/// The primary compact monthly/yearly paywall provided by AppFoundation.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let purchaseManager: PurchaseManager
    private let configuration: PaywallConfiguration

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

    public init(purchaseManager: PurchaseManager, configuration: PaywallConfiguration) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                planContainer
                legalFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .tint(configuration.tint)
        .overlay(alignment: .topLeading) {
            if configuration.showsCloseButton {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: Circle())
                    .padding(12)
                    .accessibilityIdentifier("paywall.close")
            }
        }
        .task {
            if purchaseManager.products.isEmpty {
                await purchaseManager.loadProducts(force: true)
            }
            selectDefaultProduct()
        }
        .onChange(of: purchaseManager.products) { _, _ in selectDefaultProduct() }
        .alert("Restore Purchases", isPresented: restoreAlertBinding) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Purchase", isPresented: purchaseErrorBinding) {
            Button("OK", role: .cancel) { purchaseManager.clearActivity() }
        } message: {
            Text(purchaseFailure?.message ?? PurchaseFailure.unknown.message)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(configuration.title)
                .font(.largeTitle.weight(.semibold))
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, configuration.showsCloseButton ? 28 : 0)
    }

    private var planContainer: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.planTitle).font(.title2.weight(.semibold))
                Text(configuration.planSubtitle).font(.subheadline).foregroundStyle(.secondary)
            }

            productContent
            purchaseButton
            Divider()
            featureList
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var productContent: some View {
        switch purchaseManager.productLoadingState {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 28)
        case .failed(let failure):
            VStack(spacing: 12) {
                Text(failure.message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Try Again") { Task { await purchaseManager.loadProducts(force: true) } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        case .loaded:
            HStack(alignment: .stretch, spacing: 12) {
                ForEach(subscriptionProducts.prefix(2)) { product in
                    planOption(product)
                }
            }
        }
    }

    private func planOption(_ product: PurchaseProduct) -> some View {
        let selected = selectedProductID == product.id
        return Button {
            selectedProductID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                Text(product.displayName).font(.headline).lineLimit(2)
                Text(product.displayPrice).font(.title3.weight(.bold))
                if let detail = configuration.planDetail(product) ?? product.subscriptionPeriod.map({ "Billed every \($0.shortLabel)" }) {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .padding(14)
            .background(selected ? Color.accentColor.opacity(0.10) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct else { return }
            Task {
                await purchaseManager.purchase(selectedProduct)
                if purchaseManager.hasPro { dismiss() }
            }
        } label: {
            HStack {
                if purchaseManager.isBusy { ProgressView() }
                Text(configuration.purchaseButtonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
        .disabled(selectedProduct == nil || purchaseManager.isBusy)
        .accessibilityIdentifier("paywall.purchase")
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(configuration.features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.systemImage)
                        .frame(width: 24)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.weight(.semibold))
                        Text(feature.message).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Restore Purchases") { restore() }
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                }
                if let termsURL = configuration.termsURL { Link("Terms", destination: termsURL) }
                if let privacyURL = configuration.privacyURL { Link("Privacy", destination: privacyURL) }
            }
            .font(.caption)

            Text("Subscriptions renew automatically unless cancelled in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var subscriptionProducts: [PurchaseProduct] {
        let products = purchaseManager.products.filter { $0.subscriptionPeriod != nil }
        return products.isEmpty ? purchaseManager.products : products
    }

    private var selectedProduct: PurchaseProduct? {
        selectedProductID.flatMap(purchaseManager.product(withID:)) ?? purchaseManager.preferredProduct
    }

    private func selectDefaultProduct() {
        guard selectedProductID == nil || purchaseManager.product(withID: selectedProductID ?? "") == nil else { return }
        selectedProductID = configuration.preferredProductID
            .flatMap(purchaseManager.product(withID:))?.id
            ?? purchaseManager.preferredProduct?.id
    }

    private func restore() {
        Task {
            switch await purchaseManager.restorePurchases() {
            case .restored: restoreMessage = "Your purchases have been restored."
            case .nothingToRestore: restoreMessage = "No previous purchases were found."
            case .failed(let failure):
                restoreMessage = failure.message
                purchaseManager.clearActivity()
            }
        }
    }

    private var purchaseFailure: PurchaseFailure? {
        if case .failed(let failure) = purchaseManager.activity { return failure }
        return nil
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(get: { purchaseFailure != nil }, set: { if !$0 { purchaseManager.clearActivity() } })
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }
}

public struct PremiumGate<Content: View, Locked: View>: View {
    private let decision: PremiumAccessDecision
    private let content: Content
    private let locked: (PremiumFeature) -> Locked

    public init(
        decision: PremiumAccessDecision,
        @ViewBuilder content: () -> Content,
        @ViewBuilder locked: @escaping (PremiumFeature) -> Locked
    ) {
        self.decision = decision
        self.content = content()
        self.locked = locked
    }

    public var body: some View {
        switch decision {
        case .allowed: content
        case .requiresPro(let feature): locked(feature)
        }
    }
}

public struct PremiumBadge: View {
    public init() {}
    public var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Requires Pro")
    }
}

public struct LockedFeatureOverlay: View {
    private let feature: PremiumFeature
    private let action: () -> Void

    public init(feature: PremiumFeature, action: @escaping () -> Void) {
        self.feature = feature
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text(feature.title).font(.headline)
                Text("Unlock with Pro").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(.regularMaterial)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("premium.locked.\(feature.id)")
    }
}

public struct SubscriptionSettingsSection: View {
    @Environment(\.openURL) private var openURL
    private let purchaseManager: PurchaseManager
    private let onUpgrade: () -> Void
    @State private var restoreMessage: String?

    public init(purchaseManager: PurchaseManager, onUpgrade: @escaping () -> Void) {
        self.purchaseManager = purchaseManager
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Section("Subscription") {
            LabeledContent("Status", value: purchaseManager.hasPro ? "Pro active" : "Free")
            if !purchaseManager.hasPro {
                Button("Upgrade to Pro", systemImage: "crown") { onUpgrade() }
            }
            Button("Restore Purchases", systemImage: "arrow.clockwise") { restore() }
                .disabled(purchaseManager.isBusy)
            Button("Manage Subscription", systemImage: "creditcard") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
            }
        }
        .alert("Restore Purchases", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private func restore() {
        Task {
            switch await purchaseManager.restorePurchases() {
            case .restored: restoreMessage = "Your purchases have been restored."
            case .nothingToRestore: restoreMessage = "No previous purchases were found."
            case .failed(let failure): restoreMessage = failure.message
            }
        }
    }
}
#endif
