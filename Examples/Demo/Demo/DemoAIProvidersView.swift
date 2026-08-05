import AppFoundation
import Foundation
import SwiftUI

// The Demo intentionally leaves managed AI unconfigured. It still presents the
// managed backend so apps can see how it fits beside direct BYOK providers.
enum DemoAIConfiguration {
    static let catalog = AppAIBackendCatalog(
        backends: [
            .managed(
                title: "Managed AI",
                subtitle: "Proxy-backed capabilities — not configured in Demo"
            ),
            .direct(
                providerID: .openRouter,
                title: "OpenRouter",
                subtitle: "Use models available through your OpenRouter account",
                symbolName: "arrow.triangle.branch",
                preferredModel: "openai/gpt-4.1-mini"
            ),
            .direct(
                providerID: .openAI,
                title: "OpenAI",
                subtitle: "Connect directly with your OpenAI API key",
                symbolName: "bubble.left.and.bubble.right.fill",
                preferredModel: "gpt-4.1-mini"
            ),
            .direct(
                providerID: .anthropic,
                title: "Anthropic",
                subtitle: "Connect directly with your Anthropic API key",
                symbolName: "text.bubble.fill",
                preferredModel: "claude-haiku-4-5-20251001"
            ),
            .direct(
                providerID: .gemini,
                title: "Gemini",
                subtitle: "Connect directly with your Google AI API key",
                symbolName: "diamond.fill",
                preferredModel: "gemini-2.5-flash"
            ),
            .direct(
                providerID: .deepSeek,
                title: "DeepSeek",
                subtitle: "Connect directly with your DeepSeek API key",
                symbolName: "waveform.path.ecg",
                preferredModel: "deepseek-chat"
            ),
            .direct(
                providerID: .nvidia,
                title: "NVIDIA Build",
                subtitle: "Use an NVIDIA-hosted OpenAI-compatible model",
                symbolName: "cpu.fill",
                preferredModel: "meta/llama-3.1-70b-instruct"
            ),
        ]
    )

    @MainActor
    static func makeManager() -> AppAIBackendManager {
        let credentials = AppAIKeychainCredentialStore(
            service: "com.hoangbkit.afdemo.ai-providers"
        )
        let preferences = UserDefaultsAppAIBackendPreferences(
            namespace: "com.hoangbkit.afdemo"
        )

        let clients: [any AppAIDirectProviderClient] = [
            OpenAICompatibleClient(
                configuration: AppAIProviderPresets.openRouter(
                    appName: "AppFoundation Demo",
                    siteURL: URL(
                        string: "https://github.com/hoangbkit/AppFoundation"
                    ),
                    defaultModel: "openai/gpt-4.1-mini"
                ),
                credentialStore: credentials
            ),
            OpenAIResponsesClient(credentialStore: credentials),
            AnthropicMessagesClient(credentialStore: credentials),
            GeminiGenerateContentClient(credentialStore: credentials),
            OpenAICompatibleClient(
                configuration: AppAIProviderPresets.deepSeek(
                    defaultModel: "deepseek-chat"
                ),
                credentialStore: credentials
            ),
            OpenAICompatibleClient(
                configuration: AppAIProviderPresets.nvidia(
                    defaultModel: "meta/llama-3.1-70b-instruct"
                ),
                credentialStore: credentials
            ),
        ]

        return AppAIBackendManager(
            catalog: catalog,
            clients: clients,
            credentialStore: credentials,
            preferences: preferences,
            selectedBackendID: .managed
        )
    }

    static func keyExample(for provider: AppAIProviderID) -> String {
        switch provider {
        case .openRouter: "sk-or-v1-…"
        case .openAI: "sk-…"
        case .anthropic: "sk-ant-…"
        case .gemini: "AIza…"
        case .deepSeek: "sk-…"
        case .nvidia: "nvapi-…"
        default: "Provider API key"
        }
    }
}

@MainActor
struct DemoAIProvidersView: View {
    @Environment(ThemeManager.self) private var themes

    @State private var manager: AppAIBackendManager
    @State private var configuredBackends: [AppAIBackendID: Bool] = [:]
    @State private var didRestore = false

