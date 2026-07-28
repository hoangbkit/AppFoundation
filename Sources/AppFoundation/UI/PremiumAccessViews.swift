#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

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
            case .allowed: action()
            case .requiresPro(let feature): onRequestUpgrade(feature)
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
    @Environment(PurchaseManager.self) private var environmentPurchaseManager

    private let purchaseManagerOverride: PurchaseManager?
    private let onUpgrade: () -> Void

    @State private var restoreMessage: String?

    public init(onUpgrade: @escaping () -> Void) {
        self.purchaseManagerOverride = nil
        self.onUpgrade = onUpgrade
    }

    public init(purchaseManager: PurchaseManager, onUpgrade: @escaping () -> Void) {
        self.purchaseManagerOverride = purchaseManager
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

    private var purchaseManager: PurchaseManager {
        purchaseManagerOverride ?? environmentPurchaseManager
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
