#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

/// App-owned copy for the reusable Pro-plan section used inside a SwiftUI `List` or `Form`.
public struct ProPlanSettingsConfiguration {
    public var sectionTitle: String
    public var currentPlanLabel: String
    public var freePlanTitle: String
    public var activePlanTitle: String
    public var unlockTitle: String
    public var comparePlansTitle: String
    public var manageSubscriptionTitle: String
    public var restorePurchasesTitle: String
    public var redeemCodeTitle: String
    public var manageSubscriptionsURL: URL?
    public var redeemCodeURL: URL?

    public init(
        sectionTitle: String = "Pro",
        currentPlanLabel: String = "Current plan",
        freePlanTitle: String = "Free",
        activePlanTitle: String = "Pro",
        unlockTitle: String = "Unlock Pro",
        comparePlansTitle: String = "Compare plans",
        manageSubscriptionTitle: String = "Manage subscription",
        restorePurchasesTitle: String = "Restore purchases",
        redeemCodeTitle: String = "Redeem code",
        manageSubscriptionsURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions"),
        redeemCodeURL: URL? = URL(string: "https://apps.apple.com/redeem")
    ) {
        self.sectionTitle = sectionTitle
        self.currentPlanLabel = currentPlanLabel
        self.freePlanTitle = freePlanTitle
        self.activePlanTitle = activePlanTitle
        self.unlockTitle = unlockTitle
        self.comparePlansTitle = comparePlansTitle
        self.manageSubscriptionTitle = manageSubscriptionTitle
        self.restorePurchasesTitle = restorePurchasesTitle
        self.redeemCodeTitle = redeemCodeTitle
        self.manageSubscriptionsURL = manageSubscriptionsURL
        self.redeemCodeURL = redeemCodeURL
    }
}

/// A compact subscription control surface for Settings: a flat two-line plan identity
/// followed by horizontally scrollable actions. Purchase behavior stays shared through
/// `PurchaseManager`, while this view owns its presentation and restore feedback.
public struct ProPlanSettingsSection: View {
    @Environment(\.appFoundationTheme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var restoreModel = RestorePurchasesRowModel()
    @State private var isShowingPlanComparison = false
    @State private var opensPaywallAfterComparison = false

    private let purchaseManager: PurchaseManager
    private let configuration: ProPlanSettingsConfiguration
    private let onUpgrade: (() -> Void)?

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPlanSettingsConfiguration = .init(),
        onUpgrade: (() -> Void)? = nil
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onUpgrade = onUpgrade
    }

    private var currentPlanTitle: String {
        guard purchaseManager.hasPro else {
            return configuration.freePlanTitle
        }
        guard let activeProduct = purchaseManager.activeProduct else {
            return "Pro"
        }
        return "Pro \(activeProduct.planLabel)"
    }

    private var planSubtitle: String {
        guard purchaseManager.hasPro else {
            return "Upgrade to Pro"
        }
        guard let activeProduct = purchaseManager.activeProduct else {
            return "Pro is active"
        }
        return activeProduct.isLifetime ? "Lifetime access" : activeProduct.billingDescription
    }

    public var body: some View {
        Section(configuration.sectionTitle) {
            VStack(alignment: .leading, spacing: 14) {
                planIdentity
                actionStrip
                restoreFeedback
            }
            .padding(.vertical, 4)
            .onAppear { restoreModel.reconcile(using: purchaseManager) }
            .onChange(of: purchaseManager.activity) { _, _ in
                restoreModel.reconcile(using: purchaseManager)
            }
            .sheet(
                isPresented: $isShowingPlanComparison,
                onDismiss: handlePlanComparisonDismiss
            ) {
                ProPlansComparisonView {
                    opensPaywallAfterComparison = true
                    isShowingPlanComparison = false
                }
                .environment(purchaseManager)
            }
        }
    }

    private var planIdentity: some View {
        HStack(spacing: 12) {
            Image(systemName: purchaseManager.hasPro ? "crown.fill" : "crown")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [
                            theme.accentColor.opacity(purchaseManager.hasPro ? 0.24 : 0.14),
                            theme.accentColor.opacity(purchaseManager.hasPro ? 0.08 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(theme.accentColor.opacity(purchaseManager.hasPro ? 0.28 : 0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(currentPlanTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryForegroundColor)

                Text(planSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                restorePill

                if !purchaseManager.hasPro, let onUpgrade {
                    actionPill(
                        configuration.unlockTitle,
                        systemImage: "crown.fill",
                        action: onUpgrade
                    )
                }

                if purchaseManager.hasPro,
                   purchaseManager.activeProduct?.isRecurring == true,
                   let manageSubscriptionsURL = configuration.manageSubscriptionsURL {
                    actionPill(
                        configuration.manageSubscriptionTitle,
                        systemImage: "arrow.up.right.square"
                    ) {
                        openURL(manageSubscriptionsURL)
                    }
                }

                if onUpgrade != nil {
                    actionPill(
                        configuration.comparePlansTitle,
                        systemImage: "rectangle.3.group"
                    ) {
                        isShowingPlanComparison = true
                    }
                }

                if let redeemCodeURL = configuration.redeemCodeURL {
                    actionPill(
                        configuration.redeemCodeTitle,
                        systemImage: "ticket"
                    ) {
                        openURL(redeemCodeURL)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func actionPill(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(theme.elevatedSurfaceColor, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(theme.borderColor)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primaryForegroundColor)
    }

    private var restorePill: some View {
        Button {
            switch restoreModel.phase {
            case .idle, .result(.nothingToRestore), .result(.failure):
                restoreModel.start(
                    using: purchaseManager,
                    configuration: restoreConfiguration
                )
            case .restoring, .result(.restored):
                break
            }
        } label: {
            HStack(spacing: 6) {
                if restoreModel.phase == .restoring {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: restoreIcon)
                }
                Text(restoreLabel)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(theme.elevatedSurfaceColor, in: Capsule())
            .overlay {
                Capsule().strokeBorder(theme.borderColor)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primaryForegroundColor)
        .disabled(purchaseManager.isBusy && restoreModel.phase != .restoring)
        .opacity(purchaseManager.isBusy && restoreModel.phase != .restoring ? 0.5 : 1)
    }

    @ViewBuilder
    private var restoreFeedback: some View {
        switch restoreModel.phase {
        case .idle, .restoring:
            EmptyView()
        case .result(.restored):
            Text("Purchases restored successfully.")
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
                .accessibilityLabel("Purchases restored successfully")
        case .result(.nothingToRestore):
            Text("No previous purchases were found for this Apple Account.")
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
        case .result(.failure(let failure)):
            Text(failure.message)
                .font(.caption)
                .foregroundStyle(theme.secondaryForegroundColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var restoreConfiguration: RestorePurchasesRowConfiguration {
        RestorePurchasesRowConfiguration(title: configuration.restorePurchasesTitle)
    }

    private var restoreLabel: String {
        switch restoreModel.phase {
        case .idle:
            configuration.restorePurchasesTitle
        case .restoring:
            "Restoring…"
        case .result(.restored):
            "Restored"
        case .result(.nothingToRestore):
            "Restore again"
        case .result(.failure):
            "Retry restore"
        }
    }

    private var restoreIcon: String {
        switch restoreModel.phase {
        case .result(.restored):
            "checkmark"
        case .result(.failure):
            "exclamationmark.triangle"
        default:
            "arrow.clockwise"
        }
    }

    private func handlePlanComparisonDismiss() {
        guard opensPaywallAfterComparison else { return }
        opensPaywallAfterComparison = false
        onUpgrade?()
    }
}
#endif
