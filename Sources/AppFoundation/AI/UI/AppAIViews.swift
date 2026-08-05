#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public struct AppAIBackendPicker: View {
    private let title: String
    private let catalog: AppAIBackendCatalog
    @Binding private var selection: AppAIBackendID

    public init(
        _ title: String = "AI Provider",
        selection: Binding<AppAIBackendID>,
        catalog: AppAIBackendCatalog
    ) {
        self.title = title
        self._selection = selection
        self.catalog = catalog
    }

    public var body: some View {
        Picker(title, selection: $selection) {
            ForEach(catalog.backends) { backend in
                if let symbolName = backend.symbolName {
                    Label(backend.title, systemImage: symbolName).tag(backend.id)
                } else {
                    Text(backend.title).tag(backend.id)
                }
            }
        }
    }
}

@MainActor
public struct AppAIBackendStatusRow: View {
    private let descriptor: AppAIBackendDescriptor
    private let isConfigured: Bool
    private let isSelected: Bool
    private let statusText: String?

    public init(
        descriptor: AppAIBackendDescriptor,
        isConfigured: Bool,
        isSelected: Bool = false,
        statusText: String? = nil
    ) {
        self.descriptor = descriptor
        self.isConfigured = isConfigured
        self.isSelected = isSelected
        self.statusText = statusText
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(descriptor.title)
            Spacer(minLength: 12)
            Text(statusText ?? (isConfigured ? "Configured" : "Not Configured"))
                .foregroundStyle(isConfigured ? Color.green : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

@MainActor
public struct AppAIModelField: View {
    private let title: String
    private let placeholder: String
    @Binding private var model: String

    public init(
        _ title: String = "Model",
        model: Binding<String>,
        placeholder: String = "Model ID"
    ) {
        self.title = title
        self._model = model
        self.placeholder = placeholder
    }

    public var body: some View {
        LabeledContent(title) {
            TextField(placeholder, text: $model)
                .multilineTextAlignment(.trailing)
        }
    }
}

@MainActor
public struct AppAIAPIKeyField: View {
    private let title: String
    private let placeholder: String
    private let hasCredential: Bool
    private let save: (String) async throws -> Void
    private let remove: () async throws -> Void

    @State private var value = ""
    @State private var isWorking = false
    @State private var message: String?

    public init(
        _ title: String = "API Key",
        placeholder: String = "Paste API key",
        hasCredential: Bool,
        save: @escaping (String) async throws -> Void,
        remove: @escaping () async throws -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.hasCredential = hasCredential
        self.save = save
        self.remove = remove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(placeholder, text: $value)

            HStack {
                Button(hasCredential ? "Replace Key" : "Save Key") {
                    perform {
                        try await save(value)
                        value = ""
                        message = "Saved"
                    }
                }
                .disabled(
                    isWorking
                        || value.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                )

                if hasCredential {
                    Button("Remove", role: .destructive) {
                        perform {
                            try await remove()
                            message = "Removed"
                        }
                    }
                    .disabled(isWorking)
                }

                if isWorking {
                    ProgressView().controlSize(.small)
                }
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await operation()
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

@MainActor
public struct AppAIConnectionTestButton: View {
    private let title: String
    private let test: () async throws -> Void

    @State private var isTesting = false
    @State private var result: String?

    public init(
        _ title: String = "Test Connection",
        test: @escaping () async throws -> Void
    ) {
        self.title = title
        self.test = test
    }

    public var body: some View {
        HStack {
            Button(title) {
                isTesting = true
                result = nil
                Task {
                    do {
                        try await test()
                        result = "Connected"
                    } catch {
                        result = error.localizedDescription
                    }
                    isTesting = false
                }
            }
            .disabled(isTesting)

            if isTesting {
                ProgressView().controlSize(.small)
            }
            if let result {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A compact form for configuring one direct AI provider.
///
/// The API key and model ID remain directly editable. Apps can optionally
/// provide model browsing while preserving manual entry and paste support.
@MainActor
public struct AppAIDirectProviderConfigurationView: View {
    private enum Activity {
        case saving
        case testing
    }

    private let descriptor: AppAIBackendDescriptor
    @Binding private var apiKey: String
    @Binding private var model: String
    private let canSave: Bool
    private let save: () async throws -> Void
    private let testConnection: () async throws -> Void
    private let browseModels: (() -> Void)?

    @State private var activity: Activity?
    @State private var message: String?
    @State private var messageIsError = false

    public init(
        descriptor: AppAIBackendDescriptor,
        apiKey: Binding<String>,
        model: Binding<String>,
        canSave: Bool,
        save: @escaping () async throws -> Void,
        testConnection: @escaping () async throws -> Void,
        browseModels: (() -> Void)? = nil
    ) {
        self.descriptor = descriptor
        self._apiKey = apiKey
        self._model = model
        self.canSave = canSave
        self.save = save
        self.testConnection = testConnection
        self.browseModels = browseModels
    }

    public var body: some View {
        Form {
            Section("API Key") {
                HStack(spacing: 10) {
                    SecureField(keyPlaceholder, text: $apiKey)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    clearButton(
                        value: $apiKey,
                        accessibilityLabel: "Clear API key"
                    )
                }
            }

            Section("Model ID") {
                HStack(spacing: 10) {
                    TextField("Model ID", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    clearButton(
                        value: $model,
                        accessibilityLabel: "Clear model ID"
                    )

                    if descriptor.capabilities.supportsModelDiscovery,
                       let browseModels {
                        Button("Browse", action: browseModels)
                            .disabled(trimmedAPIKey.isEmpty || isWorking)
                    }
                }
            }

            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Spacer()
                        if activity == .testing {
                            ProgressView()
                            Text("Testing…")
                        } else {
                            Text("Test Connection")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    isWorking
                        || trimmedAPIKey.isEmpty
                        || trimmedModel.isEmpty
                )

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(
                            messageIsError ? Color.red : Color.green
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await saveConfiguration() }
                } label: {
                    if activity == .saving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!canSave || isWorking || trimmedModel.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func clearButton(
        value: Binding<String>,
        accessibilityLabel: String
    ) -> some View {
        if !value.wrappedValue.isEmpty {
            Button {
                value.wrappedValue = ""
                message = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var isWorking: Bool {
        activity != nil
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keyPlaceholder: String {
        guard case .direct(let providerID) = descriptor.id else {
            return "Paste API key"
        }

        switch providerID {
        case .openRouter:
            return "sk-or-v1-..."
        case .openAI:
            return "sk-..."
        case .anthropic:
            return "sk-ant-..."
        case .gemini:
            return "AIza..."
        case .deepSeek:
            return "sk-..."
        case .nvidia:
            return "nvapi-..."
        default:
            return "Paste API key"
        }
    }

    private func saveConfiguration() async {
        activity = .saving
        message = nil
        defer { activity = nil }

        do {
            try await save()
            message = "Saved"
            messageIsError = false
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }

    private func test() async {
        activity = .testing
        message = nil
        defer { activity = nil }

        do {
            try await testConnection()
            message = "Connection successful"
            messageIsError = false
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }
}

@MainActor
public struct AppAIManagedUsageSection: View {
    private let status: AppAIStatus?
    private let isRefreshing: Bool
    private let isStale: Bool
    private let refresh: () -> Void

    public init(
        status: AppAIStatus?,
        isRefreshing: Bool,
        isStale: Bool,
        refresh: @escaping () -> Void
    ) {
        self.status = status
        self.isRefreshing = isRefreshing
        self.isStale = isStale
        self.refresh = refresh
    }

    public var body: some View {
        Section("AI Usage") {
            if let status {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(status.usage.remaining) left")
                                .font(.title2.weight(.semibold))
                            Text(status.plan.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(status.usage.used) of \(status.usage.limit) used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(
                        value: Double(status.usage.used),
                        total: Double(max(1, status.usage.limit))
                    )

                    LabeledContent("Resets") {
                        Text(
                            status.usage.resetsAt,
                            format: .dateTime.year().month().day().hour().minute()
                        )
                    }
                    .font(.subheadline)

                    if isStale {
                        Label(
                            "Showing the last available usage",
                            systemImage: "wifi.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else if isRefreshing {
                HStack {
                    ProgressView()
                    Text("Refreshing usage…")
                }
            } else {
                ContentUnavailableView(
                    "Usage Unavailable",
                    systemImage: "chart.bar.xaxis"
                )
            }

            Button("Refresh Usage", action: refresh)
                .disabled(isRefreshing)
        }
    }
}
#endif
