#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

public struct FoundationSettingsConfiguration {
    public let appName: String
    public let supportURL: URL?
    public let privacyURL: URL?
    public let termsURL: URL?
    public let shareURL: URL?
    public let proPlanConfiguration: ProPlanSettingsConfiguration
    public let paywallConfiguration: PaywallConfiguration?

    /// Retained for source compatibility with callers that explicitly provide
    /// a fixed `FoundationTheme`.
    public let theme: FoundationTheme

    /// Optional full `AppTheme` override. When nil, theme-aware configurations
    /// follow the active theme installed with `.appFoundationTheme(_:)`.
    public let themeOverride: AppTheme?

    public let followsActiveTheme: Bool

    /// Creates settings that follow the active app theme.
    public init(
        appName: String,
        supportURL: URL? = nil,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        shareURL: URL? = nil,
        proPlanConfiguration: ProPlanSettingsConfiguration? = nil,
        paywallConfiguration: PaywallConfiguration? = nil,
        themeOverride: AppTheme? = nil
    ) {
        self.appName = appName
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.shareURL = shareURL
        self.proPlanConfiguration = proPlanConfiguration ?? ProPlanSettingsConfiguration(
            sectionTitle: "\(appName) Pro",
            activePlanTitle: "\(appName) Pro",
            unlockTitle: "Unlock \(appName) Pro"
        )
        self.paywallConfiguration = paywallConfiguration
        self.theme = .indigo
        self.themeOverride = themeOverride
        self.followsActiveTheme = true
    }

    /// Creates settings with a fixed legacy `FoundationTheme` override.
    public init(
        appName: String,
        supportURL: URL? = nil,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        shareURL: URL? = nil,
        proPlanConfiguration: ProPlanSettingsConfiguration? = nil,
        paywallConfiguration: PaywallConfiguration? = nil,
        theme: FoundationTheme
    ) {
        self.appName = appName
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.shareURL = shareURL
        self.proPlanConfiguration = proPlanConfiguration ?? ProPlanSettingsConfiguration(
            sectionTitle: "\(appName) Pro",
            activePlanTitle: "\(appName) Pro",
            unlockTitle: "Unlock \(appName) Pro"
        )
        self.paywallConfiguration = paywallConfiguration
        self.theme = theme
        self.themeOverride = nil
        self.followsActiveTheme = false
    }
}

public struct FoundationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.appFoundationTheme) private var environmentTheme

    private let purchases: PurchaseController?
    private let configuration: FoundationSettingsConfiguration
    private let metadata: AppMetadata

    @State private var isShowingPaywall = false

    public init(
        purchases: PurchaseController? = nil,
        configuration: FoundationSettingsConfiguration,
        metadata: AppMetadata = .current()
    ) {
        self.purchases = purchases
        self.configuration = configuration
        self.metadata = metadata
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                background

                List {
                    if let purchases {
                        purchaseSection(purchases)
                    }

                    supportSection
                    legalSection

                    Section("About") {
                        LabeledContent("Version", value: metadata.versionAndBuild)
                        LabeledContent("Built with", value: "AppFoundation")
                    }
                    .listRowBackground(surface)
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(primaryForeground)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(accent)
            .preferredColorScheme(preferredColorScheme)
            .sheet(isPresented: $isShowingPaywall) {
                if let purchases, let paywallConfiguration = configuration.paywallConfiguration {
                    PaywallView(
                        purchaseManager: purchases,
                        configuration: paywallConfiguration
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if configuration.followsActiveTheme {
            AppThemeBackground(theme: activeTheme)
        } else {
            FoundationBackground(theme: configuration.theme)
        }
    }

    private func purchaseSection(_ purchases: PurchaseController) -> some View {
        let onUpgrade: (() -> Void)?
        if configuration.paywallConfiguration != nil {
            onUpgrade = { isShowingPaywall = true }
        } else {
            onUpgrade = nil
        }

        return ProPlanSettingsSection(
            purchaseManager: purchases,
            configuration: configuration.proPlanConfiguration,
            onUpgrade: onUpgrade
        )
        .listRowBackground(surface)
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
                Label("Rate \(configuration.appName)", systemImage: "star")
            }

            if let shareURL = configuration.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share \(configuration.appName)", systemImage: "square.and.arrow.up")
                }
            }
        }
        .listRowBackground(surface)
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
            .listRowBackground(surface)
        }
    }

    private var activeTheme: AppTheme {
        configuration.themeOverride ?? environmentTheme
    }

    private var accent: Color {
        configuration.followsActiveTheme ? activeTheme.accentColor : configuration.theme.primary
    }

    private var primaryForeground: Color {
        configuration.followsActiveTheme ? activeTheme.primaryForegroundColor : .primary
    }

    private var surface: Color {
        configuration.followsActiveTheme
            ? activeTheme.surfaceColor
            : Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var preferredColorScheme: ColorScheme? {
        configuration.followsActiveTheme
            ? activeTheme.appearance.preferredColorScheme.colorScheme
            : nil
    }
}
#endif
