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
        features: [PaywallFeature],
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

/// The primary theme-aware paywall provided by AppFoundation.
///
/// Every configured entitlement product is presented in catalog order. Weekly,
/// monthly, yearly, and lifetime products can be mixed in the same paywall.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let purchaseManager: PurchaseManager
    private let configuration: PaywallConfiguration

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

    public init(purchaseManager: PurchaseManager, configuration: PaywallConfiguration) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                PaywallThemeBackground(tokens: theme)

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        planContainer
                        legalFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(theme.primaryForeground)
            .toolbar {
                if configuration.showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("paywall.close")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                if purchaseManager.products.isEmpty {
                    await purchaseManager.loadProducts(force: true)
                }
                selectDefaultProduct()
            }
            .onChange(of: purchaseManager.products) { _, _ in
                selectDefaultProduct()
            }
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
        .tint(theme.accent)
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(configuration.title)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.primaryForeground)
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(theme.secondaryForeground)
        }
        .multilineTextAlignment(.center)
    }

    private var planContainer: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.planTitle)
                    .font(.title2.weight(.semibold))
                Text(configuration.planSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForeground)
            }

            productContent
            purchaseButton

            Divider().overlay(theme.border)
            featureList
        }
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

    @ViewBuilder
    private var productContent: some View {
        switch purchaseManager.productLoadingState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        case .failed(let failure):
            VStack(spacing: 12) {
                Text(failure.message)
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await purchaseManager.loadProducts(force: true) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        case .loaded:
            LazyVGrid(columns: planColumns, spacing: 12) {
                ForEach(purchaseManager.products) { product in
                    planOption(product)
                }
            }
        }
    }

    private func planOption(_ product: PurchaseProduct) -> some View {
        let selected = selectedProductID == product.id
        let highlighted = configuration.highlightedProductID == product.id
        let optionRadius = min(theme.cardCornerRadius, 18)

        return Button {
            withAnimation(.snappy) {
                selectedProductID = product.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? theme.accent : theme.secondaryForeground)

                    Spacer(minLength: 6)

                    if highlighted {
                        Text(configuration.highlightedProductBadge)
                            .font(.caption2.bold())
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(theme.accent.opacity(0.13), in: Capsule())
                    }
                }

                Text(product.planLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)

                Text(product.displayName)
                    .font(.headline)
                    .foregroundStyle(theme.primaryForeground)
                    .lineLimit(2)

                Text(product.displayPrice)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryForeground)

                Text(configuration.planDetail(product) ?? product.billingDescription)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
            .padding(14)
            .background(
                selected ? theme.accent.opacity(0.12) : theme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
                    .strokeBorder(
                        selected ? theme.accent : theme.border,
                        lineWidth: selected ? 1.5 : 1
                    )
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
        .tint(theme.accent)
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
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryForeground)
                        Text(feature.message)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryForeground)
                    }
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Button("Restore Purchases") { restore() }

                if purchaseManager.products.contains(where: \.isRecurring) {
                    Button("Manage Subscription") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                if let termsURL = configuration.termsURL {
                    Link("Terms", destination: termsURL)
                }
                if let privacyURL = configuration.privacyURL {
                    Link("Privacy", destination: privacyURL)
                }
            }

            Text(PurchasePlanDisclosure.text(for: purchaseManager.products))
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)
        }
        .font(.caption)
        .foregroundStyle(theme.accent)
    }

    private var planColumns: [GridItem] {
        if purchaseManager.products.count <= 1 || dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var theme: PaywallThemeTokens {
        PaywallThemeTokens(
            appTheme: configuration.themeOverride ?? environmentTheme,
            accentOverride: configuration.tint
        )
    }

    private var selectedProduct: PurchaseProduct? {
        selectedProductID.flatMap(purchaseManager.product(withID:))
            ?? purchaseManager.preferredProduct
    }

    private func selectDefaultProduct() {
        guard selectedProductID == nil
            || purchaseManager.product(withID: selectedProductID ?? "") == nil
        else {
            return
        }

        selectedProductID = configuration.preferredProductID
            .flatMap(purchaseManager.product(withID:))?.id
            ?? purchaseManager.preferredProduct?.id
    }

    private func restore() {
        Task {
            switch await purchaseManager.restorePurchases() {
            case .restored:
                restoreMessage = "Your purchases have been restored."
            case .nothingToRestore:
                restoreMessage = "No previous purchases were found."
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
        Binding(
            get: { purchaseFailure != nil },
            set: { if !$0 { purchaseManager.clearActivity() } }
        )
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )
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
    @Environment(\.appFoundationTheme) private var theme

    public init() {}

    public var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .foregroundStyle(theme.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.accentColor.opacity(0.12), in: Capsule())
            .accessibilityLabel("Requires Pro")
    }
}

public struct PremiumButton<Label: View>: View {
    private let decision: PremiumAccessDecision
    private let action: () -> Void
    private let onRequestUpgrade: (PremiumFeature) -> Void
    private let label: Label

    public init(
        decision: PremiumAccessDecision,
        action: @escaping () -> Void,
        onRequestUpgrade: @escaping (PremiumFeature) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.decision = decision
        self.action = action
        self.onRequestUpgrade = onRequestUpgrade
        self.label = label()
    }

    public var body: some View {
        Button {
            switch decision {
            case .allowed:
                action()
            case .requiresPro(let feature):
                onRequestUpgrade(feature)
            }
        } label: {
            HStack(spacing: 8) {
                label
                if case .requiresPro = decision { PremiumBadge() }
            }
        }
    }
}

public struct LockedFeatureOverlay: View {
    @Environment(\.appFoundationTheme) private var theme

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
                    .foregroundStyle(theme.accentColor)
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryForegroundColor)
                Text("Unlock with Pro")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(theme.elevatedSurfaceColor)
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
            if purchaseManager.products.contains(where: \.isRecurring) {
                Button("Manage Subscription", systemImage: "creditcard") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                }
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
            case .restored:
                restoreMessage = "Your purchases have been restored."
            case .nothingToRestore:
                restoreMessage = "No previous purchases were found."
            case .failed(let failure):
                restoreMessage = failure.message
            }
        }
    }
}
#endif