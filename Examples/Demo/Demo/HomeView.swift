import AppFoundation
import SwiftUI

struct HomeView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes

    @State private var selectedPaywallStyle: PaywallStyle?
    @State private var isShowingSettings = false
    @State private var isShowingOnboarding = false

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                List {
                    row(top: 8, bottom: 9) { heroCard }
                    row(top: 9, bottom: 9) { entitlementCard }
                    row(top: 9, bottom: 30) { featuresCard }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .navigationTitle("AppFoundation")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedPaywallStyle = .current
                    } label: {
                        Image(systemName: "crown.fill")
                    }
                    .accessibilityLabel("Open default paywall")
                }
            }
            .navigationDestination(for: DemoFeature.self) { feature in
                destination(for: feature)
            }
            .sheet(item: $selectedPaywallStyle) { style in
                paywall(for: style)
            }
            .sheet(isPresented: $isShowingSettings) {
                DemoSettingsView()
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages
                ) {
                    isShowingOnboarding = false
                }
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    FoundationPill(
                        "SHARED INFRASTRUCTURE",
                        systemImage: "square.stack.3d.up.fill",
                        tint: theme.accentColor
                    )

                    Spacer(minLength: 12)

                    Image(systemName: "swift")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Build the app.\nSkip the boilerplate.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryForegroundColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Explore production-ready systems from one focused Demo app.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryForegroundColor)
                        .lineSpacing(3)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        heroButton(
                            "StoreKit 2",
                            systemImage: "cart.fill",
                            destination: .paywalls
                        )
                        heroButton(
                            "Swift 6",
                            systemImage: "swift",
                            destination: .infrastructure
                        )
                        heroButton(
                            "Widgets",
                            systemImage: "square.grid.2x2.fill",
                            destination: .widgets
                        )
                        heroButton(
                            "Studios",
                            systemImage: "wand.and.stars",
                            destination: .screenshotStudio
                        )
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func heroButton(
        _ title: String,
        systemImage: String,
        destination: DemoFeature
    ) -> some View {
        NavigationLink(value: destination) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.secondaryForegroundColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.elevatedSurfaceColor, in: Capsule())
                .overlay { Capsule().strokeBorder(theme.borderColor) }
        }
        .buttonStyle(.plain)
    }

    private var entitlementCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                Text("PREMIUM STATUS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryForegroundColor)

                HStack(spacing: 12) {
                    Image(systemName: entitlementIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(entitlementColor)
                        .frame(width: 44, height: 44)
                        .background(
                            entitlementColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entitlementTitle)
                            .font(.headline)
                        Text(entitlementMessage)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }

                    Spacer(minLength: 8)
                }

                #if DEBUG
                Divider().overlay(theme.borderColor)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        "Simulated purchases",
                        isOn: Binding(
                            get: { purchases.isUsingSimulatedPurchases },
                            set: { enabled in
                                Task {
                                    await purchases.setSimulatedPurchasesEnabled(enabled)
                                }
                            }
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Button("Reset simulated purchases", role: .destructive) {
                        Task { await purchases.resetSimulatedPurchases() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!purchases.isUsingSimulatedPurchases)
                }
                #endif
            }
        }
    }

    private var featuresCard: some View {
        AppThemeCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                Text("EXPLORE THE PACKAGE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .padding(.bottom, 10)

                featureRow(.screenshotStudio)
                divider
                featureRow(.promoStudio)
                divider
                featureRow(.widgets)
                divider
                featureRow(.upsells)
                divider
                featureRow(.paywalls)
                divider
                featureRow(.themes)
                divider
                featureRow(.screenshotTemplates)
                divider
                featureRow(.infrastructure)
                divider

                Button {
                    isShowingOnboarding = true
                } label: {
                    featureLabel(
                        title: "Onboarding",
                        subtitle: "Preview the reusable onboarding flow",
                        systemImage: "rectangle.stack.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func featureRow(_ feature: DemoFeature) -> some View {
        NavigationLink(value: feature) {
            featureLabel(
                title: feature.title,
                subtitle: feature.subtitle,
                systemImage: feature.systemImage
            )
        }
        .buttonStyle(.plain)
    }

    private func featureLabel(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
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

    private var divider: some View {
        Divider()
            .overlay(theme.borderColor)
            .padding(.leading, 56)
    }

    @ViewBuilder
    private func destination(for feature: DemoFeature) -> some View {
        switch feature {
        case .screenshotStudio:
            ScreenshotStudioDemoView()
        case .promoStudio:
            PromoVideoStudioDemoView()
        case .widgets:
            WidgetShowcaseDemoView()
        case .upsells:
            PurchaseUpsellDemoView()
        case .paywalls:
            PaywallStylePickerView { selectedPaywallStyle = $0 }
        case .themes:
            ThemeDemoView()
        case .screenshotTemplates:
            ScreenshotTemplateGalleryView()
        case .infrastructure:
            InfrastructureDemoView()
        }
    }

    @ViewBuilder
    private func paywall(for style: PaywallStyle) -> some View {
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
                ? "Use the paywall to test purchases without App Store Connect."
                : "The Demo is currently using live StoreKit."
            #else
            "Open the default paywall to test StoreKit purchases."
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

private enum DemoFeature: Hashable {
    case screenshotStudio
    case promoStudio
    case widgets
    case upsells
    case paywalls
    case themes
    case screenshotTemplates
    case infrastructure

    var title: String {
        switch self {
        case .screenshotStudio: "Screenshot Studio"
        case .promoStudio: "Promo Video Studio"
        case .widgets: "Widgets"
        case .upsells: "Pro & Upsells"
        case .paywalls: "Paywall Styles"
        case .themes: "Themes"
        case .screenshotTemplates: "Screenshot Templates"
        case .infrastructure: "New APIs"
        }
    }

    var subtitle: String {
        switch self {
        case .screenshotStudio: "Compose, preview, and export App Store screenshots"
        case .promoStudio: "Build responsive animated promo videos in SwiftUI"
        case .widgets: "Browse reusable widget designs and install guidance"
        case .upsells: "Preview Pro settings and reusable upgrade flows"
        case .paywalls: "Compare the current paywall with legacy layouts"
        case .themes: "Persistent selection and timed Pro previews"
        case .screenshotTemplates: "Explore reusable screenshot compositions"
        case .infrastructure: "Export, backup, snapshots, notifications, and utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .screenshotStudio: "photo.stack.fill"
        case .promoStudio: "film.stack.fill"
        case .widgets: "square.grid.2x2.fill"
        case .upsells: "crown.fill"
        case .paywalls: "creditcard.fill"
        case .themes: "paintpalette.fill"
        case .screenshotTemplates: "rectangle.3.group.fill"
        case .infrastructure: "shippingbox.fill"
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
