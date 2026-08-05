import Foundation
import Observation

@MainActor
@Observable
public final class AppAIBackendManager {
    private enum PreferenceWrite: Sendable {
        case selectedBackend(AppAIBackendID)
        case model(AppAIProviderID, String?)
    }

    public private(set) var selectedBackendID: AppAIBackendID
    public private(set) var models: [AppAIProviderID: String]
    public let catalog: AppAIBackendCatalog
    public let managedBackend: AppAIManagedBackend?

    @ObservationIgnored private let credentialStore: any AppAICredentialStoring
    @ObservationIgnored private let preferences: any AppAIBackendPreferences
    @ObservationIgnored private let clients: [
        AppAIProviderID: any AppAIDirectProviderClient
    ]
    @ObservationIgnored private var preferenceWriteTask: Task<Void, Never>?

    public init(
        catalog: AppAIBackendCatalog,
        managedBackend: AppAIManagedBackend? = nil,
        clients: [any AppAIDirectProviderClient],
        credentialStore: any AppAICredentialStoring,
        preferences: any AppAIBackendPreferences,
        selectedBackendID: AppAIBackendID? = nil
    ) {
        let registeredCatalog = Self.catalog(
            catalog,
            registering: managedBackend
        )

        self.catalog = registeredCatalog
        self.managedBackend = managedBackend
        self.credentialStore = credentialStore
        self.preferences = preferences

        var indexedClients: [
            AppAIProviderID: any AppAIDirectProviderClient
        ] = [:]
        for client in clients where indexedClients[client.providerID] == nil {
            indexedClients[client.providerID] = client
        }
        self.clients = indexedClients

        var initialModels: [AppAIProviderID: String] = [:]
        for descriptor in registeredCatalog.backends {
            guard case .direct(let providerID) = descriptor.id,
                  let preferredModel = descriptor.preferredModel?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !preferredModel.isEmpty else {
                continue
            }
            initialModels[providerID] = preferredModel
        }
        self.models = initialModels

        let fallback = registeredCatalog.defaultBackendID ?? .managed
        if let selectedBackendID,
           registeredCatalog.contains(selectedBackendID) {
            self.selectedBackendID = selectedBackendID
        } else {
            self.selectedBackendID = fallback
        }
    }

    public var managedClient: AppAIClient? {
        managedBackend?.client
    }

    public var managedStatusStore: AppAIStatusStore? {
        managedBackend?.statusStore
    }

    public func restore() async {
        await preferenceWriteTask?.value

        if let persisted = await preferences.selectedBackend(),
           catalog.contains(persisted) {
            selectedBackendID = persisted
        }

        for descriptor in catalog.backends {
            guard case .direct(let providerID) = descriptor.id else {
                continue
            }
            if let persisted = await preferences.model(for: providerID)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !persisted.isEmpty {
                models[providerID] = persisted
            }
        }
    }

    public func select(_ backend: AppAIBackendID) {
        guard catalog.contains(backend) else { return }
        selectedBackendID = backend
        enqueuePreferenceWrite(.selectedBackend(backend))
    }

    public func selectAndWait(_ backend: AppAIBackendID) async {
        guard catalog.contains(backend) else { return }
        selectedBackendID = backend
        let task = enqueuePreferenceWrite(.selectedBackend(backend))
        await task.value
    }

    public func isConfigured(_ backend: AppAIBackendID) async -> Bool {
        guard catalog.contains(backend) else { return false }

        switch backend {
        case .managed:
            return managedBackend != nil

        case .direct(let providerID):
            guard let client = clients[providerID] else { return false }
            return await client.hasCredential()
        }
    }

    public func requireManagedClient() throws -> AppAIClient {
        guard let managedClient else {
            throw AppAIError.invalidConfiguration(
                "Managed AI is not registered for this app."
            )
        }
        return managedClient
    }

    public func credential(
        for provider: AppAIProviderID
    ) async throws -> String? {
        _ = try directClient(for: provider)
        return try await credentialStore.credential(for: provider)
    }

    public func saveCredential(
        _ credential: String,
        for provider: AppAIProviderID
    ) async throws {
        let client = try directClient(for: provider)
        try await client.saveCredential(credential)
    }

    public func removeCredential(
        for provider: AppAIProviderID
    ) async throws {
        let client = try directClient(for: provider)
        try await client.removeCredential()
    }

    public func model(for provider: AppAIProviderID) -> String {
        if let model = models[provider], !model.isEmpty {
            return model
        }
        return catalog.descriptor(for: provider)?.preferredModel ?? ""
    }

