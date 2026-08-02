import AppFoundation
import StoreKit
import SwiftUI

struct DemoSettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ThemeManager.self) private var themes
    @Environment(\.appFoundationVisualStyle) private var visualStyle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @AppStorage("appfoundation.demo.visual-style")
    private var visualStyleID = DemoVisualStyleOption.signature.rawValue

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
                    visualStyleSection

                    #if DEBUG
                    simulatedPurchasesSection
                    #endif

                    ProPlanSettingsSection(
                        purchaseManager: purchases,
                        configuration: configuration.proPlanConfiguration,
                        onUpgrade: { isShowingPaywall = true }
                    )
                    .listRowBackground(rowBackground)

                    Section {
                        ThemePickerView(
                            manager: themes,
                            title: nil,
                            onRequestUpgrade: { isShowingPaywall = true }
                        )
                    } header: {
                        Text("App Theme")
                    } footer: {
                        Text("Choose a color theme for the Demo app. Pro themes can be previewed before upgrading.")
                    }
                    .listRowBackground(rowBackground)

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
                    .listRowBackground(rowBackground)

                    supportSection
                    legalSection

                    Section("About") {
                        LabeledContent("Version", value: metadata.versionAndBuild)
                        LabeledContent("Built with", value: "AppFoundation")
                        LabeledContent("Platform", value: "iOS 26")
                    }
                    .listRowBackground(rowBackground)
                }
                .scrollContentBackground(formBackgroundVisibility)
            }
            .foregroundStyle(primaryForeground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(toolbarVisibility, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(
                    purchaseManager: purchases,
                    configuration: DemoConfiguration.modernPaywall
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
                        .foregroundStyle(secondaryForeground)
                }

                Spacer(minLength: 8)
            }
        }
        .listRowBackground(rowBackground)
    }

    private var visualStyleSection: some View {
        Section {
            Picker("Built-in views", selection: visualStyleSelection) {
                ForEach(DemoVisualStyleOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Visual Style")
        } footer: {
            Text("Changes AppFoundation backgrounds, surfaces, shadows, buttons, navigation chrome, onboarding, paywalls, and theme previews live.")
        }
        .listRowBackground(rowBackground)
    }

    #if DEBUG
    private var simulatedPurchasesSection: some View {
        Section("Debug purchases") {
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

            NavigationLink {
                SimulatedPlansEditorView()
            } label: {
                LabeledContent(
                    "Configure simulated plans",
                    value: "\(purchases.configuration.productIDs.count)"
                )
            }
            .disabled(!purchases.isUsingSimulatedPurchases)

            Button("Reset simulated purchases", role: .destructive) {
                Task { await purchases.resetSimulatedPurchases() }
            }
            .disabled(!purchases.isUsingSimulatedPurchases)
        }
        .listRowBackground(rowBackground)
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
        case .checking: secondaryForeground
        case .inactive, .active: theme.accentColor
        }
    }

    private var visualStyleSelection: Binding<DemoVisualStyleOption> {
        Binding(
            get: { DemoVisualStyleOption(rawValue: visualStyleID) ?? .signature },
            set: { visualStyleID = $0.rawValue }
        )
    }

    private var primaryForeground: Color {
        visualStyle.background == .systemGrouped ? .primary : theme.primaryForegroundColor
    }

    private var secondaryForeground: Color {
        visualStyle.background == .systemGrouped ? .secondary : theme.secondaryForegroundColor
    }

    private var rowBackground: Color {
        switch visualStyle.surface {
        case .plain:
            .clear
        case .solid where visualStyle.background == .systemGrouped:
            Color(uiColor: .secondarySystemGroupedBackground)
        case .automatic, .solid, .material:
            theme.surfaceColor
        }
    }

    private var formBackgroundVisibility: Visibility {
        visualStyle.background == .systemGrouped ? .visible : .hidden
    }

    private var toolbarVisibility: Visibility {
        visualStyle.navigationChrome == .system ? .visible : .hidden
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
        .listRowBackground(rowBackground)
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
            .listRowBackground(rowBackground)
        }
    }
}
