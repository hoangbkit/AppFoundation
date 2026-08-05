import Foundation
import Testing
@testable import AppFoundation

private actor MockDirectClient: AppAIDirectProviderClient {
    nonisolated let providerID: AppAIProviderID
    private let store: any AppAICredentialStoring
    private var lastTestCredential: String?

    init(
        providerID: AppAIProviderID,
        store: any AppAICredentialStoring
    ) {
        self.providerID = providerID
        self.store = store
    }

    func hasCredential() async -> Bool {
        await store.hasCredential(for: providerID)
    }

    func saveCredential(_ value: String) async throws {
        try await store.setCredential(value, for: providerID)
    }

    func removeCredential() async throws {
        try await store.removeCredential(for: providerID)
    }

    func testConnection(model: String) async throws {
        if model.isEmpty {
            throw AppAIDirectError.invalidModel
        }
        lastTestCredential = try await store.credential(for: providerID)
    }

    func generate(
        _ request: AppAIDirectRequest
    ) async throws -> AppAIDirectResponse {
        .init(
            text: "ok",
            providerID: providerID,
            modelID: request.model
        )
    }

    func availableModels() async throws -> [AppAIModel] {
        [.init(id: "model-a")]
    }

    func testedCredential() -> String? {
        lastTestCredential
    }
}

@Test @MainActor
func backendManagerRestoresSelectionAndModels() async throws {
    let store = AppAIInMemoryCredentialStore(
        credentials: [.openAI: "key"]
    )
    let preferences = AppAIInMemoryBackendPreferences(
        selectedBackend: .direct(.openAI),
        models: [.openAI: "persisted-model"]
    )
    let catalog = AppAIBackendCatalog(backends: [
        .managed(title: "App AI"),
        .openAI(preferredModel: "default-model")
    ])
    let manager = AppAIBackendManager(
        catalog: catalog,
        clients: [
            MockDirectClient(providerID: .openAI, store: store)
        ],
        credentialStore: store,
        preferences: preferences
    )

    await manager.restore()

    #expect(manager.selectedBackendID == .direct(.openAI))
    #expect(manager.model(for: .openAI) == "persisted-model")
    #expect(await manager.isConfigured(.direct(.openAI)))
}

@Test @MainActor
func backendManagerUsesPreferredModelWhenNoModelIsSaved() async throws {
    let store = AppAIInMemoryCredentialStore()
    let catalog = AppAIBackendCatalog(backends: [
        .openAI(preferredModel: "preferred-model")
    ])
    let manager = AppAIBackendManager(
        catalog: catalog,
        clients: [
            MockDirectClient(providerID: .openAI, store: store)
        ],
        credentialStore: store,
        preferences: AppAIInMemoryBackendPreferences()
    )

    #expect(manager.model(for: .openAI) == "preferred-model")
}

@Test @MainActor
func backendManagerTestsDraftCredentialAndRestoresSavedCredential() async throws {
    let store = AppAIInMemoryCredentialStore(
        credentials: [.openAI: "saved-key"]
    )
    let client = MockDirectClient(providerID: .openAI, store: store)
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(backends: [.openAI()]),
        clients: [client],
        credentialStore: store,
        preferences: AppAIInMemoryBackendPreferences()
    )

    try await manager.test(
        provider: .openAI,
        credential: "draft-key",
        model: "gpt-test"
    )

    #expect(await client.testedCredential() == "draft-key")
    #expect(try await store.credential(for: .openAI) == "saved-key")
}

@Test @MainActor
func backendManagerTestsDraftCredentialAndRemovesTemporaryCredential() async throws {
    let store = AppAIInMemoryCredentialStore()
    let client = MockDirectClient(providerID: .openAI, store: store)
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(backends: [.openAI()]),
        clients: [client],
        credentialStore: store,
        preferences: AppAIInMemoryBackendPreferences()
    )

    try await manager.test(
        provider: .openAI,
        credential: "draft-key",
        model: "gpt-test"
    )

    #expect(await client.testedCredential() == "draft-key")
    #expect(try await store.credential(for: .openAI) == nil)
}
