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

/// A focused setup surface for a direct BYOK provider.
///
/// The view intentionally keeps advanced provider information out of the main
/// flow. It shows the current connection state, reveals the API-key editor only
/// when needed, persists model changes through the supplied binding, and gives
/// connection testing one clear primary action.
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
    @State private var isEditingCredential: Bool
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
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
        self._isEditingCredential = State(initialValue: !hasCredential)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            providerSummary

            Divider()
                .padding(.vertical, 16)

            credentialSection

            Divider()
                .padding(.vertical, 16)

            modelSection

            Divider()
                .padding(.vertical, 16)

            connectionSection
        }
        .onChange(of: hasCredential) { _, newValue in
            hasSavedKey = newValue
            isEditingCredential = !newValue
        }
        .confirmationDialog(
            "Remove \(descriptor.title) API key?",
            isPresented: $isShowingRemoveConfirmation
        ) {
            Button("Remove API Key", role: .destructive) {
                Task { await removeKey() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Requests through this provider will stop working until a new key is saved.")
        }
    }

    private var providerSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        hasSavedKey
                            ? Color.green.opacity(0.14)
                            : Color.secondary.opacity(0.12)
                    )

                Image(systemName: descriptor.symbolName ?? "sparkles")
                    .font(.headline)
                    .foregroundStyle(hasSavedKey ? Color.green : Color.secondary)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.title)
                    .font(.headline)

                Text(hasSavedKey ? "Ready to use" : "Add an API key to connect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(hasSavedKey ? "Configured" : "Not Configured")
                .font(.caption.weight(.semibold))
                .foregroundStyle(hasSavedKey ? Color.green : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    (hasSavedKey ? Color.green : Color.secondary).opacity(0.12),
                    in: Capsule()
                )
        }
    }

    @ViewBuilder
    private var credentialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("API Key", systemImage: "key.fill")
                    .font(.headline)

                Spacer()

                if hasSavedKey && !isEditingCredential {
                    Button("Replace") {
                        apiKey = ""
                        statusMessage = nil
                        isEditingCredential = true
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if hasSavedKey && !isEditingCredential {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved securely")
                            .font(.subheadline.weight(.semibold))
                        Text("Stored in Keychain on this device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Remove API Key", role: .destructive) {
                    isShowingRemoveConfirmation = true
                }
                .font(.subheadline)
                .disabled(isWorking)
            } else {
                SecureField(
                    hasSavedKey ? "Paste replacement key" : keyPlaceholder,
                    text: $apiKey
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                HStack(spacing: 10) {
                    Button(hasSavedKey ? "Save Replacement" : "Save API Key") {
                        Task { await saveKey() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedAPIKey.isEmpty || isWorking)

                    if hasSavedKey {
                        Button("Cancel") {
                            apiKey = ""
                            statusMessage = nil
                            isEditingCredential = false
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Model", systemImage: "cube.fill")
                .font(.headline)

            TextField("Model ID", text: $model)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(alignment: .firstTextBaseline) {
                Text("Used automatically for new requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let preferredModel = normalizedPreferredModel,
                   model.trimmingCharacters(in: .whitespacesAndNewlines) != preferredModel {
                    Button("Use Default") {
                        model = preferredModel
                        statusMessage = nil
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await runConnectionTest() }
            } label: {
                HStack {
                    Spacer()
                    if isWorking {
                        ProgressView()
                        Text("Testing…")
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                        Text("Test Connection")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                isWorking
                    || !hasSavedKey
                    || model.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
            )

            if let statusMessage {
                Label(
                    statusMessage,
                    systemImage: statusIsError
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(statusIsError ? Color.red : Color.green)
                .fixedSize(horizontal: false, vertical: true)
            } else if !hasSavedKey {
                Text("Save an API key before testing the connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Label(
                "Your key stays in Keychain and is sent only to \(descriptor.title).",
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPreferredModel: String? {
        guard let preferredModel = descriptor.preferredModel?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !preferredModel.isEmpty else {
            return nil
        }
        return preferredModel
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
            try await saveCredential(trimmedAPIKey)
            apiKey = ""
            hasSavedKey = true
            isEditingCredential = false
            statusMessage = "API key saved"
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func removeKey() async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await removeCredential()
            apiKey = ""
            hasSavedKey = false
            isEditingCredential = true
            statusMessage = "API key removed"
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
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
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
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
