#if os(macOS) && canImport(SwiftUI) && canImport(StoreKit)
import AppKit
import StoreKit
import SwiftUI

/// A native two-column macOS paywall backed by AppFoundation's `PurchaseManager`.
///
/// The view is intentionally compiled only for macOS. It prepares the supplied
/// purchase manager, presents every configured StoreKit product, and keeps
/// purchase, restore, entitlement, loading, and error state inside AppFoundation.
@MainActor
public struct MacPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    private let purchases: PurchaseManager
    private let configuration: FoundationPaywallConfiguration
    private let onClose: (() -> Void)?

    @State private var selectedProductID: String?
    @State private var restoreMessage: String?

    public init(
        purchases: PurchaseManager,
        configuration: FoundationPaywallConfiguration,
        onClose: (() -> Void)? = nil
    ) {
        self.purchases = purchases
        self.configuration = configuration
        self.onClose = onClose
        _selectedProductID = State(initialValue: nil)
    }

    public var body: some View {
        GeometryReader { proxy in
            let outerPadding = max(20, min(proxy.size.width * 0.03, 32))
            let topPadding = max(28, min(proxy.size.height * 0.08, 44))
            let columnSpacing = max(18, min(proxy.size.width * 0.03, 30))

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    leadingPane
                    trailingPane
                }
                .padding(.horizontal, outerPadding)
                .padding(.top, topPadding)
                .padding(.bottom, outerPadding)

                Divider()

                bottomBar
                    .padding(.horizontal, max(16, outerPadding - 6))
                    .padding(.vertical, 16)
            }
        }
        .frame(
            minWidth: 760,
            idealWidth: 860,
            maxWidth: 980,
            minHeight: 480,
            idealHeight: 560
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await purchases.prepare()
            selectDefaultProductIfNeeded()
        }
        .onChange(of: purchases.products) { _, _ in
            selectDefaultProductIfNeeded()
        }
        .onChange(of: purchases.hasPro) { _, hasPro in
            if hasPro {
                close()
            }
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

    private var leadingPane: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.title)
                        .font(.system(size: 34, weight: .bold))
                    Text(configuration.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(configuration.features) { feature in
                        HStack(alignment: .top, spacing: 14) {
                            iconTile(feature.systemImage)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.headline)
                                Text(feature.message)
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 280,
            idealWidth: 420,
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var trailingPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            productOptions

            Spacer(minLength: 10)

            purchaseButton

            legalFooter
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(
            minWidth: 300,
            idealWidth: 340,
            maxWidth: 380,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private var productOptions: some View {
        switch purchases.productLoadingState {
        case .idle, .loading:
            loadingState
        case .failed(let failure):
            productLoadingFailure(failure)
        case .loaded:
            VStack(spacing: 12) {
                ForEach(purchases.products) { product in
                    productCard(product)
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let selectedProduct, !purchases.isBusy else { return }
            Task {
                await purchases.purchase(selectedProduct)
            }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Text(isPurchasing ? "Purchasing..." : configuration.purchaseButtonTitle)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedProduct == nil || purchases.isBusy)
        .opacity(selectedProduct == nil || purchases.isBusy ? 0.6 : 1)
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                restore()
            } label: {
                if isRestoring {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Restoring...")
                    }
                } else {
                    Text("Restore Purchases")
                }
            }
            .buttonStyle(.bordered)
            .disabled(purchases.isBusy)

            Spacer()

            Button {
                close()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .disabled(purchases.isBusy)
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading available plans...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    private func productLoadingFailure(_ failure: PurchaseFailure) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Unable to load plans")
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
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    private func productCard(_ product: PurchaseProduct) -> some View {
        let isSelected = selectedProductID == product.id
        let isHighlighted = configuration.highlightedProductID == product.id

        return Button {
            guard !purchases.isBusy else { return }
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isHighlighted {
                            Text(configuration.highlightedProductBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }

                    Text(product.description.isEmpty ? product.billingDescription : product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(product.displayPrice)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(product.planLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchases.isBusy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconTile(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor)
            )
    }

    @ViewBuilder
    private var legalFooter: some View {
        VStack(spacing: 8) {
            if configuration.termsURL != nil || configuration.privacyURL != nil {
                HStack(spacing: 8) {
                    if let termsURL = configuration.termsURL {
                        Link("Terms of Use", destination: termsURL)
                    }

                    if configuration.termsURL != nil, configuration.privacyURL != nil {
                        Text("•")
                    }

                    if let privacyURL = configuration.privacyURL {
                        Link("Privacy Policy", destination: privacyURL)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption.weight(.semibold))
            }

            Text(PurchasePlanDisclosure.text(for: purchases.products))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedProduct: PurchaseProduct? {
        guard let selectedProductID else { return nil }
        return purchases.product(withID: selectedProductID)
    }

    private var isPurchasing: Bool {
        if case .purchasing = purchases.activity {
            return true
        }
        return false
    }

    private var isRestoring: Bool {
        purchases.activity == .restoring
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
        guard !purchases.products.isEmpty else { return }
        guard selectedProduct == nil else { return }

        if let highlightedProductID = configuration.highlightedProductID,
           purchases.product(withID: highlightedProductID) != nil {
            selectedProductID = highlightedProductID
        } else {
            selectedProductID = purchases.preferredProduct?.id ?? purchases.products.first?.id
        }
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

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
#endif
