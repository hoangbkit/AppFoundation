import AppFoundation
import SwiftUI

struct DemoSettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

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

                    supportSection
                    legalSection
                    aboutSection
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
}
