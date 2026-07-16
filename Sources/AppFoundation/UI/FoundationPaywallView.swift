#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

public struct FoundationPaywallFeature: Identifiable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let message: String

    public init(
        id: String,
        systemImage: String,
        title: String,
        message: String
    ) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }
}

public struct FoundationPaywallConfiguration {
    public let badge: String
    public let title: String
    public let subtitle: String
    public let features: [FoundationPaywallFeature]
    public let purchaseButtonTitle: String
    public let highlightedProductID: String?
    public let highlightedProductBadge: String
    public let privacyURL: URL?
    public let termsURL: URL?
    public let theme: FoundationTheme

    public init(
        badge: String = "UNLOCK EVERYTHING",
        title: String,
        subtitle: String,
        features: [FoundationPaywallFeature],
        purchaseButtonTitle: String = "Continue",
        highlightedProductID: String? = nil,
        highlightedProductBadge: String = "BEST VALUE",
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        theme: FoundationTheme = .indigo
    ) {
        self.badge = badge
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.purchaseButtonTitle = purchaseButtonTitle
        self.highlightedProductID = highlightedProductID
        self.highlightedProductBadge = highlightedProductBadge
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.theme = theme
    }
}

public struct FoundationPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    private let purchases: PurchaseController
    private let configuration: FoundationPaywallConfiguration

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

    public init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration
    ) {
        self.purchases = purchases
        self.configuration = configuration
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FoundationBackground(theme: configuration.theme)

                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        features
                        products
                        purchaseButton
                        legalFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                if purchases.products.isEmpty {
                    await purchases.loadProducts()
                }
                selectDefaultProductIfNeeded()
            }
            .onChange(of: purchases.products) { _, _ in
                selectDefaultProductIfNeeded()
            }
            .alert("Purchase", isPresented: purchaseErrorBinding) {
                Button("OK", role: .cancel) {
                    purchases.clearActivity()
                }
            } message: {
                Text(purchaseFailure?.message ?? PurchaseFailure.unknown.message)
            }
            .alert("Restore Purchases", isPresented: restoreAlertBinding) {
                Button("OK", role: .cancel) {
                    restoreMessage = nil
                }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(configuration.theme.primary.opacity(0.16))
                    .frame(width: 132, height: 132)

                Image(systemName: "crown.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(configuration.theme.primary, configuration.theme.secondary)
            }

            FoundationPill(
                configuration.badge,
                systemImage: "sparkles",
                tint: configuration.theme.primary
            )

            Text(configuration.title)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(configuration.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
    }

    private var features: some View {
        FoundationCard(theme: configuration.theme) {
            VStack(spacing: 18) {
                ForEach(configuration.features) { feature in
                    HStack(spacing: 14) {
                        Image(systemName: feature.systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(configuration.theme.primary)
                            .frame(width: 42, height: 42)
                            .background(configuration.theme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var products: some View {
        switch purchases.productLoadingState {
        case .idle, .loading:
            FoundationCard(theme: configuration.theme) {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading purchase options…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        case .failed(let failure):
            FoundationCard(theme: configuration.theme) {
                VStack(spacing: 14) {
                    Label("Unable to load plans", systemImage: "wifi.exclamationmark")
                        .font(.headline)
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task {
                            await purchases.loadProducts(force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(configuration.theme.primary)
                }
                .frame(maxWidth: .infinity)
            }
        case .loaded:
            VStack(spacing: 12) {
                ForEach(purchases.products) { product in
                    productRow(product)
                }
            }
        }
    }

    private func productRow(_ product: StoreProduct) -> some View {
        let isSelected = selectedProductID == product.id
        let isHighlighted = configuration.highlightedProductID == product.id

        return Button {
            withAnimation(.snappy) {
                selectedProductID = product.id
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? configuration.theme.primary : Color.secondary.opacity(0.45))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isHighlighted {
                            Text(configuration.highlightedProductBadge)
                                .font(.caption2.bold())
                                .foregroundStyle(configuration.theme.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(configuration.theme.primary.opacity(0.12), in: Capsule())
                        }
                    }

                    if let period = product.subscriptionPeriod {
                        Text("Billed every \(period.shortLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            .padding(18)
            .background(
                isSelected ? configuration.theme.primary.opacity(0.10) : Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? configuration.theme.primary : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct else {
                return
            }
            Task {
                await purchases.purchase(selectedProduct)
                if purchases.isEntitled {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if purchases.isBusy {
                    ProgressView()
                        .tint(.white)
                }
                Text(buttonTitle)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(FoundationPrimaryButtonStyle(theme: configuration.theme))
        .disabled(selectedProduct == nil || purchases.isBusy)
        .opacity(selectedProduct == nil ? 0.55 : 1)
    }

    private var legalFooter: some View {
        VStack(spacing: 14) {
            Button("Restore Purchases") {
                Task {
                    let outcome = await purchases.restorePurchases()
                    switch outcome {
                    case .restored:
                        restoreMessage = "Your purchases have been restored."
                    case .nothingToRestore:
                        restoreMessage = "No previous purchases were found."
                    case .failed(let failure):
                        restoreMessage = failure.message
                        purchases.clearActivity()
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .disabled(purchases.isBusy)

            HStack(spacing: 18) {
                if let privacyURL = configuration.privacyURL {
                    Link("Privacy", destination: privacyURL)
                }
                if let termsURL = configuration.termsURL {
                    Link("Terms", destination: termsURL)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 10)
    }

    private var selectedProduct: StoreProduct? {
        if let selectedProductID {
            return purchases.product(withID: selectedProductID)
        }
        return purchases.preferredProduct
    }

    private var buttonTitle: String {
        if case .purchasing = purchases.activity {
            return "Processing…"
        }
        return configuration.purchaseButtonTitle
    }

    private var purchaseFailure: PurchaseFailure? {
        if case .failed(let failure) = purchases.activity {
            return failure
        }
        return nil
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { purchaseFailure != nil },
            set: { isPresented in
                if !isPresented {
                    purchases.clearActivity()
                }
            }
        )
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { isPresented in
                if !isPresented {
                    restoreMessage = nil
                }
            }
        )
    }

    private func selectDefaultProductIfNeeded() {
        guard selectedProductID == nil || purchases.product(withID: selectedProductID ?? "") == nil else {
            return
        }
        selectedProductID = purchases.preferredProduct?.id
    }
}
#endif
