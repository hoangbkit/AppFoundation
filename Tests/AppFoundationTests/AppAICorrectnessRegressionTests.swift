import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor RegressionTransport: AppAITransport {
    typealias Handler = @Sendable (
        URLRequest,
        Int
    ) async throws -> (Data, HTTPURLResponse)

    private var requests: [URLRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try await handler(request, requests.count)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

private actor ControlledStatusClient: AppAIStatusServing {
    private var nextCallID = 0
    private var continuations: [
        Int: CheckedContinuation<AppAIStatus, Never>
    ] = [:]

    func status() async throws -> AppAIStatus {
        await nextStatus()
    }

    func syncCurrentEntitlements() async throws -> AppAIStatus {
        await nextStatus()
    }

    func callCount() -> Int {
        nextCallID
    }

    func resume(
        callID: Int,
        with status: AppAIStatus
    ) {
        continuations.removeValue(forKey: callID)?.resume(
            returning: status
        )
    }

    private func nextStatus() async -> AppAIStatus {
        nextCallID += 1
        let callID = nextCallID
        return await withCheckedContinuation { continuation in
            continuations[callID] = continuation
        }
    }
}

@Test @MainActor
func directBackendRequiresRegisteredClientToBeReady() async {
    let credentialStore = AppAIInMemoryCredentialStore(
        credentials: [.openAI: "orphaned-key"]
    )
    let manager = AppAIBackendManager(
        catalog: AppAIBackendCatalog(
            backends: [
                .openAI(preferredModel: "model-a"),
            ]
        ),
        clients: [],
        credentialStore: credentialStore,
        preferences: AppAIInMemoryBackendPreferences()
    )

    #expect(!(await manager.isConfigured(.direct(.openAI))))

    do {
        try await manager.saveCredential("new-key", for: .openAI)
        Issue.record("Expected a missing direct client error")
    } catch let error as AppAIDirectError {
        #expect(
            error
                == .invalidRequest(
                    "No direct client is registered for openai."
                )
        )
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func GeminiModelDiscoveryPaginatesAndFiltersUnsupportedModels() async throws {
    let credentials = AppAIInMemoryCredentialStore(
        credentials: [.gemini: "gemini-key"]
    )
    let transport = RegressionTransport { request, call in
        let components = try #require(
            URLComponents(
                url: try #require(request.url),
                resolvingAgainstBaseURL: false
            )
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            }
        )
        #expect(query["pageSize"] == "1000")
        #expect(
            request.value(forHTTPHeaderField: "x-goog-api-key")
                == "gemini-key"
        )

        let body: String
        if call == 1 {
            #expect(query["pageToken"] == nil)
            body = #"{
                "models": [
                    {
                        "name": "models/gemini-a",
                        "displayName": "Gemini A",
                        "inputTokenLimit": 1000,
                        "supportedGenerationMethods": ["generateContent"]
                    },
                    {
                        "name": "models/embedding-a",
                        "displayName": "Embedding A",
                        "supportedGenerationMethods": ["embedContent"]
                    }
                ],
                "nextPageToken": "next-page"
            }"#
        } else {
            #expect(query["pageToken"] == "next-page")
            body = #"{
                "models": [
                    {
                        "name": "models/gemini-b",
                        "displayName": "Gemini B",
                        "inputTokenLimit": 2000,
                        "supportedGenerationMethods": ["generateContent"]
                    }
                ]
            }"#
        }

        return (
            Data(body.utf8),
            HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
    let client = GeminiGenerateContentClient(
        credentialStore: credentials,
        transport: transport,
        baseURL: URL(string: "https://example.com/v1beta")!
    )

    let models = try await client.availableModels()

    #expect(models.map(\.id) == ["gemini-a", "gemini-b"])
    #expect(models.map(\.displayName) == ["Gemini A", "Gemini B"])
    #expect(await transport.capturedRequests().count == 2)
}

@Test @MainActor
func cancelledStatusRefreshCannotClobberNewerRefresh() async {
    let client = ControlledStatusClient()
    let store = AppAIStatusStore(client: client)

    store.refresh(syncEntitlements: false)
    await waitForCallCount(1, client: client)

    store.cancelRefresh()
    store.refresh(syncEntitlements: false)
    await waitForCallCount(2, client: client)

    await client.resume(
        callID: 1,
        with: makeStatus(id: "old", remaining: 1)
    )
    await Task.yield()
    #expect(store.isRefreshing)

    let waiter = Task { @MainActor in
        await store.refreshAndWait(syncEntitlements: false)
    }
    await client.resume(
        callID: 2,
        with: makeStatus(id: "new", remaining: 9)
    )
    await waiter.value

    #expect(store.status?.app.id == "new")
    #expect(store.usage?.remaining == 9)
    #expect(!store.isRefreshing)
}

private func waitForCallCount(
    _ expected: Int,
    client: ControlledStatusClient
) async {
    for _ in 0..<1_000 {
        if await client.callCount() >= expected {
            return
        }
        await Task.yield()
    }
    Issue.record("Timed out waiting for status call \(expected)")
}

private func makeStatus(
    id: String,
    remaining: Int
) -> AppAIStatus {
    AppAIStatus(
        app: .init(id: id, displayName: id),
        enabled: true,
        plan: "free",
        entitlement: nil,
        attestation: .init(mode: "preferred", status: "verified"),
        usage: .init(
            limit: 10,
            used: 10 - remaining,
            remaining: remaining,
            resetsAt: .now
        )
    )
}
