import AppFoundation
import SwiftUI

struct HomeView: View {
    @Environment(PurchaseController.self) private var purchases

    @State private var selectedPaywallStyle: PaywallStyle?
    @State private var isShowingPaywallStylePicker = false
    @State private var isShowingOnboarding = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                FoundationBackground(theme: DemoConfiguration.theme)

                List {
                    homeListRow(top: 8, bottom: 11) {
                        heroCard
                    }

                    homeListRow(top: 11, bottom: 11) {
                        entitlementCard
                    }

                    homeListRow(top: 11, bottom: 32) {
                        componentsCard
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("AppFoundation")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(item: $selectedPaywallStyle) { style in
                switch style {
                case .standard:
                    FoundationPaywallView(
                        purchases: purchases,
                        configuration: DemoConfiguration.paywall
                    )
                case .claude:
                    ClaudePaywallView(
                        purchases: purchases,
                        configuration: DemoConfiguration.claudePaywall
                    )
                }
            }
            .navigationDestination(isPresented: $isShowingPaywallStylePicker) {
                PaywallStylePickerView { style in
                    selectedPaywallStyle = style
                }
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages,
                    theme: DemoConfiguration.theme
                ) {
                    isShowingOnboarding = false
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                FoundationSettingsView(
                    purchases: purchases,
                    configuration: DemoConfiguration.settings
                )
            }
        }
        .tint(DemoConfiguration.theme.primary)
    }

    private func homeListRow<Content: View>(
        top: CGFloat,
        bottom: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var heroCard: some View {
        FoundationCard(theme: DemoConfiguration.theme) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    FoundationPill(
                        "APPFOUNDATION",
                        systemImage: "square.stack.3d.up.fill",
                        tint: DemoConfiguration.theme.primary
                    )

                    Spacer()

                    Image(systemName: "swift")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 42, height: 42)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Build the app.\nSkip the boilerplate.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .lineSpacing(1)

                    Text("Production-ready StoreKit 2 infrastructure and polished SwiftUI screens in one focused package.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                HStack(spacing: 8) {
                    technologyBadge("StoreKit 2", systemImage: "cart.fill")
                    technologyBadge("Swift 6", systemImage: "swift")
                    technologyBadge("iOS 26", systemImage: "iphone")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var entitlementCard: some View {
        FoundationCard(theme: DemoConfiguration.theme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("PREMIUM STATUS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                #if DEBUG
                if purchases.isUsingSimulatedPurchases {
                    FoundationPill(
                        "SIMULATED BILLING",
                        systemImage: "hammer.fill",
                        tint: .orange
                    )
                }
                #endif

                HStack(spacing: 12) {
                    Image(systemName: entitlementIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(entitlementColor)
                        .frame(width: 46, height: 46)
                        .background(entitlementColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entitlementTitle)
                            .font(.headline)
                        Text(entitlementMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if !purchases.isEntitled {
                    Button {
                        isShowingPaywallStylePicker = true
                    } label: {
                        HStack {
                            Text("Compare paywall styles")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(FoundationPrimaryButtonStyle(theme: DemoConfiguration.theme))
                }

                #if DEBUG
                if purchases.isUsingSimulatedPurchases {
                    Button("Reset simulated purchases", role: .destructive) {
                        Task {
                            await purchases.resetSimulatedPurchases()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                #endif
            }
        }
    }

    private var componentsCard: some View {
        FoundationCard(theme: DemoConfiguration.theme) {
            VStack(alignment: .leading, spacing: 0) {
                Text("EXPLORE COMPONENTS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                componentRow(
                    title: "Onboarding",
                    subtitle: "Preview the complete onboarding flow",
                    systemImage: "rectangle.stack.fill",
                    action: { isShowingOnboarding = true }
                )
                componentDivider
                componentRow(
                    title: "Paywall",
                    subtitle: "Compare two StoreKit-powered styles",
                    systemImage: "creditcard.fill",
                    action: { isShowingPaywallStylePicker = true }
                )
                componentDivider
                componentRow(
                    title: "Settings",
                    subtitle: "Purchases, support, and legal links",
                    systemImage: "slider.horizontal.3",
                    action: { isShowingSettings = true }
                )
                componentDivider
                componentRow(
                    title: "Core",
                    subtitle: "Verified entitlements and pure logic",
                    systemImage: "checkmark.seal.fill"
                )
            }
        }
    }

    @ViewBuilder
    private func componentRow(
        title: String,
        subtitle: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(DemoConfiguration.theme.primary)
                .frame(width: 42, height: 42)
                .background(
                    DemoConfiguration.theme.primary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 13)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var componentDivider: some View {
        Divider()
            .padding(.leading, 56)
    }

    private func technologyBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private var entitlementTitle: String {
        switch purchases.entitlementState {
        case .checking:
            "Checking premium access"
        case .inactive:
            "Free plan"
        case .active:
            "Demo Pro is active"
        }
    }

    private var entitlementMessage: String {
        switch purchases.entitlementState {
        case .checking:
            "Verifying current App Store entitlements."
        case .inactive:
            #if DEBUG
            purchases.isUsingSimulatedPurchases
                ? "Open the paywall to test purchases without App Store Connect."
                : "Open the sample paywall to test StoreKit purchases."
            #else
            "Open the sample paywall to test StoreKit purchases."
            #endif
        case .active:
            #if DEBUG
            purchases.isUsingSimulatedPurchases
                ? "This entitlement comes from the Debug purchase simulator."
                : "This status comes from verified StoreKit transactions."
            #else
            "This status comes from verified StoreKit transactions."
            #endif
        }
    }

    private var entitlementIcon: String {
        switch purchases.entitlementState {
        case .checking:
            "clock.arrow.circlepath"
        case .inactive:
            "lock.fill"
        case .active:
            "crown.fill"
        }
    }

    private var entitlementColor: Color {
        switch purchases.entitlementState {
        case .checking:
            .secondary
        case .inactive:
            DemoConfiguration.theme.primary
        case .active:
            .orange
        }
    }
}

private struct PaywallStylePickerView: View {
    let onSelect: (PaywallStyle) -> Void

    var body: some View {
        List {
            Section {
                Button {
                    onSelect(.standard)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gradient Paywall")
                                .font(.headline)
                            Text("A bold gradient design with feature cards and plan rows.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles.rectangle.stack")
                            .foregroundStyle(DemoConfiguration.theme.primary)
                    }
                }

                Button {
                    onSelect(.claude)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ClaudePaywall")
                                .font(.headline)
                            Text("A compact plan-focused layout with side-by-side options.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.split.2x1")
                            .foregroundStyle(DemoConfiguration.theme.primary)
                    }
                }
            } header: {
                Text("Choose a paywall style")
            }
        }
        .navigationTitle("Paywall Styles")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum PaywallStyle: String, Identifiable {
    case standard
    case claude

    var id: String { rawValue }
}
