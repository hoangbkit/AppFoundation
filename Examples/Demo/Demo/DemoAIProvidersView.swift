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
                subtitle: "Built into the app"
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
            )
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
            )
        ]

        return AppAIBackendManager(
            catalog: catalog,
            clients: clients,
            credentialStore: credentials,
            preferences: preferences,
            selectedBackendID: .managed
        )
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
                        "Managed AI works automatically. You can also connect your own provider and use its API key directly."
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
                                isSelected: manager.selectedBackendID == descriptor.id,
                                statusText: statusText(for: descriptor)
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

    private func statusText(
        for descriptor: AppAIBackendDescriptor
    ) -> String {
        switch descriptor.id {
        case .managed:
            "Unavailable"
        case .direct:
            configuredBackends[descriptor.id] == true
                ? "Configured"
                : "Not Configured"
        }
    }

    private func refreshStatuses() async {
        var values: [AppAIBackendID: Bool] = [:]

        for descriptor in manager.catalog.backends {
            switch descriptor.id {
            case .managed:
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
                    Label("Built into the app", systemImage: "sparkles")
                        .foregroundStyle(theme.accentColor)

                    Text(
                        "Managed AI requires no personal API key. The app handles provider access, models, and usage limits."
                    )
                    .foregroundStyle(theme.secondaryForegroundColor)
                } header: {
                    Text("Managed Provider")
                }
                .listRowBackground(theme.surfaceColor)

                Section("Availability") {
                    LabeledContent("Status", value: "Unavailable")

                    Text(
                        "This Demo build does not connect to a managed AI service."
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
    @State private var isShowingModelBrowser = false

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

            AppAIDirectProviderConfigurationView(
                descriptor: descriptor,
                model: $model,
                hasCredential: hasCredential,
                saveCredential: saveCredential,
                removeCredential: removeCredential,
                saveModel: saveModel,
                testConnection: testConnection,
                browseModels: descriptor.capabilities.supportsModelDiscovery
                    ? { isShowingModelBrowser = true }
                    : nil,
                credentialFooter: "The key is stored in Keychain and is never synced through iCloud. The Demo sends request content directly to \(descriptor.title) only when this provider is used."
            )
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingModelBrowser) {
            NavigationStack {
                DemoAIModelBrowserView(
                    manager: manager,
                    descriptor: descriptor,
                    selectedModelID: model
                ) { selectedModel in
                    model = selectedModel
                }
            }
        }
        .task {
            guard !didLoad else { return }
            model = manager.model(for: providerID)
            hasCredential = await manager.isConfigured(descriptor.id)
            didLoad = true
        }
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

    private func saveModel(_ candidateModel: String) async throws {
        await manager.setModelAndWait(candidateModel, for: providerID)
        model = manager.model(for: providerID)
        onConfigurationChanged()
    }

    private func testConnection(_ candidateModel: String) async throws {
        await manager.setModelAndWait(candidateModel, for: providerID)
        model = manager.model(for: providerID)
        try await manager.test(provider: providerID, model: model)
        onConfigurationChanged()
    }
}

@MainActor
private struct DemoAIModelBrowserView: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss

    let manager: AppAIBackendManager
    let descriptor: AppAIBackendDescriptor
    let selectedModelID: String
    let onSelect: @MainActor (String) -> Void

    @State private var models: [AppAIModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var theme: AppTheme { themes.effectiveTheme }

    private var providerID: AppAIProviderID {
        guard case .direct(let providerID) = descriptor.id else {
            preconditionFailure("Model browser requires a direct backend")
        }
        return providerID
    }

    private var filteredModels: [AppAIModel] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return models }

        return models.filter {
            $0.id.localizedCaseInsensitiveContains(query)
                || $0.displayName.localizedCaseInsensitiveContains(query)
        }
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
                } else if filteredModels.isEmpty {
                    ContentUnavailableView(
                        "No Matching Models",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    List(filteredModels) { model in
                        Button {
                            manager.setModel(model.id, for: providerID)
                            onSelect(model.id)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.displayName)
                                        .foregroundStyle(
                                            theme.primaryForegroundColor
                                        )
                                    Text(model.id)
                                        .font(.caption)
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

                                Spacer()

                                if selectedModelID == model.id {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .searchable(text: $searchText, prompt: "Search models")
        .navigationTitle("Choose Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
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
