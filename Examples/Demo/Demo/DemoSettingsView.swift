import AppFoundation
import StoreKit
import SwiftUI

struct DemoSettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes
    @Environment(\.requestReview) private var requestReview

    @State private var isShowingPaywall = false

    private var theme: AppTheme { themes.effectiveTheme }
    private var configuration: FoundationSettingsConfiguration { DemoConfiguration.settings }
    private var metadata: AppMetadata { .current() }

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

                    Section("Appearance") {
                        NavigationLink {
                            ThemeDemoView()
                        } label: {
                            Label("Themes", systemImage: "paintpalette.fill")
                        }
                    }
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
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(
                    purchaseManager: purchases,
                    configuration: DemoConfiguration.modernPaywall
                )
            }
        }
        .tint(theme.accentColor)
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
