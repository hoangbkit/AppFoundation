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

    /// Retained for source compatibility with configurations that explicitly
    /// supplied a `FoundationTheme`.
    public let theme: FoundationTheme

    /// A full `AppTheme` override. When nil, the paywall follows the active
    /// theme supplied through `.appFoundationTheme(_:)`.
    public let themeOverride: AppTheme?

    /// True for the theme-aware initializer and false for the legacy
    /// `FoundationTheme` override initializer.
    public let followsActiveTheme: Bool

    /// Creates a paywall that follows the active app theme.
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
        themeOverride: AppTheme? = nil
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
        self.theme = .indigo
        self.themeOverride = themeOverride
        self.followsActiveTheme = true
    }

    /// Creates a paywall with the older fixed `FoundationTheme` treatment.
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
        theme: FoundationTheme
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
        self.themeOverride = nil
        self.followsActiveTheme = false
    }
}

/// The original gradient paywall, supporting all configured recurring and lifetime plans.
public struct FoundationPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme

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
                PaywallThemeBackground(tokens: theme)

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
            .foregroundStyle(theme.primaryForeground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
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
                Button("OK", role: .cancel) { purchases.clearActivity() }
            } message: {
                Text(purchaseFailure?.message ?? PurchaseFailure.unknown.message)
            }
            .alert("Restore Purchases", isPresented: restoreAlertBinding) {
                Button("OK", role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.16))
                    .frame(width: 132, height: 132)

                Image(systemName: "crown.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.accent, theme.secondaryAccent)
            }

            FoundationPill(
                configuration.badge,
                systemImage: "sparkles",
                tint: theme.accent
            )

            Text(configuration.title)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryForeground)
                .multilineTextAlignment(.center)

            Text(configuration.subtitle)
                .font(.body)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
    }

    private var features: some View {
        themedCard {
            VStack(spacing: 18) {
                ForEach(configuration.features) { feature in
                    HStack(spacing: 14) {
                        Image(systemName: feature.systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 42, height: 42)
                            .background(
                                theme.accent.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.headline)
                                .foregroundStyle(theme.primaryForeground)
                            Text(feature.message)
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryForeground)
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
            themedCard {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading purchase options…")
                        .foregroundStyle(theme.secondaryForeground)
                    Spacer()
                }
            }
        case .failed(let failure):
            themedCard {
                VStack(spacing: 14) {
                    Label("Unable to load plans", systemImage: "wifi.exclamationmark")
                        .font(.headline)
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryForeground)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await purchases.loadProducts(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
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
        let rowRadius = min(theme.cardCornerRadius, 20)

        return Button {
            withAnimation(.snappy) {
                selectedProductID = product.id
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        isSelected ? theme.accent : theme.secondaryForeground.opacity(0.55)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(theme.primaryForeground)

                        if isHighlighted {
                            Text(configuration.highlightedProductBadge)
                                .font(.caption2.bold())
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(theme.accent.opacity(0.12), in: Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text(product.planLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Text("•")
                            .foregroundStyle(theme.secondaryForeground)
                        Text(product.billingDescription)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForeground)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundStyle(theme.primaryForeground)
            }
            .padding(18)
            .background(
                isSelected ? theme.accent.opacity(0.12) : theme.surface,
                in: RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.accent : theme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: theme.shadow.opacity(0.55), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct else { return }
            Task {
                await purchases.purchase(selectedProduct)
                if purchases.isEntitled { dismiss() }
            }
        } label: {
            HStack(spacing: 10) {
                if purchases.isBusy {
                    ProgressView().tint(.white)
                }
                Text(buttonTitle)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(FoundationPrimaryButtonStyle(theme: theme.foundationTheme))
        .disabled(selectedProduct == nil || purchases.isBusy)
        .opacity(selectedProduct == nil ? 0.55 : 1)
    }

    private var legalFooter: some View {
        VStack(spacing: 14) {
            Button("Restore Purchases") { restore() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
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
            .foregroundStyle(theme.accent)

            Text(PurchasePlanDisclosure.text(for: purchases.products))
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 10)
    }

    private func themedCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(20)
            .background(
                theme.surface,
                in: RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(theme.border)
            }
            .shadow(color: theme.shadow, radius: 18, y: 10)
    }

    private var theme: PaywallThemeTokens {
        PaywallThemeTokens(
            appTheme: configuration.themeOverride ?? environmentTheme,
            foundationOverride: configuration.followsActiveTheme ? nil : configuration.theme
        )
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

    private func restore() {
        Task {
            switch await purchases.restorePurchases() {
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

    private var purchaseFailure: PurchaseFailure? {
        if case .failed(let failure) = purchases.activity { return failure }
        return nil
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { purchaseFailure != nil },
            set: { if !$0 { purchases.clearActivity() } }
        )
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )
    }

    private func selectDefaultProductIfNeeded() {
        guard selectedProductID == nil
            || purchases.product(withID: selectedProductID ?? "") == nil
        else {
            return
        }
        selectedProductID = purchases.preferredProduct?.id
    }
}
#endif