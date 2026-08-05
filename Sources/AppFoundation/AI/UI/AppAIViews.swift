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

@MainActor
public struct AppAIDirectProviderConfigurationView: View {
    private let descriptor: AppAIBackendDescriptor
    @Binding private var model: String
    private let hasCredential: Bool
    private let saveCredential: (String) async throws -> Void
    private let removeCredential: () async throws -> Void
    private let testConnection: (String) async throws -> Void

    @State private var apiKey = ""
    @State private var hasSavedKey: Bool
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var isShowingRemoveConfirmation = false

    public init(
        descriptor: AppAIBackendDescriptor,
        model: Binding<String>,
        hasCredential: Bool,
        saveCredential: @escaping (String) async throws -> Void,
        removeCredential: @escaping () async throws -> Void,
        testConnection: @escaping (String) async throws -> Void
    ) {
        self.descriptor = descriptor
        self._model = model
        self.hasCredential = hasCredential
        self.saveCredential = saveCredential
        self.removeCredential = removeCredential
        self.testConnection = testConnection
        self._hasSavedKey = State(initialValue: hasCredential)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppAIBackendStatusRow(
                descriptor: descriptor,
                isConfigured: hasSavedKey
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("API Key")
                    .font(.headline)

                SecureField(
                    hasSavedKey
                        ? "Saved key — enter to replace"
                        : keyPlaceholder,
                    text: $apiKey
                )
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button(hasSavedKey ? "Replace API Key" : "Save API Key") {
                    Task { await saveKey() }
                }
                .disabled(
                    apiKey.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isWorking
                )

                if hasSavedKey {
                    Label(
                        "Key saved securely on this device",
                        systemImage: "checkmark.shield.fill"
                    )
                    .foregroundStyle(.green)

                    Button("Remove API Key", role: .destructive) {
                        isShowingRemoveConfirmation = true
                    }
                    .disabled(isWorking)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Model")
                    .font(.headline)

                TextField("Model ID", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save Model") {
                    model = model.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    statusMessage = "Model saved"
                }
                .disabled(
                    model.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isWorking
                )

                if let preferredModel = descriptor.preferredModel {
                    Text(
                        "Default: \(preferredModel). Enter any model ID available to your account."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Task { await runConnectionTest() }
                } label: {
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text("Testing \(descriptor.title)")
                        }
                    } else {
                        Label(
                            "Test Key and Model",
                            systemImage: "bolt.horizontal.circle"
                        )
                    }
                }
                .disabled(
                    isWorking
                        || !hasSavedKey
                        || model.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                )

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(
                            statusMessage == "Connection successful"
                                ? Color.green
                                : Color.secondary
                        )
                }
            }
        }
        .onChange(of: hasCredential) { _, newValue in
            hasSavedKey = newValue
        }
        .confirmationDialog(
            "Remove \(descriptor.title) API key?",
            isPresented: $isShowingRemoveConfirmation
        ) {
            Button("Remove API Key", role: .destructive) {
                Task { await removeKey() }
            }
            Button("Cancel", role: .cancel) {}
        }
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

    private func saveKey() async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await saveCredential(apiKey)
            apiKey = ""
            hasSavedKey = true
            statusMessage = "API key saved"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func removeKey() async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await removeCredential()
            hasSavedKey = false
            statusMessage = "API key removed"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runConnectionTest() async {
        model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await testConnection(model)
            statusMessage = "Connection successful"
        } catch {
            statusMessage = error.localizedDescription
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
                LabeledContent("Plan", value: status.plan.capitalized)
                LabeledContent(
                    "Used",
                    value: "\(status.usage.used) of \(status.usage.limit)"
                )
                LabeledContent(
                    "Remaining",
                    value: "\(status.usage.remaining)"
                )
                LabeledContent("Resets") {
                    Text(
                        status.usage.resetsAt,
                        format: .dateTime.year().month().day().hour().minute()
                    )
                }
                if isStale {
                    Label(
                        "Showing the last available usage",
                        systemImage: "wifi.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if isRefreshing {
                HStack {
                    ProgressView()
                    Text("Refreshing usage…")
                }
            } else {
                LabeledContent("Usage", value: "Unavailable")
            }
            Button("Refresh Usage", action: refresh)
                .disabled(isRefreshing)
        }
    }
}
#endif
