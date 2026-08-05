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
                    managedSummary
                }
                .listRowBackground(theme.surfaceColor)

                Section("Included") {
                    benefitRow(
                        "No API key required",
                        message: "The app handles provider access for you.",
                        systemImage: "key.slash.fill"
                    )
                    benefitRow(
                        "Monthly allowance",
                        message: "Usage and limits are shown by the app.",
                        systemImage: "chart.bar.fill"
                    )
                    benefitRow(
                        "Works automatically",
                        message: "No model or provider setup is needed.",
                        systemImage: "sparkles"
                    )
                }
                .listRowBackground(theme.surfaceColor)

                Section {
                    Label(
                        "Managed AI is unavailable in this Demo build.",
                        systemImage: "info.circle.fill"
                    )
                    .foregroundStyle(theme.secondaryForegroundColor)
                } footer: {
                    Text(
                        "Production apps connect this option to their own managed AI service and display the user's remaining allowance here."
                    )
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var managedSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.accentColor.opacity(0.14))
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.title)
                    .font(.headline)
                Text("Built into the app")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }

            Spacer(minLength: 12)

            Text("Unavailable")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryForegroundColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    theme.secondaryForegroundColor.opacity(0.12),
                    in: Capsule()
                )
        }
        .padding(.vertical, 4)
    }

    private func benefitRow(
        _ title: String,
        message: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }
        }
        .padding(.vertical, 3)
    }
}

@MainActor
private struct DemoAIDirectProviderView: View {
    @Environment(ThemeManager.self) private var themes

    let manager: AppAIBackendManager
    let descriptor: AppAIBackendDescriptor
    let onConfigurationChanged: @MainActor () -> Void

    @State private var apiKey = ""
    @State private var model = ""
    @State private var savedAPIKey = ""
    @State private var savedModel = ""
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
                apiKey: $apiKey,
                model: $model,
                canSave: canSave,
                save: saveConfiguration,
                testConnection: testConnection,
                browseModels: descriptor.capabilities.supportsModelDiscovery
                    ? { isShowingModelBrowser = true }
                    : nil
            )
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isShowingModelBrowser) {
            NavigationStack {
                DemoAIModelBrowserView(
                    manager: manager,
                    descriptor: descriptor,
                    credential: apiKey
                ) { selectedModel in
                    model = selectedModel
                }
            }
        }
        .task {
            guard !didLoad else { return }
            await loadConfiguration()
            didLoad = true
        }
    }

    private var normalizedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        didLoad
            && !normalizedModel.isEmpty
            && (
                normalizedAPIKey != savedAPIKey
                    || normalizedModel != savedModel
            )
    }

    private func loadConfiguration() async {
        apiKey = (try? await manager.credential(for: providerID)) ?? ""
        model = manager.model(for: providerID)
        savedAPIKey = normalizedAPIKey
        savedModel = normalizedModel
    }

    private func saveConfiguration() async throws {
        if normalizedAPIKey.isEmpty {
            try await manager.removeCredential(for: providerID)
        } else {
            try await manager.saveCredential(
                normalizedAPIKey,
                for: providerID
            )
        }

        await manager.setModelAndWait(normalizedModel, for: providerID)
        apiKey = normalizedAPIKey
        model = normalizedModel
        savedAPIKey = normalizedAPIKey
        savedModel = normalizedModel
        onConfigurationChanged()
    }

    private func testConnection() async throws {
        try await manager.test(
            provider: providerID,
            credential: normalizedAPIKey,
            model: normalizedModel
        )
    }
}

@MainActor
private struct DemoAIModelBrowserView: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.dismiss) private var dismiss

    let manager: AppAIBackendManager
    let descriptor: AppAIBackendDescriptor
    let credential: String
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
        .toolbarBackground(.visible, for: .navigationBar)
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
            models = try await manager.availableModels(
                for: providerID,
                credential: credential
            )
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
