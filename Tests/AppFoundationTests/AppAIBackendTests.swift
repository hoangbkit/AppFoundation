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
        .openAI(preferredModel: "default-model"),
    ])
    let manager = AppAIBackendManager(
        catalog: catalog,
        clients: [
            MockDirectClient(providerID: .openAI, store: store),
        ],
        credentialStore: store,
        preferences: preferences
    )

    await manager.restore()

    #expect(manager.selectedBackendID == .direct(.openAI))
    #expect(manager.model(for: .openAI) == "persisted-model")
    #expect(await manager.isConfigured(.direct(.openAI)))
    #expect(!(await manager.isConfigured(.managed)))
    #expect(manager.managedClient == nil)
}

@Test @MainActor
func backendManagerTestsDraftCredentialWithoutSavingIt() async throws {
    let store = AppAIInMemoryCredentialStore(
        credentials: [.openAI: "saved-key"]
    )
    let client = MockDirectClient(providerID: .openAI, store: store)
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(backends: [
            .openAI(preferredModel: "model-a"),
        ]),
        clients: [client],
        credentialStore: store,
        preferences: AppAIInMemoryBackendPreferences()
    )

    try await manager.test(
        provider: .openAI,
        credential: "draft-key",
        model: "model-a"
    )

    #expect(await client.testedCredential() == "draft-key")
    #expect(try await store.credential(for: .openAI) == "saved-key")
}

@Test @MainActor
func managedBackendRegistrationExposesClientAndConfiguration() async throws {
    let credentialStore = AppAIInMemoryCredentialStore()
    let preferences = AppAIInMemoryBackendPreferences()
    let client = AppAIClient(
        configuration: AppAIClientConfiguration(
            appID: "test-app",
            appKey: "test-app-key-123456789",
            baseURL: URL(string: "https://example.com")!,
            attestationPolicy: .disabled,
            keychainService: "com.hoangbkit.AppFoundationTests.managed"
        )
    )
    let managedBackend = AppAIManagedBackend(
        descriptor: .managed(
            title: "Registered App AI",
            subtitle: "Managed by the test app"
        ),
        client: client
    )
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(backends: [
            .managed(title: "Placeholder Managed AI"),
            .openAI(preferredModel: "model-a"),
        ]),
        managedBackend: managedBackend,
        clients: [],
        credentialStore: credentialStore,
        preferences: preferences
    )

    #expect(await manager.isConfigured(.managed))
    #expect(manager.managedClient != nil)
    #expect(manager.managedStatusStore == nil)
    #expect(
        manager.catalog.descriptor(for: .managed)?.title
            == "Registered App AI"
    )
    _ = try manager.requireManagedClient()
}

@Test @MainActor
func missingManagedBackendThrowsConfigurationError() async {
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(backends: [
            .managed(title: "Managed AI"),
        ]),
        clients: [],
        credentialStore: AppAIInMemoryCredentialStore(),
        preferences: AppAIInMemoryBackendPreferences()
    )

    do {
        _ = try manager.requireManagedClient()
        Issue.record("Expected missing managed backend error")
    } catch let error as AppAIError {
        #expect(
            error
                == .invalidConfiguration(
                    "Managed AI is not registered for this app."
                )
        )
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

private actor MockStatusClient: AppAIStatusServing {
    private var statusCalls = 0
    private let value: AppAIStatus

    init(value: AppAIStatus) {
        self.value = value
    }

    func status() async throws -> AppAIStatus {
        statusCalls += 1
        return value
    }

    func syncCurrentEntitlements() async throws -> AppAIStatus {
        statusCalls += 1
        return value
    }

    func calls() -> Int {
        statusCalls
    }
}

@Test @MainActor
func statusStorePublishesCurrentStatus() async throws {
    let value = AppAIStatus(
        app: .init(id: "test", displayName: "Test"),
        enabled: true,
        plan: "free",
        entitlement: nil,
        attestation: .init(
            mode: "preferred",
            status: "verified"
        ),
        usage: .init(
            limit: 10,
            used: 2,
            remaining: 8,
            resetsAt: .now
        )
    )
    let client = MockStatusClient(value: value)
    let store = AppAIStatusStore(client: client)

    await store.refreshAndWait(syncEntitlements: true)

    #expect(store.status?.plan == "free")
    #expect(store.usage?.remaining == 8)
    #expect(await client.calls() == 1)
}
