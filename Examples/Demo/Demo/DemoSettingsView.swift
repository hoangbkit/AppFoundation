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
                    ProPlanSettingsSection(
                        purchaseManager: purchases,
                        configuration: configuration.proPlanConfiguration,
                        onUpgrade: { isShowingPaywall = true }
                    )
                    .listRowBackground(theme.surfaceColor)

                    appearanceSection

                    AppIconPickerSection(
                        icons: appIcons,
                        footer: "Rose demonstrates a Pro-only alternate icon.",
                        isLocked: { icon in
                            icon.requiresUnlock && !purchases.hasPro
                        },
                        onRequestUnlock: { _ in
                            isShowingPaywall = true
                        }
                    )
                    .listRowBackground(theme.surfaceColor)

                    Section("App") {
                        NavigationLink {
                            DemoAIProvidersView()
                        } label: {
                            Label("AI Providers", systemImage: "sparkles")
                        }
                    }
                    .listRowBackground(theme.surfaceColor)

                    supportSection
                    legalSection
                    aboutSection

                    #if DEBUG
                    developerToolsSection
                    #endif
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
                    .labelStyle(.iconOnly)
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

    private var appearanceSection: some View {
        Section {
            ThemePickerView(
                manager: themes,
                title: nil,
                onRequestUpgrade: { isShowingPaywall = true }
            )
        } header: {
            Text("Theme")
        } footer: {
            Text("Pro themes can be previewed before upgrading.")
        }
        .listRowBackground(theme.surfaceColor)
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

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: metadata.versionAndBuild)
            LabeledContent("Built with", value: "AppFoundation")
            LabeledContent("Platform", value: "iOS 26")
        }
        .listRowBackground(theme.surfaceColor)
    }

    #if DEBUG
    private var developerToolsSection: some View {
        Section {
            NavigationLink {
                FoundationDeveloperView(
                    purchaseManager: purchases,
                    configuration: developerConfiguration
                )
            } label: {
                Label("Developer Tools", systemImage: "hammer.fill")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Purchase simulation, failure modes, replay flows, startup recovery, and diagnostics.")
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
}
