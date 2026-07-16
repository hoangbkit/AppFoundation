#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

/// A compact, plan-focused paywall style with side-by-side subscription cards.
///
/// This style is intentionally independent from `FoundationPaywallView` so an app
/// can choose the visual treatment that best fits its product without changing
/// its StoreKit or configuration code.
public struct ClaudePaywallView: View {
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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())
        }
        .padding(.leading, 4)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(configuration.title)
                .font(.system(size: 32, weight: .regular, design: .serif))
            Text(configuration.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 36)
        .multilineTextAlignment(.center)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pro")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                Text("For everyday productivity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            featureList
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        if case .failed(let failure) = purchases.productLoadingState {
            VStack(spacing: 12) {
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

        return Button {
            withAnimation(.snappy) { selectedProductID = product.id }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? configuration.theme.primary : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        if isSelected {
                            Circle()
                                .fill(configuration.theme.primary)
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
                            .background(configuration.theme.primary.opacity(0.15), in: Capsule())
                            .foregroundStyle(configuration.theme.primary)
                    }
                }

                Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(product.id == yearly?.id ? "Billed annually" : "Billed monthly")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? configuration.theme.primary.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? configuration.theme.primary : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
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
                Text("Get Pro plan").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(Color.black, in: Capsule())
        .foregroundStyle(.white)
        .disabled(selectedProduct == nil || purchases.isBusy)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything in Free, plus:")
                .font(.subheadline.weight(.semibold))
            ForEach(configuration.features) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(feature.message)
                        .font(.subheadline)
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        }
        .padding(.horizontal, 8)
    }

    private var selectedProduct: StoreProduct? {
        selectedProductID.flatMap(purchases.product(withID:)) ?? purchases.preferredProduct
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
        guard selectedProductID == nil || purchases.product(withID: selectedProductID ?? "") == nil else { return }
        selectedProductID = purchases.preferredProduct?.id
    }

    private func savingsBadge(for product: StoreProduct) -> String? {
        guard product.id == yearly?.id,
              let monthly,
              monthly.price > 0 else { return nil }
        let savings = Int(((monthly.price * 12 - product.price) / (monthly.price * 12) * 100).rounded())
        return savings > 0 ? "Save \(savings)%" : nil
    }

    private var purchaseFailure: PurchaseFailure? {
        if case .failed(let failure) = purchases.activity { return failure }
        return nil
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(get: { purchaseFailure != nil }, set: { if !$0 { purchases.clearActivity() } })
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

    private var termsURL: URL {
        configuration.termsURL ?? URL(string: "https://example.com/terms")!
    }

    private var privacyURL: URL {
        configuration.privacyURL ?? URL(string: "https://example.com/privacy")!
    }
}
#endif