    public func setModel(
        _ model: String,
        for provider: AppAIProviderID
    ) {
        let normalized = model.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if normalized.isEmpty {
            models.removeValue(forKey: provider)
        } else {
            models[provider] = normalized
        }
        enqueuePreferenceWrite(
            .model(
                provider,
                normalized.isEmpty ? nil : normalized
            )
        )
    }

    public func setModelAndWait(
        _ model: String,
        for provider: AppAIProviderID
    ) async {
        let normalized = model.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if normalized.isEmpty {
            models.removeValue(forKey: provider)
        } else {
            models[provider] = normalized
        }
        let task = enqueuePreferenceWrite(
            .model(
                provider,
                normalized.isEmpty ? nil : normalized
            )
        )
        await task.value
    }

    public func test(
        provider: AppAIProviderID,
        model: String? = nil
    ) async throws {
        let client = try directClient(for: provider)
        let resolved = try resolvedModel(model, provider: provider)
        try await client.testConnection(model: resolved)
    }

    public func test(
        provider: AppAIProviderID,
        credential: String,
        model: String
    ) async throws {
        let client = try directClient(for: provider)
        let resolved = try resolvedModel(model, provider: provider)
        try await withTemporaryCredential(
            credential,
            for: provider
        ) {
            try await client.testConnection(model: resolved)
        }
    }

    public func availableModels(
        for provider: AppAIProviderID
    ) async throws -> [AppAIModel] {
        try await directClient(for: provider).availableModels()
    }

    public func availableModels(
        for provider: AppAIProviderID,
        credential: String
    ) async throws -> [AppAIModel] {
        let client = try directClient(for: provider)
        return try await withTemporaryCredential(
            credential,
            for: provider
        ) {
            try await client.availableModels()
        }
    }

    public func directClient(
        for provider: AppAIProviderID
    ) throws -> any AppAIDirectProviderClient {
        guard catalog.contains(.direct(provider)) else {
            throw AppAIDirectError.invalidRequest(
                "The provider is not included in this app's AI catalog."
            )
        }
        guard let client = clients[provider] else {
            throw AppAIDirectError.invalidRequest(
                "No direct client is registered for \(provider.rawValue)."
            )
        }
        return client
    }

    @discardableResult
    private func enqueuePreferenceWrite(
        _ write: PreferenceWrite
    ) -> Task<Void, Never> {
        let previousTask = preferenceWriteTask
        let preferences = self.preferences
        let task = Task {
            await previousTask?.value

            switch write {
            case .selectedBackend(let backend):
                await preferences.setSelectedBackend(backend)
            case .model(let provider, let model):
                await preferences.setModel(model, for: provider)
            }
        }
        preferenceWriteTask = task
        return task
    }

    private func resolvedModel(
        _ candidate: String?,
        provider: AppAIProviderID
    ) throws -> String {
        let value = candidate?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? model(for: provider)
        guard !value.isEmpty else {
            throw AppAIDirectError.invalidModel
        }
        return value
    }

    private func withTemporaryCredential<Value>(
        _ credential: String,
        for provider: AppAIProviderID,
        operation: () async throws -> Value
    ) async throws -> Value {
        let normalized = credential.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else {
            throw AppAIDirectError.missingCredential(provider)
        }

        let original = try await credentialStore.credential(for: provider)
        if original == normalized {
            return try await operation()
        }

        try await credentialStore.setCredential(normalized, for: provider)
        do {
            let value = try await operation()
            try await restoreCredential(original, for: provider)
            return value
        } catch {
            let operationError = error
            try? await restoreCredential(original, for: provider)
            throw operationError
        }
    }

    private func restoreCredential(
        _ credential: String?,
        for provider: AppAIProviderID
    ) async throws {
        if let credential, !credential.isEmpty {
            try await credentialStore.setCredential(
                credential,
                for: provider
            )
        } else {
            try await credentialStore.removeCredential(for: provider)
        }
    }

    private static func catalog(
        _ catalog: AppAIBackendCatalog,
        registering managedBackend: AppAIManagedBackend?
    ) -> AppAIBackendCatalog {
        guard let managedBackend else { return catalog }

        var descriptors = catalog.backends
        if let index = descriptors.firstIndex(where: { $0.id == .managed }) {
            descriptors[index] = managedBackend.descriptor
        } else {
            descriptors.insert(managedBackend.descriptor, at: 0)
        }
        return AppAIBackendCatalog(backends: descriptors)
    }
}
