import Foundation
import Observation

@MainActor
@Observable
public final class AppAIBackendManager {
    public private(set) var selectedBackendID: AppAIBackendID
    public private(set) var models: [AppAIProviderID: String]
    public let catalog: AppAIBackendCatalog

    @ObservationIgnored private let credentialStore: any AppAICredentialStoring
    @ObservationIgnored private let preferences: any AppAIBackendPreferences
    @ObservationIgnored private let clients: [AppAIProviderID: any AppAIDirectProviderClient]

    public init(
        catalog: AppAIBackendCatalog,
        clients: [any AppAIDirectProviderClient],
        credentialStore: any AppAICredentialStoring,
        preferences: any AppAIBackendPreferences,
        selectedBackendID: AppAIBackendID? = nil
    ) {
        self.catalog = catalog
        self.credentialStore = credentialStore
        self.preferences = preferences

        var indexedClients: [AppAIProviderID: any AppAIDirectProviderClient] = [:]
        for client in clients where indexedClients[client.providerID] == nil {
            indexedClients[client.providerID] = client
        }
        self.clients = indexedClients

        var initialModels: [AppAIProviderID: String] = [:]
        for descriptor in catalog.backends {
            guard case .direct(let providerID) = descriptor.id,
                  let preferredModel = descriptor.preferredModel?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !preferredModel.isEmpty else { continue }
            initialModels[providerID] = preferredModel
        }
        self.models = initialModels

        let fallback = catalog.defaultBackendID ?? .managed
        if let selectedBackendID, catalog.contains(selectedBackendID) {
            self.selectedBackendID = selectedBackendID
        } else {
            self.selectedBackendID = fallback
        }
    }

    public func restore() async {
        if let persisted = await preferences.selectedBackend(), catalog.contains(persisted) {
            selectedBackendID = persisted
        }

        for descriptor in catalog.backends {
            guard case .direct(let providerID) = descriptor.id else { continue }
            if let persisted = await preferences.model(for: providerID)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !persisted.isEmpty {
                models[providerID] = persisted
            }
        }
    }

    public func select(_ backend: AppAIBackendID) {
        guard catalog.contains(backend) else { return }
        selectedBackendID = backend
        Task { await preferences.setSelectedBackend(backend) }
    }

    public func selectAndWait(_ backend: AppAIBackendID) async {
        guard catalog.contains(backend) else { return }
        selectedBackendID = backend
        await preferences.setSelectedBackend(backend)
    }

    public func isConfigured(_ backend: AppAIBackendID) async -> Bool {
        guard catalog.contains(backend) else { return false }
        switch backend {
        case .managed:
            return true
        case .direct(let providerID):
            if let client = clients[providerID] {
                return await client.hasCredential()
            }
            return await credentialStore.hasCredential(for: providerID)
        }
    }

    public func saveCredential(_ credential: String, for provider: AppAIProviderID) async throws {
        guard catalog.contains(.direct(provider)) else {
            throw AppAIDirectError.invalidRequest("The provider is not included in this app's AI catalog.")
        }
        if let client = clients[provider] {
            try await client.saveCredential(credential)
        } else {
            try await credentialStore.setCredential(credential, for: provider)
        }
    }

    public func removeCredential(for provider: AppAIProviderID) async throws {
        if let client = clients[provider] {
            try await client.removeCredential()
        } else {
            try await credentialStore.removeCredential(for: provider)
        }
    }

    public func model(for provider: AppAIProviderID) -> String {
        if let model = models[provider], !model.isEmpty { return model }
        return catalog.descriptor(for: provider)?.preferredModel ?? ""
    }

    public func setModel(_ model: String, for provider: AppAIProviderID) {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { models.removeValue(forKey: provider) }
        else { models[provider] = normalized }
        Task { await preferences.setModel(normalized.isEmpty ? nil : normalized, for: provider) }
    }

    public func setModelAndWait(_ model: String, for provider: AppAIProviderID) async {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { models.removeValue(forKey: provider) }
        else { models[provider] = normalized }
        await preferences.setModel(normalized.isEmpty ? nil : normalized, for: provider)
    }

    public func test(provider: AppAIProviderID, model: String? = nil) async throws {
        let client = try directClient(for: provider)
        let resolved = try resolvedModel(model, provider: provider)
        try await client.testConnection(model: resolved)
    }

    public func availableModels(for provider: AppAIProviderID) async throws -> [AppAIModel] {
        try await directClient(for: provider).availableModels()
    }

    public func directClient(for provider: AppAIProviderID) throws -> any AppAIDirectProviderClient {
        guard catalog.contains(.direct(provider)) else {
            throw AppAIDirectError.invalidRequest("The provider is not included in this app's AI catalog.")
        }
        guard let client = clients[provider] else {
            throw AppAIDirectError.invalidRequest("No direct client is registered for \(provider.rawValue).")
        }
        return client
    }

    private func resolvedModel(_ candidate: String?, provider: AppAIProviderID) throws -> String {
        let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? model(for: provider)
        guard !value.isEmpty else { throw AppAIDirectError.invalidModel }
        return value
    }
}
