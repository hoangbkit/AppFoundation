import AppFoundation
import SwiftUI

struct PurchaseUpsellDemoView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.appFoundationTheme) private var theme

    @State private var isShowingPaywall = false
    @State private var isShowingLimitUpsell = false

    var body: some View {
        NavigationStack {
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
                            Label("MiLove-style limit flow", systemImage: "exclamationmark.circle.fill")
                                .font(.headline)
                            Text("Preview the reusable stay-free comparison before transitioning into the app-owned paywall.")
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
                PaywallView(
                    purchaseManager: purchases,
                    configuration: DemoConfiguration.modernPaywall
                )
            }
            .sheet(isPresented: $isShowingLimitUpsell) {
                LimitReachedUpsellFlow(
                    configuration: DemoConfiguration.limitReachedUpsell
                ) {
                    PaywallView(
                        purchaseManager: purchases,
                        configuration: DemoConfiguration.modernPaywall
                    )
                }
            }
        }
        .animation(.smooth, value: theme.id)
    }
}
