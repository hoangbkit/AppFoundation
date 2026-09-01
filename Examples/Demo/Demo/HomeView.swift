import AppFoundation
import SwiftUI

struct HomeView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes

    @State private var isShowingPaywall = false
    @State private var isShowingCelebration = false
    @State private var isShowingSettings = false
    @State private var isShowingOnboarding = false
    @State private var isShowingFlexibleOnboarding = false

    #if DEBUG
    @State private var isShowingDeveloperTools = false
    #endif

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                AppThemeBackground(theme: theme)

                List {
                    heroSection
                    appExperiencesSection
                    studiosAndInfrastructureSection
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(theme.primaryForegroundColor)
            .navigationTitle("AppFoundation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        isShowingSettings = true
                    }
                    .labelStyle(.iconOnly)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    #if DEBUG
                    Button("Developer Tools", systemImage: "hammer.fill") {
                        isShowingDeveloperTools = true
                    }
                    .labelStyle(.iconOnly)
                    #endif

                    Button(
                        purchases.hasPro ? "Show Pro celebration" : "Unlock Pro",
                        systemImage: "crown.fill"
                    ) {
                        if purchases.hasPro {
                            isShowingCelebration = true
                        } else {
                            isShowingPaywall = true
                        }
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
            .sheet(isPresented: $isShowingCelebration) {
                ProCelebrationView(
                    configuration: DemoConfiguration.proCelebration(for: purchases)
                )
            }
            .sheet(isPresented: $isShowingSettings) {
                DemoSettingsView()
            }
            #if DEBUG
            .sheet(isPresented: $isShowingDeveloperTools) {
                NavigationStack {
                    DemoDeveloperView()
                }
            }
            #endif
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages
                ) {
                    isShowingOnboarding = false
                }
            }
            .fullScreenCover(isPresented: $isShowingFlexibleOnboarding) {
                FoundationOnboardingView(
                    pages: DemoConfiguration.onboardingPages,
                    configuration: FoundationOnboardingConfiguration(
                        headerTitle: "APPFOUNDATION",
                        completionTitle: "Back to Demo",
                        buttonAppearance: .themed
                    )
                ) { page, context in
                    DemoOnboardingPageView(page: page, context: context)
                } onCompletion: {
                    isShowingFlexibleOnboarding = false
                }
            }
        }
        .tint(theme.accentColor)
        .animation(.smooth, value: theme.id)
    }

    private var heroSection: some View {
        Section {
            AppThemeCard(theme: theme) {
                VStack(alignment: .leading, spacing: 14) {
                    FoundationPill(
                        "AppFoundation",
                        systemImage: "swift",
                        tint: theme.accentColor
                    )

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
                            platformTag("iOS 26.0+")
                            platformTag("macOS 15.0+")
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func platformTag(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.secondaryForegroundColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.elevatedSurfaceColor, in: Capsule())
            .overlay { Capsule().strokeBorder(theme.borderColor) }
    }

    private var appExperiencesSection: some View {
        Section("App Experiences") {
            NavigationLink {
                PurchaseUpsellDemoView()
            } label: {
                demoRow(
                    title: "Pro & Upsells",
                    subtitle: "Paywall, plan settings, and limit-reached upgrade flow",
                    systemImage: "crown.fill"
                )
            }

            NavigationLink {
                WidgetShowcaseDemoView()
            } label: {
                demoRow(
                    title: "Widgets",
                    subtitle: "Reusable widget showcase and install guidance",
                    systemImage: "square.grid.2x2.fill"
                )
            }

            NavigationLink {
                ThemeDemoView()
            } label: {
                demoRow(
                    title: "Themes",
                    subtitle: "Persistent selection and timed Pro previews",
                    systemImage: "paintpalette.fill"
                )
            }

            Button {
                isShowingOnboarding = true
            } label: {
                demoRow(
                    title: "Onboarding",
                    subtitle: "Reusable icon-and-copy onboarding flow",
                    systemImage: "rectangle.stack.fill"
                )
            }
            .buttonStyle(.plain)

            Button {
                isShowingFlexibleOnboarding = true
            } label: {
                demoRow(
                    title: "Flexible Onboarding",
                    subtitle: "App-owned SwiftUI pages inside the shared flow",
                    systemImage: "rectangle.stack.badge.plus"
                )
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var studiosAndInfrastructureSection: some View {
        Section("Studios & Infrastructure") {
            NavigationLink {
                ScreenshotStudioDemoView()
            } label: {
                demoRow(
                    title: "Screenshot Studio",
                    subtitle: "Compose, preview, and export App Store screenshots",
                    systemImage: "photo.stack.fill"
                )
            }

            NavigationLink {
                PromoVideoStudioDemoView()
            } label: {
                demoRow(
                    title: "Promo Video Studio",
                    subtitle: "Build responsive animated promo videos in SwiftUI",
                    systemImage: "film.stack.fill"
                )
            }

            NavigationLink {
                InfrastructureDemoView()
            } label: {
                demoRow(
                    title: "Infrastructure",
                    subtitle: "Export, backup, startup, shared data, and notifications",
                    systemImage: "shippingbox.fill"
                )
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private func demoRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(theme.primaryForegroundColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
