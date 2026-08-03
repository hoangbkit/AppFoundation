#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style supporting recurring and lifetime plans.
public struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.appFoundationVisualStyle) private var visualStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(PurchaseManager.self) private var environmentPurchaseManager

    private let purchaseManagerOverride: PurchaseController?
    private let configuration: FoundationPaywallConfiguration
    private let rendersForScreenshot: Bool

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

    public init(
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String? = nil
    ) {
        self.purchaseManagerOverride = nil
        self.configuration = configuration
        self.rendersForScreenshot = false
        _selectedProductID = State(
            initialValue: initialSelectedProductID ?? configuration.highlightedProductID
        )
    }

    public init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String? = nil
    ) {
        self.init(
            purchases: purchases,
            configuration: configuration,
            initialSelectedProductID: initialSelectedProductID,
            rendersForScreenshot: false
        )
    }

    init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String?,
        rendersForScreenshot: Bool
    ) {
        self.purchaseManagerOverride = purchases
        self.configuration = configuration
        self.rendersForScreenshot = rendersForScreenshot
        _selectedProductID = State(
            initialValue: initialSelectedProductID
                ?? purchases.configuration.preferredProductID
                ?? configuration.highlightedProductID
        )
    }

    public var body: some View {
        Group {
            if rendersForScreenshot {
                screenshotBody
            } else {
                interactiveBody
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var interactiveBody: some View {
        NavigationStack {
            paywallBackground {
                ScrollView {
                    contentStack
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(visualStyle.toolbarVisibility, for: .navigationBar)
            .task {
                if purchases.products.isEmpty {
                    await purchases.loadProducts(force: true)
                }
                selectDefaultPlanIfNeeded()
            }
            .onChange(of: purchases.products) { _, _ in
                selectDefaultPlanIfNeeded()
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
    }

    private var screenshotBody: some View {
        paywallBackground {
            GeometryReader { proxy in
                contentStack
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .center
                    )
            }
        }
    }

    private func paywallBackground<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            PaywallThemeBackground(tokens: theme)
            content()
        }
        .foregroundStyle(primaryForeground)
    }

    private var contentStack: some View {
        VStack(spacing: 28) {
            header
            planCard
            legalFooter
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ProCrownIcon()

            Text(configuration.title)
                .font(
                    .system(
                        size: 32,
                        weight: .semibold,
                        design: visualStyle.resolvedFontDesign(fallback: .rounded)
                    )
                )
                .foregroundStyle(primaryForeground)
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(secondaryForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pro")
                    .font(
                        .system(
                            size: 26,
                            weight: .semibold,
                            design: visualStyle.resolvedFontDesign(fallback: .serif)
                        )
                    )
                    .foregroundStyle(primaryForeground)

                Text("Choose the plan that fits you")
                    .font(.subheadline)
                    .foregroundStyle(secondaryForeground)
            }

            productContent

            if !purchases.products.isEmpty {
                purchaseButton
            }

            if !resolvedFeatures.isEmpty {
                Divider().overlay(surfaceBorder)
                featureList
            }
        }
        .padding(20)
        .foundationVisualSurface(
            solidColor: planSurface,
            borderColor: surfaceBorder,
            shadowColor: theme.shadow,
            fallbackCornerRadius: theme.cardCornerRadius,
            fallbackShadowRadius: 18,
            fallbackShadowOffset: 10
        )
    }

    @ViewBuilder
    private var productContent: some View {
        switch purchases.productLoadingState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        case .failed(let failure):
            VStack(spacing: 12) {
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(secondaryForeground)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await purchases.loadProducts(force: true) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loaded:
            if usesStackedPlanLayout {
                VStack(spacing: 10) {
                    ForEach(purchases.products) { product in
                        stackedPlanOption(for: product, badge: badge(for: product))
                    }
                }
            } else {
                LazyVGrid(columns: planColumns, spacing: 12) {
                    ForEach(purchases.products) { product in
                        cardPlanOption(for: product, badge: badge(for: product))
                    }
                }
            }
        }
    }

    private func cardPlanOption(for product: StoreProduct, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        let optionRadius = min(theme.cardCornerRadius, 16)

        return Button { select(product) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    selectionIndicator(isSelected: isSelected)
                    Spacer(minLength: 6)
                    if let badge { planBadge(badge) }
                }

                Text(product.planLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(primaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                Text(product.isLifetime ? "Pay once" : product.billingDescription)
                    .font(.footnote)
                    .foregroundStyle(secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .foundationVisualSurface(
                solidColor: optionSurface(isSelected: isSelected),
                borderColor: isSelected ? theme.accent : surfaceBorder,
                shadowColor: theme.shadow.opacity(0.55),
                fallbackCornerRadius: optionRadius,
                borderLineWidth: isSelected ? 1.5 : 1,
                fallbackShadowRadius: 0,
                fallbackShadowOffset: 0
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stackedPlanOption(for product: StoreProduct, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        let optionRadius = min(theme.cardCornerRadius, 16)

        return Button { select(product) } label: {
            HStack(spacing: 12) {
                selectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.planLabel)
                        .font(.headline)
                        .foregroundStyle(primaryForeground)
                    Text(product.billingDescription)
                        .font(.caption)
                        .foregroundStyle(secondaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    if let badge { planBadge(badge) }
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .foundationVisualSurface(
                solidColor: optionSurface(isSelected: isSelected),
                borderColor: isSelected ? theme.accent : surfaceBorder,
                shadowColor: theme.shadow.opacity(0.55),
                fallbackCornerRadius: optionRadius,
                borderLineWidth: isSelected ? 1.5 : 1,
                fallbackShadowRadius: 0,
                fallbackShadowOffset: 0
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? theme.accent : secondaryForeground.opacity(0.45),
                    lineWidth: 1.5
                )
            if isSelected {
                Circle().fill(theme.accent).padding(4)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func planBadge(_ badge: String) -> some View {
        if visualStyle.preservesLegacyPresentation {
            Text(badge)
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(theme.accent.opacity(0.15), in: Capsule())
                .foregroundStyle(theme.accent)
                .lineLimit(1)
        } else {
            FoundationPill(badge, tint: theme.accent)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if visualStyle.primaryAction == .automatic {
            Button(action: purchaseSelectedProduct) {
                HStack {
                    if purchases.isBusy { ProgressView().tint(.black) }
                    Text(purchaseButtonTitle).font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.white, in: Capsule())
            .foregroundStyle(.black)
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            .disabled(selectedProduct == nil || purchases.isBusy)
        } else {
            Button(action: purchaseSelectedProduct) {
                HStack {
                    if purchases.isBusy { ProgressView() }
                    Text(purchaseButtonTitle).font(.headline)
                }
            }
            .buttonStyle(FoundationPrimaryButtonStyle(theme: theme.foundationTheme))
            .disabled(selectedProduct == nil || purchases.isBusy)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything in Free, plus:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryForeground)

            ForEach(resolvedFeatures) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: feature.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 20)
                    Text(feature.message)
                        .font(.subheadline)
                        .foregroundStyle(primaryForeground)
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text(PurchasePlanDisclosure.text(for: purchases.products))
                .font(.caption2)
                .foregroundStyle(secondaryForeground)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: termsURL)
                Link("Privacy Policy", destination: privacyURL)
                Button("Restore Purchases") { restore() }
                    .disabled(purchases.isBusy)
            }
            .font(.caption)
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, 8)
    }

    private var purchases: PurchaseController {
        purchaseManagerOverride ?? environmentPurchaseManager
    }

    private var resolvedFeatures: [FoundationPaywallFeature] {
        if !configuration.features.isEmpty { return configuration.features }
        return purchases.features.map(FoundationPaywallFeature.init)
    }

    private var usesStackedPlanLayout: Bool {
        purchases.products.count != 2 || dynamicTypeSize.isAccessibilitySize
    }

    private var planColumns: [GridItem] {
        if purchases.products.count <= 1 || dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var theme: PaywallThemeTokens {
        PaywallThemeTokens(
            appTheme: configuration.themeOverride ?? environmentTheme,
            foundationOverride: configuration.followsActiveTheme ? nil : configuration.theme
        )
    }

    private var primaryForeground: Color {
        visualStyle.background == .systemGrouped ? .primary : theme.primaryForeground
    }

    private var secondaryForeground: Color {
        visualStyle.background == .systemGrouped ? .secondary : theme.secondaryForeground
    }

    private var planSurface: Color {
        if visualStyle.background == .systemGrouped {
            return systemGroupedSurface
        }
        return theme.surface
    }

    private func optionSurface(isSelected: Bool) -> Color {
        if isSelected {
            return theme.accent.opacity(0.12)
        }
        if visualStyle.background == .systemGrouped {
            return systemGroupedElevatedSurface
        }
        return theme.elevatedSurface
    }

    private var surfaceBorder: Color {
        visualStyle.background == .systemGrouped
            ? Color.primary.opacity(0.10)
            : theme.border
    }

    private var systemGroupedSurface: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        theme.surface
        #endif
    }

    private var systemGroupedElevatedSurface: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .tertiarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        theme.elevatedSurface
        #endif
    }

    private var selectedProduct: StoreProduct? {
        selectedProductID.flatMap(purchases.product(withID:))
            ?? purchases.preferredProduct
    }

    private var purchaseButtonTitle: String {
        guard let selectedProduct else { return configuration.purchaseButtonTitle }
        return "\(configuration.purchaseButtonTitle) with \(selectedProduct.planLabel)"
    }

    private func purchaseSelectedProduct() {
        guard let selectedProduct else { return }
        Task {
            await purchases.purchase(selectedProduct)
            if purchases.isEntitled { dismiss() }
        }
    }

    private func select(_ product: StoreProduct) {
        withAnimation(.snappy) { selectedProductID = product.id }
    }

    private func selectDefaultPlanIfNeeded() {
        guard selectedProductID == nil
            || purchases.product(withID: selectedProductID ?? "") == nil
        else { return }
        selectedProductID = purchases.preferredProduct?.id
    }

    private func badge(for product: StoreProduct) -> String? {
        configuration.highlightedProductID == product.id
            ? configuration.highlightedProductBadge
            : nil
    }

    private func restore() {
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

    private var termsURL: URL {
        configuration.termsURL ?? URL(string: "https://example.com/terms")!
    }

    private var privacyURL: URL {
        configuration.privacyURL ?? URL(string: "https://example.com/privacy")!
    }
}
#endif
