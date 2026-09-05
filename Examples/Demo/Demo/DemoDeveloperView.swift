#if DEBUG
import AppFoundation
import SwiftUI

struct DemoDeveloperView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        FoundationDeveloperView(
            purchaseManager: purchases,
            configuration: configuration
        )
    }

    private var configuration: FoundationDeveloperConfiguration {
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
                ),
                FoundationDeveloperSection(
                    id: "analytics",
                    title: "Analytics",
                    items: [
                        .action(
                            FoundationDeveloperAction(
                                id: "analytics-track",
                                title: "Track Demo Event",
                                systemImage: "chart.bar.xaxis"
                            ) {
                                try await DemoConfiguration.analytics.track(
                                    "demo_action",
                                    dimension: "developer_tools"
                                )
                            }
                        ),
                        .action(
                            FoundationDeveloperAction(
                                id: "analytics-flush",
                                title: "Flush Analytics",
                                systemImage: "arrow.up.circle"
                            ) {
                                try await DemoConfiguration.analytics.flush()
                            }
                        ),
                        .action(
                            FoundationDeveloperAction(
                                id: "analytics-reset",
                                title: "Reset Analytics State",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                try await DemoConfiguration.analytics.resetLocalState()
                            }
                        ),
                    ]
                ),
            ]
        )
    }
}
#endif
