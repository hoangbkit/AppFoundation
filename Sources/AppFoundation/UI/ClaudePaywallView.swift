#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style supporting recurring and lifetime plans.
public struct ClaudePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let purchases: PurchaseController
    private let configuration: FoundationPaywallConfiguration
    private let rendersForScreenshot: Bool

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

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
        self.purchases = purchases
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
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .foregroundStyle(theme.primaryForeground)
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
            Text(configuration.title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.primaryForeground)
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(theme.secondaryForeground)
        }
        .multilineTextAlignment(.center)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pro")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.primaryForeground)
                Text("Choose the plan that fits you")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForeground)
            }

            productContent

            if !purchases.products.isEmpty {
                purchaseButton
            }

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
        switch purchases.productLoadingState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        case .failed(let failure):
            VStack(spacing: 12) {
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForeground)
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

        return Button {
            select(product)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    selectionIndicator(isSelected: isSelected)

                    Spacer(minLength: 6)

                    if let badge {
                        planBadge(badge)
                    }
                }

                Text(product.planLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primaryForeground)
                Text(product.isLifetime ? "Pay once" : product.billingDescription)
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                isSelected ? theme.accent.opacity(0.12) : theme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.accent : theme.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stackedPlanOption(for product: StoreProduct, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        let optionRadius = min(theme.cardCornerRadius, 16)

        return Button {
            select(product)
        } label: {
            HStack(spacing: 12) {
                selectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.planLabel)
                        .font(.headline)
                        .foregroundStyle(theme.primaryForeground)

                    Text(product.billingDescription)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    if let badge {
                        planBadge(badge)
                    }

                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                isSelected ? theme.accent.opacity(0.12) : theme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: optionRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.accent : theme.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? theme.accent : theme.secondaryForeground.opacity(0.45),
                    lineWidth: 1.5
                )
            if isSelected {
                Circle().fill(theme.accent).padding(4)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    private func planBadge(_ badge: String) -> some View {
        Text(badge)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.accent.opacity(0.15), in: Capsule())
            .foregroundStyle(theme.accent)
            .lineLimit(1)
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct else { return }
            Task {
                await purchases.purchase(selectedProduct)
                if purchases.isEntitled { dismiss() }
            }
        } label: {
            HStack {
                if purchases.isBusy { ProgressView().tint(.black) }
                Text(purchaseButtonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(
            Color.white,
            in: Capsule()
        )
        .foregroundStyle(.black)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .disabled(selectedProduct == nil || purchases.isBusy)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything in Free, plus:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryForeground)

            ForEach(configuration.features) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    Text(feature.message)
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryForeground)
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text(PurchasePlanDisclosure.text(for: purchases.products))
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
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

    private var usesStackedPlanLayout: Bool {
        purchases.products.count >= 3 || dynamicTypeSize.isAccessibilitySize
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

    private var selectedProduct: StoreProduct? {
        selectedProductID.flatMap(purchases.product(withID:))
            ?? purchases.preferredProduct
    }

    private var purchaseButtonTitle: String {
        guard let selectedProduct else {
            return configuration.purchaseButtonTitle
        }
        return "\(configuration.purchaseButtonTitle) with \(selectedProduct.planLabel)"
    }

    private func select(_ product: StoreProduct) {
        withAnimation(.snappy) {
            selectedProductID = product.id
        }
    }

    private func selectDefaultPlanIfNeeded() {
        guard selectedProductID == nil
            || purchases.product(withID: selectedProductID ?? "") == nil
        else {
            return
        }
        selectedProductID = purchases.preferredProduct?.id
    }

    private func badge(for product: StoreProduct) -> String? {
        if configuration.highlightedProductID == product.id {
            return configuration.highlightedProductBadge
        }

        guard product.subscriptionPeriod?.unit == .year,
              let monthly = purchases.products.first(where: {
                  $0.subscriptionPeriod?.unit == .month && $0.subscriptionPeriod?.value == 1
              }),
              monthly.price > 0
        else {
            return nil
        }

        let yearlyCostAtMonthlyRate = monthly.price * 12
        let savings = Int(
            ((yearlyCostAtMonthlyRate - product.price) / yearlyCostAtMonthlyRate * 100).rounded()
        )
        return savings > 0 ? "Save \(savings)%" : nil
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