    init(manager: AppAIBackendManager? = nil) {
        _manager = State(
            initialValue: manager ?? DemoAIConfiguration.makeManager()
        )
    }

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            Form {
                Section {
                    AppAIBackendPicker(
                        "Default Provider",
                        selection: backendSelection,
                        catalog: manager.catalog
                    )
                } footer: {
                    Text(
                        "Managed AI works through the shared proxy. The app also remembers the provider selected for direct BYOK requests."
                    )
                }
                .listRowBackground(theme.surfaceColor)

                Section("Providers") {
                    ForEach(manager.catalog.backends) { descriptor in
                        NavigationLink {
                            destination(for: descriptor)
                        } label: {
                            AppAIBackendStatusRow(
                                descriptor: descriptor,
                                isConfigured: configuredBackends[descriptor.id] == true,
                                isSelected: manager.selectedBackendID == descriptor.id
                            )
                        }
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if !didRestore {
                await manager.restore()
                didRestore = true
            }
            await refreshStatuses()
        }
    }

    private var backendSelection: Binding<AppAIBackendID> {
        Binding(
            get: { manager.selectedBackendID },
            set: { manager.select($0) }
        )
    }

    @ViewBuilder
    private func destination(
        for descriptor: AppAIBackendDescriptor
    ) -> some View {
        switch descriptor.id {
        case .managed:
            DemoManagedAIConfigurationView(descriptor: descriptor)
        case .direct:
            DemoAIDirectProviderView(
                manager: manager,
                descriptor: descriptor
            ) {
                Task { await refreshStatuses() }
            }
        }
    }

    private func refreshStatuses() async {
        var values: [AppAIBackendID: Bool] = [:]

        for descriptor in manager.catalog.backends {
            switch descriptor.id {
            case .managed:
                // The Demo has no proxy tenant/app key. Production apps can
                // replace this with an AppAIStatusStore-backed status.
                values[descriptor.id] = false
            case .direct:
                values[descriptor.id] = await manager.isConfigured(
                    descriptor.id
                )
            }
        }

        configuredBackends = values
    }
}

@MainActor
private struct DemoManagedAIConfigurationView: View {
    @Environment(ThemeManager.self) private var themes

    let descriptor: AppAIBackendDescriptor

