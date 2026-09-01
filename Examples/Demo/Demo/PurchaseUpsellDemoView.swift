import AppFoundation
import SwiftUI

struct PurchaseUpsellDemoView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.appFoundationTheme) private var theme

    @State private var isShowingPaywall = false
    @State private var isShowingLimitUpsell = false

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            List {
                ProPlanSettingsSection(
                    purchaseManager: purchases,
                    configuration: ProPlanSettingsConfiguration(
                        sectionTitle: "Demo Pro",
                        activePlanTitle: "Demo Pro",
                        unlockTitle: "Unlock Demo Pro"
                    ),
                    onUpgrade: { isShowingPaywall = true }
                )
                .listRowBackground(theme.surfaceColor)

                Section("Limit reached upsell") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Catalog-driven purchase flow", systemImage: "exclamationmark.circle.fill")
                            .font(.headline)
                        Text("The paywall and Free-vs-Pro table both read the same registered features from PurchaseManager.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }

                    Button {
                        isShowingLimitUpsell = true
                    } label: {
                        HStack {
                            Label("Show limit reached", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(theme.secondaryForegroundColor.opacity(0.72))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(theme.primaryForegroundColor)
        }
        .navigationTitle("Pro & Upsells")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(theme.accentColor)
        .sheet(isPresented: $isShowingPaywall) {
            ProPaywallView(
                purchases: purchases,
                configuration: DemoConfiguration.proPaywall
            )
        }
        .sheet(isPresented: $isShowingLimitUpsell) {
            LimitReachedUpsellFlow(
                configuration: DemoConfiguration.limitReachedUpsell
            ) {
                ProPaywallView(
                    purchases: purchases,
                    configuration: DemoConfiguration.proPaywall
                )
            }
        }
        .animation(.smooth, value: theme.id)
    }
}
