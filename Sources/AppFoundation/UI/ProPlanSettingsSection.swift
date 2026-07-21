#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

/// App-owned copy for the reusable Pro-plan section used inside a SwiftUI `List` or `Form`.
public struct ProPlanSettingsConfiguration {
    public var sectionTitle: String
    public var currentPlanLabel: String
    public var freePlanTitle: String
    public var activePlanTitle: String
    public var unlockTitle: String
    public var manageSubscriptionTitle: String
    public var restorePurchasesTitle: String
    public var manageSubscriptionsURL: URL?

    public init(
        sectionTitle: String = "Pro",
        currentPlanLabel: String = "Current plan",
        freePlanTitle: String = "Free",
        activePlanTitle: String = "Pro",
        unlockTitle: String = "Unlock Pro",
        manageSubscriptionTitle: String = "Manage subscription",
        restorePurchasesTitle: String = "Restore purchases",
        manageSubscriptionsURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions")
    ) {
        self.sectionTitle = sectionTitle
        self.currentPlanLabel = currentPlanLabel
        self.freePlanTitle = freePlanTitle
        self.activePlanTitle = activePlanTitle
        self.unlockTitle = unlockTitle
        self.manageSubscriptionTitle = manageSubscriptionTitle
        self.restorePurchasesTitle = restorePurchasesTitle
        self.manageSubscriptionsURL = manageSubscriptionsURL
    }
}

/// A compact current-plan, upgrade, manage, and restore section adapted from MiLove.
///
/// The app still owns the paywall presentation. Pass `onUpgrade` to show the upgrade row.
public struct ProPlanSettingsSection: View {
    @Environment(\.appFoundationTheme) private var theme
    @Environment(\.openURL) private var openURL

    private let purchaseManager: PurchaseManager
    private let configuration: ProPlanSettingsConfiguration
    private let onUpgrade: (() -> Void)?

    @State private var restoreMessage: String?

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPlanSettingsConfiguration = .init(),
        onUpgrade: (() -> Void)? = nil
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Section(configuration.sectionTitle) {
            LabeledContent(configuration.currentPlanLabel) {
                Text(purchaseManager.hasPro ? configuration.activePlanTitle : configuration.freePlanTitle)
                    .foregroundStyle(purchaseManager.hasPro ? theme.accentColor : theme.secondaryForegroundColor)
            }

            if !purchaseManager.hasPro, let onUpgrade {
                Button(action: onUpgrade) {
                    HStack {
                        Label(configuration.unlockTitle, systemImage: "crown.fill")
                            .foregroundStyle(theme.primaryForegroundColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(theme.secondaryForegroundColor.opacity(0.72))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if purchaseManager.hasPro,
                      purchaseManager.products.contains(where: \.isRecurring),
                      let manageSubscriptionsURL = configuration.manageSubscriptionsURL {
                Button {
                    openURL(manageSubscriptionsURL)
                } label: {
                    HStack {
                        Label(
                            configuration.manageSubscriptionTitle,
                            systemImage: "person.crop.circle.badge.checkmark"
                        )
                        .foregroundStyle(theme.primaryForegroundColor)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(theme.secondaryForegroundColor.opacity(0.72))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                restorePurchases()
            } label: {
                HStack {
                    Label(configuration.restorePurchasesTitle, systemImage: "arrow.clockwise")
                    Spacer()
                    if case .restoring = purchaseManager.activity {
                        ProgressView()
                    }
                }
            }
            .disabled(purchaseManager.isBusy)
        }
        .alert("Restore Purchases", isPresented: restoreAlertBinding) {
            Button("OK", role: .cancel) {
                restoreMessage = nil
            }
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private func restorePurchases() {
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
}
#endif
