#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style with side-by-side subscription cards.
///
/// The view follows the active theme installed with `.appFoundationTheme(_:)`.
/// `FoundationPaywallConfiguration.themeOverride` can provide an isolated
/// `AppTheme`, while the legacy `theme:` initializer remains a fixed override.
public struct ClaudePaywallView: View {
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
        ZStack {
            PaywallThemeBackground(tokens: theme)

            ScrollView {
                VStack(spacing: 28) {
                    header
                    planCard
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(theme.primaryForeground)
        .tint(theme.accent)
        .preferredColorScheme(theme.preferredColorScheme)
        .overlay(alignment: .topLeading) { closeButton }
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

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryForeground)
                .frame(width: 36, height: 36)
                .background(theme.elevatedSurface.opacity(0.94), in: Circle())
                .overlay {
                    Circle().strokeBorder(theme.border)
                }
        }
        .padding(.leading, 4)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(configuration.title)
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(theme.primaryForeground)
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(theme.secondaryForeground)
        }
        .padding(.top, 36)
        .multilineTextAlignment(.center)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pro")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.primaryForeground)
                Text("For everyday productivity")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForeground)
            }

            if monthly == nil && yearly == nil {
                loadingContent
            } else {
                HStack(spacing: 12) {
                    if let monthly {
                        planOption(for: monthly, badge: nil)
                    }
                    if let yearly {
                        planOption(for: yearly, badge: savingsBadge(for: yearly))
                    }
                }

                purchaseButton
            }

            Divider()
                .overlay(theme.border)

            featureList
        }
        .padding(20)
        .background(
            theme.surface,
            in: RoundedRectangle(
                cornerRadius: theme.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: theme.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(theme.border)
        }
        .shadow(color: theme.shadow, radius: 18, y: 10)
    }

    @ViewBuilder
    private var loadingContent: some View {
        if case .failed(let failure) = purchases.productLoadingState {
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
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    private func planOption(for product: StoreProduct, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        let optionRadius = min(theme.cardCornerRadius, 16)

        return Button {
            withAnimation(.snappy) {
                selectedProductID = product.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected ? theme.accent : theme.secondaryForeground.opacity(0.45),
                                lineWidth: 1.5
                            )
                        if isSelected {
                            Circle()
                                .fill(theme.accent)
                                .padding(4)
                        }
                    }
                    .frame(width: 22, height: 22)

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(theme.accent)
                    }
                }

                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primaryForeground)
                Text(product.id == yearly?.id ? "Billed annually" : "Billed monthly")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryForeground)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct else { return }
            Task {
                await purchases.purchase(selectedProduct)
                if purchases.isEntitled { dismiss() }
            }
        } label: {
            HStack {
                if purchases.isBusy { ProgressView().tint(.white) }
                Text(configuration.purchaseButtonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [theme.accent, theme.secondaryAccent],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .foregroundStyle(.white)
        .shadow(color: theme.accent.opacity(0.24), radius: 12, y: 6)
        .disabled(selectedProduct == nil || purchases.isBusy)
        .opacity(selectedProduct == nil ? 0.55 : 1)
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
            Text("Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(theme.secondaryForeground)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: termsURL)
                Link("Privacy Policy", destination: privacyURL)
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
                .disabled(purchases.isBusy)
            }
            .font(.caption)
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, 8)
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

    private var monthly: StoreProduct? {
        purchases.products.first {
            $0.subscriptionPeriod?.unit == .month
                || $0.id.localizedCaseInsensitiveContains("monthly")
        }
    }

    private var yearly: StoreProduct? {
        purchases.products.first {
            $0.subscriptionPeriod?.unit == .year
                || $0.id.localizedCaseInsensitiveContains("yearly")
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

    private func savingsBadge(for product: StoreProduct) -> String? {
        guard product.id == yearly?.id,
              let monthly,
              monthly.price > 0
        else {
            return nil
        }

        let yearlyCostAtMonthlyRate = monthly.price * 12
        let savings = Int(
            ((yearlyCostAtMonthlyRate - product.price) / yearlyCostAtMonthlyRate * 100)
                .rounded()
        )
        return savings > 0 ? "Save \(savings)%" : nil
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
