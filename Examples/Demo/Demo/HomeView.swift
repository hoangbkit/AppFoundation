import AppFoundation
import SwiftUI

struct HomeView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes

    @State private var selectedPaywallStyle: PaywallStyle?
    @State private var isShowingPaywallStylePicker = false
    @State private var isShowingOnboarding = false
    @State private var isShowingThemeDemo = false
    @State private var isShowingInfrastructureDemo = false
    @State private var isShowingSettings = false

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                List {
                    row(top: 8, bottom: 11) { heroCard }
                    row(top: 11, bottom: 11) { entitlementCard }
                    row(top: 11, bottom: 32) { componentsCard }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .navigationTitle("AppFoundation")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        isShowingSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(item: $selectedPaywallStyle) { style in
                switch style {
                case .current:
                    PaywallView(
                        purchaseManager: purchases,
                        configuration: DemoConfiguration.modernPaywall
                    )
                case .legacyGradient:
                    FoundationPaywallView(
                        purchases: purchases,
                        configuration: DemoConfiguration.legacyPaywall
                    )
                case .legacyClaude:
                    ClaudePaywallView(
                        purchases: purchases,
                        configuration: DemoConfiguration.legacyClaudePaywall
                    )
                }
            }
            .navigationDestination(isPresented: $isShowingPaywallStylePicker) {
                PaywallStylePickerView { selectedPaywallStyle = $0 }
            }
            .navigationDestination(isPresented: $isShowingThemeDemo) {
                ThemeDemoView()
            }
            .navigationDestination(isPresented: $isShowingInfrastructureDemo) {
                InfrastructureDemoView()
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages
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
        .tint(theme.accentColor)
        .animation(.smooth, value: theme.id)
    }

    private func row<Content: View>(
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
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    FoundationPill(
                        "SHARED INFRASTRUCTURE",
                        systemImage: "square.stack.3d.up.fill",
                        tint: theme.accentColor
                    )
                    Spacer()
                    Image(systemName: "swift")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 42, height: 42)
                        .background(
                            theme.elevatedSurfaceColor,
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(theme.borderColor)
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Build the app.\nSkip the boilerplate.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryForegroundColor)
                    Text("Explore purchases, themes, export, backup, widget storage, notifications, and production utilities in one Demo app.")
                        .foregroundStyle(theme.secondaryForegroundColor)
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
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 16) {
                Text("PREMIUM STATUS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryForegroundColor)

                #if DEBUG
                if purchases.isUsingSimulatedPurchases {
                    FoundationPill(
                        "SIMULATED BILLING",
                        systemImage: "hammer.fill",
                        tint: theme.accentColor
                    )
                }
                #endif

                HStack(spacing: 12) {
                    Image(systemName: entitlementIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(entitlementColor)
                        .frame(width: 46, height: 46)
                        .background(
                            entitlementColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entitlementTitle)
                            .font(.headline)
                            .foregroundStyle(theme.primaryForegroundColor)
                        Text(entitlementMessage)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }
                    Spacer()
                }

                if !purchases.hasPro {
                    Button {
                        selectedPaywallStyle = .current
                    } label: {
                        HStack {
                            Text("Open current PaywallView")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(FoundationPrimaryButtonStyle(theme: theme))
                }

                #if DEBUG
                if purchases.isUsingSimulatedPurchases {
                    Button("Reset simulated purchases", role: .destructive) {
                        Task { await purchases.resetSimulatedPurchases() }
                    }
                    .buttonStyle(.bordered)
                }
                #endif
            }
        }
    }

    private var componentsCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                Text("EXPLORE THE PACKAGE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .padding(.bottom, 10)

                componentRow(
                    title: "New APIs",
                    subtitle: "Commerce gates, export, backup, shared snapshots, notifications, and utilities",
                    systemImage: "shippingbox.fill",
                    action: { isShowingInfrastructureDemo = true }
                )
                divider
                componentRow(
                    title: "Paywalls",
                    subtitle: "Compare the current PaywallView with legacy layouts",
                    systemImage: "creditcard.fill",
                    action: { isShowingPaywallStylePicker = true }
                )
                divider
                componentRow(
                    title: "Themes",
                    subtitle: "Persistent selection and timed Pro previews",
                    systemImage: "paintpalette.fill",
                    action: { isShowingThemeDemo = true }
                )
                divider
                componentRow(
                    title: "Onboarding",
                    subtitle: "Preview the reusable onboarding flow",
                    systemImage: "rectangle.stack.fill",
                    action: { isShowingOnboarding = true }
                )
                divider
                componentRow(
                    title: "Legacy Settings",
                    subtitle: "Existing all-in-one settings view for migration testing",
                    systemImage: "slider.horizontal.3",
                    action: { isShowingSettings = true }
                )
            }
        }
    }

    private func componentRow(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 42, height: 42)
                    .background(
                        theme.elevatedSurfaceColor,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryForegroundColor)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.secondaryForegroundColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider()
            .overlay(theme.borderColor)
            .padding(.leading, 56)
    }

    private func technologyBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.secondaryForegroundColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(theme.elevatedSurfaceColor, in: Capsule())
            .overlay { Capsule().strokeBorder(theme.borderColor) }
    }

    private var entitlementTitle: String {
        switch purchases.entitlementState {
        case .checking: "Checking premium access"
        case .inactive: "Free plan"
        case .active: "Demo Pro is active"
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
                : "Open the current paywall to test StoreKit purchases."
            #else
            "Open the current paywall to test StoreKit purchases."
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
        case .checking: "clock.arrow.circlepath"
        case .inactive: "lock.fill"
        case .active: "crown.fill"
        }
    }

    private var entitlementColor: Color {
        switch purchases.entitlementState {
        case .checking: theme.secondaryForegroundColor
        case .inactive, .active: theme.accentColor
        }
    }
}

private struct PaywallStylePickerView: View {
    @Environment(\.appFoundationTheme) private var theme

    let onSelect: (PaywallStyle) -> Void

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            List {
                Section("Recommended") {
                    styleButton(
                        title: "PaywallView",
                        subtitle: "Current theme-aware weekly, monthly, yearly, and lifetime paywall.",
                        systemImage: "rectangle.split.2x1",
                        style: .current
                    )
                }
                .listRowBackground(theme.surfaceColor)

                Section("Migration previews") {
                    styleButton(
                        title: "FoundationPaywallView",
                        subtitle: "Legacy gradient layout retained for existing apps.",
                        systemImage: "sparkles.rectangle.stack",
                        style: .legacyGradient
                    )
                    styleButton(
                        title: "ClaudePaywallView",
                        subtitle: "Legacy compact layout retained for comparison.",
                        systemImage: "rectangle.grid.2x2",
                        style: .legacyClaude
                    )
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(theme.primaryForegroundColor)
        }
        .navigationTitle("Paywall Styles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(theme.accentColor)
    }

    private func styleButton(
        title: String,
        subtitle: String,
        systemImage: String,
        style: PaywallStyle
    ) -> some View {
        Button { onSelect(style) } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryForegroundColor)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryForegroundColor)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(theme.accentColor)
            }
        }
    }
}

private enum PaywallStyle: String, Identifiable {
    case current
    case legacyGradient
    case legacyClaude

    var id: String { rawValue }
}