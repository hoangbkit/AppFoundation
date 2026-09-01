import AppFoundation
import SwiftUI

struct DemoSettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingPaywall = false

    private var theme: AppTheme { themes.effectiveTheme }
    private var configuration: FoundationSettingsConfiguration { DemoConfiguration.settings }
    private var metadata: AppMetadata { .current() }

    private var appIcons: [AppIconOption] {
        [
            AppIconOption(
                title: "Default",
                alternateIconName: nil,
                previewImageName: "AppIconDefaultPreview",
                accentColor: theme.accentColor
            ),
            AppIconOption(
                title: "Midnight",
                alternateIconName: "AppIconMidnight",
                previewImageName: "AppIconMidnightPreview",
                accentColor: .indigo
            ),
            AppIconOption(
                title: "Rose",
                alternateIconName: "AppIconRose",
                previewImageName: "AppIconRosePreview",
                accentColor: .pink,
                requiresUnlock: true
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                Form {
                    premiumStatusSection

                    #if DEBUG
                    developerToolsSection
                    #endif

                    ProPlanSettingsSection(
                        purchaseManager: purchases,
                        configuration: configuration.proPlanConfiguration,
                        onUpgrade: { isShowingPaywall = true }
                    )
                    .listRowBackground(theme.surfaceColor)

                    Section("AI") {
                        NavigationLink {
                            DemoAIProvidersView()
                        } label: {
                            Label("AI Providers", systemImage: "sparkles")
                        }
                    }
                    .listRowBackground(theme.surfaceColor)

                    Section {
                        ThemePickerView(
                            manager: themes,
                            title: nil,
                            onRequestUpgrade: { isShowingPaywall = true }
                        )
                    } header: {
                        Text("App Theme")
                    } footer: {
                        Text("Choose a theme for the Demo app. Pro themes can be previewed before upgrading.")
                    }
                    .listRowBackground(theme.surfaceColor)

                    AppIconPickerSection(
                        icons: appIcons,
                        footer: "Default and Midnight are included with Free. Rose demonstrates a Pro-only alternate icon.",
                        isLocked: { icon in
                            icon.requiresUnlock && !purchases.hasPro
                        },
                        onRequestUnlock: { _ in
                            isShowingPaywall = true
                        }
                    )
                    .listRowBackground(theme.surfaceColor)

                    supportSection
                    legalSection

                    Section("About") {
                        LabeledContent("Version", value: metadata.versionAndBuild)
                        LabeledContent("Built with", value: "AppFoundation")
                        LabeledContent("Platform", value: "iOS 26")
                    }
                    .listRowBackground(theme.surfaceColor)
                }
                .scrollContentBackground(.hidden)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                ProPaywallView(
                    purchases: purchases,
                    configuration: DemoConfiguration.proPaywall
                )
            }
        }
        .tint(theme.accentColor)
    }

    private var premiumStatusSection: some View {
        Section("Premium status") {
            HStack(spacing: 12) {
                Image(systemName: entitlementIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(entitlementColor)
                    .frame(width: 38, height: 38)
                    .background(
                        entitlementColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(entitlementTitle)
                        .font(.headline)
                    Text(entitlementMessage)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryForegroundColor)
                }

                Spacer(minLength: 8)
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    #if DEBUG
    private var developerToolsSection: some View {
        Section("Developer") {
            NavigationLink {
                FoundationDeveloperView(
                    purchaseManager: purchases,
                    configuration: developerConfiguration
                )
            } label: {
                Label("Developer Tools", systemImage: "hammer.fill")
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var developerConfiguration: FoundationDeveloperConfiguration {
        FoundationDeveloperConfiguration(
            replays: [
                FoundationDeveloperReplay(
                    id: "paywall",
                    title: "Paywall",
                    systemImage: "rectangle.portrait.and.arrow.forward"
                ) { _ in
                    ProPaywallView(
                        purchases: purchases,
                        configuration: DemoConfiguration.proPaywall
                    )
                },
                FoundationDeveloperReplay(
                    id: "upsell",
                    title: "Limit Upsell",
                    systemImage: "crown"
                ) { _ in
                    LimitReachedUpsellFlow(
                        configuration: DemoConfiguration.limitReachedUpsell
                    ) {
                        ProPaywallView(
                            purchases: purchases,
                            configuration: DemoConfiguration.proPaywall
                        )
                    }
                },
                FoundationDeveloperReplay(
                    id: "onboarding",
                    title: "Onboarding",
                    systemImage: "rectangle.stack.fill",
                    presentation: .fullScreen
                ) { close in
                    FoundationOnboardingView(
                        pages: DemoConfiguration.onboardingPages,
                        configuration: FoundationOnboardingConfiguration(
                            headerTitle: "APPFOUNDATION",
                            completionTitle: "Close Preview",
                            buttonAppearance: .themed
                        )
                    ) { page, context in
                        DemoOnboardingPageView(page: page, context: context)
                    } onCompletion: {
                        close()
                    }
                },
                FoundationDeveloperReplay(
                    id: "celebration",
                    title: "Pro Celebration",
                    systemImage: "party.popper.fill"
                ) { _ in
                    ProCelebrationView(
                        configuration: DemoConfiguration.proCelebration(for: purchases)
                    )
                },
            ],
            resetOnboarding: FoundationDeveloperAction(
                id: "reset-onboarding",
                title: "Reset Onboarding",
                systemImage: "arrow.counterclockwise",
                role: .destructive
            ) {
                hasCompletedOnboarding = false
            },
            additionalSections: [
                FoundationDeveloperSection(
                    id: "demo",
                    title: "Demo",
                    items: [
                        .value(
                            FoundationDeveloperValue(
                                id: "theme",
                                title: "Current theme",
                                value: { themes.effectiveTheme.title }
                            )
                        ),
                        .destination(
                            FoundationDeveloperDestination(
                                id: "startup-resilience",
                                title: "Startup Resilience Simulator",
                                systemImage: "heart.text.square"
                            ) {
                                StartupResilienceDemoView()
                            }
                        ),
                        .action(
                            FoundationDeveloperAction(
                                id: "reset-theme",
                                title: "Reset Theme",
                                systemImage: "paintpalette",
                                role: .destructive
                            ) {
                                themes.reset()
                            }
                        ),
                    ]
                )
            ]
        )
    }
    #endif

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
                ? "Open Developer Tools to test purchases without App Store Connect."
                : "The Demo is currently using live StoreKit."
            #else
            "Open the default paywall to test StoreKit purchases."
            #endif
        case .active:
            #if DEBUG
            purchases.isUsingSimulatedPurchases
                ? "This entitlement comes from the Developer Tools simulator."
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

    @ViewBuilder
    private var supportSection: some View {
        Section("Support") {
            if let supportURL = configuration.supportURL {
                Link(destination: supportURL) {
                    Label("Contact Support", systemImage: "questionmark.circle")
                }
            }

            Button {
                requestReview()
            } label: {
                Label("Rate Demo", systemImage: "star")
            }

            if let shareURL = configuration.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share Demo", systemImage: "square.and.arrow.up")
                }
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    @ViewBuilder
    private var legalSection: some View {
        if configuration.privacyURL != nil || configuration.termsURL != nil {
            Section("Legal") {
                if let privacyURL = configuration.privacyURL {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                if let termsURL = configuration.termsURL {
                    Link(destination: termsURL) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
            }
            .listRowBackground(theme.surfaceColor)
        }
    }
}
