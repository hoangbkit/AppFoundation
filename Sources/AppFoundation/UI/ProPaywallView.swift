#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style supporting recurring and lifetime plans.
public struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(PurchaseManager.self) private var environmentPurchaseManager

    private let purchaseManagerOverride: PurchaseController?
    private let configuration: FoundationPaywallConfiguration
    private let rendersForScreenshot: Bool

    @State private var selectedProductID: String?
    @State private var restoreModel = RestorePurchasesRowModel()

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
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if purchases.products.isEmpty {
                    await purchases.loadProducts(force: true)
                }
                selectDefaultPlanIfNeeded()
                restoreModel.reconcile(using: purchases)
            }
            .onChange(of: purchases.products) { _, _ in
                selectDefaultPlanIfNeeded()
            }
            .onChange(of: purchases.activity) { _, _ in
                restoreModel.reconcile(using: purchases)
            }
            .onDisappear {
                if restoreModel.hasLocalAttemptInFlight {
                    restoreModel.cancel(using: purchases)
                }
            }
            .alert("Purchase", isPresented: purchaseErrorBinding) {
                Button("OK", role: .cancel) { purchases.clearActivity() }
            } message: {
                Text(purchaseFailure?.message ?? PurchaseFailure.unknown.message)
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
        VStack(spacing: 24) {
            planCard
            legalFooter
        }
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

            if !resolvedFeatures.isEmpty {
                Divider().overlay(theme.border)
                featureList
            }
        }
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
            VStack(spacing: 10) {
                ForEach(purchases.products) { product in
                    stackedPlanOption(for: product, badge: badge(for: product))
                }
            }
        }
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
                        .foregroundStyle(theme.primaryForeground)

                    if let introductoryOfferHeadline = product.introductoryOfferHeadline {
                        Text(introductoryOfferHeadline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)

                        if let billingDescription = product.postIntroductoryOfferBillingDescription {
                            Text(billingDescription)
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(product.isLifetime ? "Pay once" : product.billingDescription)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    if let badge { planBadge(badge) }
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
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
        VStack(spacing: 8) {
            Button {
                guard let selectedProduct else { return }
                Task {
                    await purchases.purchase(selectedProduct)
                    if purchases.isEntitled { dismiss() }
                }
            } label: {
                HStack {
                    if purchases.isPurchasing { ProgressView().tint(.black) }
                    Text(purchaseButtonTitle).font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.white, in: Capsule())
            .foregroundStyle(.black)
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            .opacity(purchases.isRestoring ? 0.55 : 1)
            .disabled(selectedProduct == nil || purchases.isBusy)

            if let introductoryOfferDisclosure = selectedProduct?.introductoryOfferDisclosure {
                Text(introductoryOfferDisclosure)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything in Free, plus:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryForeground)

            ForEach(resolvedFeatures) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: feature.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 20)
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
                Link("Terms of Use", destination: configuration.termsURL)
                Link("Privacy Policy", destination: configuration.privacyURL)
                restoreFooterAction
            }
            .font(.caption)
            .foregroundStyle(theme.accent)

            restoreFooterMessage
        }
        .padding(.horizontal, 8)
    }

    private var restoreFooterAction: some View {
        Button {
            switch restoreModel.phase {
            case .restoring:
                restoreModel.cancel(using: purchases)
            case .idle, .result(.nothingToRestore), .result(.failure):
                restoreModel.start(using: purchases, configuration: restoreConfiguration)
            case .result(.restored):
                break
            }
        } label: {
            HStack(spacing: 4) {
                if restoreModel.phase == .restoring {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(restoreFooterLabel)
            }
        }
        .buttonStyle(.plain)
        .disabled(
            (purchases.isBusy && restoreModel.phase != .restoring)
                || restoreModel.phase == .result(.restored)
        )
        .opacity(purchases.isBusy && restoreModel.phase != .restoring ? 0.5 : 1)
        .accessibilityLabel(restoreFooterAccessibilityLabel)
    }

    @ViewBuilder
    private var restoreFooterMessage: some View {
        switch restoreModel.phase {
        case .idle, .restoring, .result(.restored):
            EmptyView()
        case .result(.nothingToRestore):
            Text("No previous purchases were found for this Apple Account.")
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)
        case .result(.failure(let failure)):
            Text(failure.message)
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var restoreConfiguration: RestorePurchasesRowConfiguration {
        RestorePurchasesRowConfiguration(title: "Restore Purchases")
    }

    private var restoreFooterLabel: String {
        switch restoreModel.phase {
        case .idle:
            "Restore Purchases"
        case .restoring:
            "Restoring…"
        case .result(.restored):
            "Purchases Restored"
        case .result(.nothingToRestore):
            "Restore Again"
        case .result(.failure):
            "Retry Restore"
        }
    }

    private var restoreFooterAccessibilityLabel: String {
        switch restoreModel.phase {
        case .restoring:
            "Restoring purchases. Double tap to cancel."
        default:
            restoreFooterLabel
        }
    }

    private var purchases: PurchaseController {
        purchaseManagerOverride ?? environmentPurchaseManager
    }

    private var resolvedFeatures: [FoundationPaywallFeature] {
        if !configuration.features.isEmpty { return configuration.features }
        return purchases.features.map(FoundationPaywallFeature.init)
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
        guard let selectedProduct else { return configuration.purchaseButtonTitle }
        return selectedProduct.purchaseActionTitle(
            defaultTitle: configuration.purchaseButtonTitle
        )
    }

    private func select(_ product: StoreProduct) {
        withAnimation(.snappy) { selectedProductID = product.id }
    }

    private func selectDefaultPlanIfNeeded() {
        guard selectedProductID == nil
            || purchases.product(withID: selectedProductID ?? "") == nil
        else { return }
        selectedProductID = purchases.preferredProduct?.id
            ?? purchases.product(withID: configuration.highlightedProductID ?? "")?.id
    }

    private func badge(for product: StoreProduct) -> String? {
        let configuredBadge = configuration.highlightedProductID == product.id
            ? configuration.highlightedProductBadge
            : nil

        if let configuredBadge, isSavingsPercentageBadge(configuredBadge) {
            return configuredBadge
        }

        if isYearlyPlan(product),
           let monthlyProduct = purchases.products.first(where: isMonthlyPlan),
           let savingsPercentage = yearlySavingsPercentage(
               monthlyPrice: monthlyProduct.price,
               yearlyPrice: product.price
           ) {
            return "SAVE \(savingsPercentage)%"
        }

        return configuredBadge
    }

    private func isMonthlyPlan(_ product: StoreProduct) -> Bool {
        guard let period = product.subscriptionPeriod else { return false }
        return period.value == 1 && period.unit == .month
    }

    private func isYearlyPlan(_ product: StoreProduct) -> Bool {
        guard let period = product.subscriptionPeriod else { return false }
        return (period.value == 1 && period.unit == .year)
            || (period.value == 12 && period.unit == .month)
    }

    private func yearlySavingsPercentage(
        monthlyPrice: Double,
        yearlyPrice: Double
    ) -> Int? {
        let annualizedMonthlyPrice = monthlyPrice * 12
        guard annualizedMonthlyPrice > 0,
              yearlyPrice >= 0,
              yearlyPrice < annualizedMonthlyPrice
        else { return nil }

        let percentage = ((annualizedMonthlyPrice - yearlyPrice) / annualizedMonthlyPrice) * 100
        return min(100, max(1, Int(percentage.rounded())))
    }

    private func isSavingsPercentageBadge(_ badge: String) -> Bool {
        let normalizedBadge = badge.lowercased()
        return badge.contains("%")
            && (normalizedBadge.contains("save") || normalizedBadge.contains("off"))
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
}
#endif
