#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style supporting recurring and lifetime plans.
public struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFoundationTheme) private var environmentTheme
    @Environment(PurchaseManager.self) private var environmentPurchaseManager
    @Environment(\.appAnalytics) private var analytics

    private let purchaseManagerOverride: PurchaseController?
    private let configuration: FoundationPaywallConfiguration
    private let rendersForScreenshot: Bool
    private let onPurchased: ((StoreProduct) -> Void)?
    private let onRestored: (() -> Void)?
    private let onClose: (() -> Void)?

    @State private var selectedProductID: String?
    @State private var restoreModel = RestorePurchasesRowModel()
    @State private var didTrackPaywallView = false
    @State private var didCompleteCommerce = false
    @State private var isOfferCodeRedemptionPresented = false
    @State private var offerCodeErrorMessage: String?

    public init(
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String? = nil,
        onPurchased: ((StoreProduct) -> Void)? = nil,
        onRestored: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.purchaseManagerOverride = nil
        self.configuration = configuration
        self.rendersForScreenshot = false
        self.onPurchased = onPurchased
        self.onRestored = onRestored
        self.onClose = onClose
        _selectedProductID = State(
            initialValue: initialSelectedProductID ?? configuration.highlightedProductID
        )
    }

    public init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String? = nil,
        onPurchased: ((StoreProduct) -> Void)? = nil,
        onRestored: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            purchases: purchases,
            configuration: configuration,
            initialSelectedProductID: initialSelectedProductID,
            rendersForScreenshot: false,
            onPurchased: onPurchased,
            onRestored: onRestored,
            onClose: onClose
        )
    }

    init(
        purchases: PurchaseController,
        configuration: FoundationPaywallConfiguration,
        initialSelectedProductID: String?,
        rendersForScreenshot: Bool,
        onPurchased: ((StoreProduct) -> Void)? = nil,
        onRestored: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.purchaseManagerOverride = purchases
        self.configuration = configuration
        self.rendersForScreenshot = rendersForScreenshot
        self.onPurchased = onPurchased
        self.onRestored = onRestored
        self.onClose = onClose
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
                    Button("Close", systemImage: "xmark") { close() }
                        .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !didTrackPaywallView {
                    didTrackPaywallView = true
                    track(ProPaywallAnalytics.paywallViewed)
                }

                await purchases.refreshProductsForPresentation()
                await purchases.refreshEntitlements()
                selectDefaultPlanIfNeeded()
                restoreModel.reconcile(using: purchases)
            }
            .onChange(of: purchases.products) { _, _ in
                selectDefaultPlanIfNeeded()
            }
            .onChange(of: purchases.activity) { _, _ in
                restoreModel.reconcile(using: purchases)
            }
            .onChange(of: restoreModel.phase) { oldPhase, newPhase in
                trackRestoreTransition(from: oldPhase, to: newPhase)
            }
            .onDisappear {
                if restoreModel.hasLocalAttemptInFlight {
                    restoreModel.cancel(using: purchases)
                }
                if !didCompleteCommerce {
                    track(ProPaywallAnalytics.paywallClosed)
                }
            }
            .offerCodeRedemption(isPresented: $isOfferCodeRedemptionPresented) { result in
                switch result {
                case .success:
                    track(ProPaywallAnalytics.offerCodeSucceeded)
                    Task {
                        await purchases.refreshEntitlements()
                    }
                case .failure(let error):
                    track(ProPaywallAnalytics.offerCodeFailed(error))
                    offerCodeErrorMessage = error.localizedDescription
                }
            }
            .alert("Purchase", isPresented: purchaseErrorBinding) {
                Button("OK", role: .cancel) { purchases.clearActivity() }
            } message: {
                Text(purchaseFailure?.message ?? PurchaseFailure.unknown.message)
            }
            .alert("Redeem Code", isPresented: offerCodeErrorBinding) {
                Button("OK", role: .cancel) { offerCodeErrorMessage = nil }
            } message: {
                Text(offerCodeErrorMessage ?? "Unable to redeem this offer code.")
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

            if !paywallProducts.isEmpty {
                purchaseButton

                if let disclosure = selectedProduct?.introductoryOfferDisclosure {
                    Text(disclosure)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
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
            if paywallProducts.isEmpty {
                Text("No Pro purchase options are available right now.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(paywallProducts) { product in
                        stackedPlanOption(for: product, badge: badge(for: product))
                    }
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
                    if let headline = product.introductoryOfferHeadline {
                        Text(headline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)

                        if let postOffer = product.postIntroductoryOfferBillingDescription {
                            Text(postOffer)
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
        Button {
            guard let selectedProduct,
                  !purchases.isBusy,
                  !purchases.isPurchasePending
            else { return }

            track(ProPaywallAnalytics.purchaseStarted(selectedProduct))

            Task {
                let outcome = await purchases.purchase(selectedProduct)

                if case .failed(let failure) = purchases.activity {
                    track(
                        ProPaywallAnalytics.purchaseFailed(
                            selectedProduct,
                            failure: failure
                        )
                    )
                    return
                }

                guard let outcome else { return }

                switch outcome {
                case .success:
                    didCompleteCommerce = true
                    track(ProPaywallAnalytics.purchaseSucceeded(selectedProduct))
                    onPurchased?(selectedProduct)
                    dismiss()
                case .pending:
                    track(ProPaywallAnalytics.purchasePending(selectedProduct))
                case .userCancelled:
                    track(ProPaywallAnalytics.purchaseCancelled(selectedProduct))
                }
            }
        } label: {
            HStack {
                if purchases.isPurchasing {
                    ProgressView().tint(.black)
                }
                Text(purchaseButtonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(Color.white, in: Capsule())
        .foregroundStyle(.black)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .opacity(purchases.isRestoring ? 0.55 : 1)
        .disabled(
            selectedProduct == nil
                || purchases.isBusy
                || purchases.isPurchasePending
        )
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
            Text(PurchasePlanDisclosure.text(for: paywallProducts))
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: configuration.termsURL)
                Link("Privacy Policy", destination: configuration.privacyURL)
                if configuration.showsRedeemCode {
                    Button("Redeem Code") {
                        track(ProPaywallAnalytics.offerCodeOpened)
                        isOfferCodeRedemptionPresented = true
                    }
                    .buttonStyle(.plain)
                    .disabled(purchases.isBusy || purchases.isPurchasePending)
                }
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
                guard !purchases.isPurchasePending else { return }
                track(ProPaywallAnalytics.restoreStarted)
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
                || purchases.isPurchasePending
                || restoreModel.phase == .result(.restored)
        )
        .opacity(
            (purchases.isBusy && restoreModel.phase != .restoring)
                || purchases.isPurchasePending
                ? 0.5
                : 1
        )
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

    private var paywallProducts: [StoreProduct] {
        purchases.entitlementProducts
    }

    private var selectedProduct: StoreProduct? {
        guard let selectedProductID else { return nil }
        return paywallProducts.first(where: { $0.id == selectedProductID })
    }

    private var purchaseButtonTitle: String {
        if purchases.isPurchasing {
            return "Purchasing…"
        }
        if purchases.isPurchasePending {
            return "Pending Approval"
        }
        guard let selectedProduct else {
            return configuration.purchaseButtonTitle
        }
        return selectedProduct.purchaseActionTitle(
            defaultTitle: configuration.purchaseButtonTitle
        )
    }

    private func select(_ product: StoreProduct) {
        guard !purchases.isBusy, !purchases.isPurchasePending else { return }
        if selectedProductID != product.id {
            track(ProPaywallAnalytics.planSelected(product))
        }
        withAnimation(.snappy) { selectedProductID = product.id }
    }

    private func selectDefaultPlanIfNeeded() {
        if let selectedProductID,
           paywallProducts.contains(where: { $0.id == selectedProductID }) {
            return
        }

        if let highlightedProductID = configuration.highlightedProductID,
           paywallProducts.contains(where: { $0.id == highlightedProductID }) {
            selectedProductID = highlightedProductID
            return
        }

        selectedProductID = purchases.preferredEntitlementProduct?.id
            ?? paywallProducts.first?.id
    }

    private func badge(for product: StoreProduct) -> String? {
        let configuredBadge = configuration.highlightedProductID == product.id
            ? configuration.highlightedProductBadge
            : nil

        if let configuredBadge, isSavingsPercentageBadge(configuredBadge) {
            return configuredBadge
        }

        if isYearlyPlan(product),
           let monthlyProduct = paywallProducts.first(where: isMonthlyPlan),
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

    private func trackRestoreTransition(
        from oldPhase: RestorePurchasesRowModel.Phase,
        to newPhase: RestorePurchasesRowModel.Phase
    ) {
        guard oldPhase != newPhase else { return }

        switch newPhase {
        case .idle, .restoring:
            break
        case .result(.restored):
            didCompleteCommerce = true
            track(ProPaywallAnalytics.restoreSucceeded)
            onRestored?()
            dismiss()
        case .result(.nothingToRestore):
            track(ProPaywallAnalytics.restoreNothingToRestore)
        case .result(.failure(let failure)):
            track(ProPaywallAnalytics.restoreFailed(failure))
        }
    }

    private func track(_ event: ProPaywallAnalyticsEvent) {
        guard let analytics else { return }

        Task {
            try? await analytics.track(
                event.name,
                dimension: event.dimension
            )
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var offerCodeErrorBinding: Binding<Bool> {
        Binding(
            get: { offerCodeErrorMessage != nil },
            set: { if !$0 { offerCodeErrorMessage = nil } }
        )
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