    private var theme: AppTheme { themes.effectiveTheme }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            Form {
                Section {
                    AppAIBackendStatusRow(
                        descriptor: descriptor,
                        isConfigured: false,
                        isSelected: true
                    )

                    Label("Built into each app", systemImage: "sparkles")
                        .foregroundStyle(theme.accentColor)

                    Text(
                        "Managed AI requires no personal provider key. The app submits a typed capability and input while ai-proxy-server owns prompts, provider routing, models, quotas, and cost controls."
                    )
                    .foregroundStyle(theme.secondaryForegroundColor)
                } header: {
                    Text("Managed Provider")
                }
                .listRowBackground(theme.surfaceColor)

                Section("Demo Status") {
                    LabeledContent("Proxy tenant", value: "Not Configured")
                    LabeledContent("App Attest", value: "Not Connected")
                    LabeledContent(
                        "Entitlement sync",
                        value: "Not Connected"
                    )

                    Text(
                        "This is intentional. A production app supplies its own app ID, app key, proxy URL, and attestation policy when creating AppAIClient."
                    )
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
                }
                .listRowBackground(theme.surfaceColor)

                Section("Production Flow") {
                    Label(
                        "Typed capability requests",
                        systemImage: "curlybraces.square"
                    )
                    Label(
                        "Per-request App Attest assertions",
                        systemImage: "checkmark.shield.fill"
                    )
                    Label(
                        "Verified StoreKit JWS access",
                        systemImage: "checkmark.seal.fill"
                    )
                    Label(
                        "Server idempotency and stored replay",
                        systemImage: "arrow.clockwise.circle.fill"
                    )
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

@MainActor
private struct DemoAIDirectProviderView: View {
    @Environment(ThemeManager.self) private var themes

    let manager: AppAIBackendManager
    let descriptor: AppAIBackendDescriptor
    let onConfigurationChanged: @MainActor () -> Void

    @State private var model = ""
    @State private var hasCredential = false
    @State private var didLoad = false

    private var theme: AppTheme { themes.effectiveTheme }

    private var providerID: AppAIProviderID {
        guard case .direct(let providerID) = descriptor.id else {
            preconditionFailure(
                "Direct provider view requires a direct backend"
            )
        }
        return providerID
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            Form {
                Section {
                    AppAIDirectProviderConfigurationView(
                        descriptor: descriptor,
                        model: modelBinding,
                        hasCredential: hasCredential,
                        saveCredential: saveCredential,
                        removeCredential: removeCredential,
                        testConnection: testConnection
                    )
                } header: {
                    Text("Provider Configuration")
                } footer: {
                    Text(
                        "Key format: \(DemoAIConfiguration.keyExample(for: providerID)). The key stays in Keychain and is never synchronized through iCloud."
                    )
                }
                .listRowBackground(theme.surfaceColor)

                if descriptor.capabilities.supportsModelDiscovery {
                    Section("Models") {
                        NavigationLink {
                            DemoAIModelBrowserView(
                                manager: manager,
                                descriptor: descriptor
                            ) { selectedModel in
                                model = selectedModel
                            }
                        } label: {
                            LabeledContent(
                                "Browse Available Models",
                                value: hasCredential ? "Open" : "Key Required"
                            )
                        }
                        .disabled(!hasCredential)
                    }
                    .listRowBackground(theme.surfaceColor)
                }

                Section("Data Routing") {
                    Text(
                        "When this provider is selected, the app sends request content directly to \(descriptor.title). Managed proxy quotas, App Attest, and server-side replay do not apply to BYOK calls."
                    )
                    .foregroundStyle(theme.secondaryForegroundColor)
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            guard !didLoad else { return }
            model = manager.model(for: providerID)
            hasCredential = await manager.isConfigured(descriptor.id)
            didLoad = true
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { model },
            set: { value in
                model = value
                manager.setModel(value, for: providerID)
            }
        )
    }

    private func saveCredential(_ value: String) async throws {
        try await manager.saveCredential(value, for: providerID)
        hasCredential = true
        onConfigurationChanged()
    }

    private func removeCredential() async throws {
        try await manager.removeCredential(for: providerID)
        hasCredential = false
        onConfigurationChanged()
    }

    private func testConnection(_ candidateModel: String) async throws {
        await manager.setModelAndWait(candidateModel, for: providerID)
        model = manager.model(for: providerID)
        try await manager.test(provider: providerID, model: model)
    }
}

@MainActor
private struct DemoAIModelBrowserView: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss

    let manager: AppAIBackendManager
    let descriptor: AppAIBackendDescriptor
    let onSelect: @MainActor (String) -> Void

    @State private var models: [AppAIModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var theme: AppTheme { themes.effectiveTheme }

    private var providerID: AppAIProviderID {
        guard case .direct(let providerID) = descriptor.id else {
            preconditionFailure("Model browser requires a direct backend")
        }
        return providerID
    }

    var body: some View {
        ZStack {
            AppThemeBackground(theme: theme)

            Group {
                if isLoading && models.isEmpty {
                    ProgressView("Loading models…")
                } else if let errorMessage, models.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "Models Unavailable",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await load() }
                        }
                    }
                } else if models.isEmpty {
                    ContentUnavailableView(
                        "No Models Returned",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text(
                            "Enter a model ID manually on the previous screen."
                        )
                    )
                } else {
                    List(models) { model in
                        Button {
                            manager.setModel(model.id, for: providerID)
                            onSelect(model.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.displayName)
                                    .foregroundStyle(
                                        theme.primaryForegroundColor
                                    )
                                Text(model.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(
                                        theme.secondaryForegroundColor
                                    )
                                if let contextLength = model.contextLength {
                                    Text(
                                        "Context: \(contextLength.formatted()) tokens"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(
                                        theme.secondaryForegroundColor
                                    )
                                }
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.surfaceColor)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle("\(descriptor.title) Models")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            models = try await manager.availableModels(for: providerID)
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare(
                        $1.displayName
                    ) == .orderedAscending
                }
        } catch {
            models = []
            errorMessage = error.localizedDescription
        }
    }
}
