#if canImport(SwiftUI) && canImport(StoreKit)
import StoreKit
import SwiftUI

public struct FoundationSettingsConfiguration {
    public let appName: String
    public let supportURL: URL?
    public let privacyURL: URL?
    public let termsURL: URL?
    public let shareURL: URL?
    public let theme: FoundationTheme

    public init(
        appName: String,
        supportURL: URL? = nil,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        shareURL: URL? = nil,
        theme: FoundationTheme = .indigo
    ) {
        self.appName = appName
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.shareURL = shareURL
        self.theme = theme
    }
}

public struct FoundationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    private let purchases: PurchaseController?
    private let configuration: FoundationSettingsConfiguration
    private let metadata: AppMetadata

    @State private var restoreMessage: String?

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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .tint(configuration.theme.primary)
            .alert("Restore Purchases", isPresented: restoreAlertBinding) {
                Button("OK", role: .cancel) {
                    restoreMessage = nil
                }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private func purchaseSection(_ purchases: PurchaseController) -> some View {
        Section("Purchases") {
            Button {
                Task {
                    let outcome = await purchases.restorePurchases()
                    switch outcome {
                    case .restored:
                        restoreMessage = "Your purchases have been restored."
                    case .nothingToRestore:
                        restoreMessage = "No previous purchases were found."
                    case .failed(let failure):
                        restoreMessage = failure.message
                        purchases.clearActivity()
                    }
                }
            } label: {
                HStack {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                    Spacer()
                    if case .restoring = purchases.activity {
                        ProgressView()
                    }
                }
            }
            .disabled(purchases.isBusy)

            if purchases.isEntitled {
                Label("Premium is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(configuration.theme.primary)
            }
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
                Label("Rate \(configuration.appName)", systemImage: "star")
            }

            if let shareURL = configuration.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share \(configuration.appName)", systemImage: "square.and.arrow.up")
                }
            }
        }
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
        }
    }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { isPresented in
                if !isPresented {
                    restoreMessage = nil
                }
            }
        )
    }
}
#endif
