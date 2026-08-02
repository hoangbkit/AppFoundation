import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor MockTransport: AppAITransport {
    var requests: [URLRequest] = []
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try handler(request)
    }

    func count() -> Int { requests.count }
    func capturedRequests() -> [URLRequest] { requests }
}

private actor MockAttestation: AppAIAttestationProviding {
    private(set) var resets = 0
    private(set) var headerCalls = 0
    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        headerCalls += 1
        return [
            "X-App-Attest-Key-ID": "test-key",
            "X-Test-Request-ID": request.requestID,
            "X-Test-Assertion": String(headerCalls),
        ]
    }
    func resetKey() async throws { resets += 1 }
    func calls() -> Int { headerCalls }
}

private struct Input: Codable, Sendable { let text: String }
private struct Output: Codable, Sendable, Equatable { let text: String }

private func makeConfiguration(appID: String = "draftx", baseURL: URL = URL(string: "https://example.com")!) -> AppAIClientConfiguration {
    AppAIClientConfiguration(
        appID: appID,
        appKey: "test-key-123456789",
        baseURL: baseURL,
        keychainService: "com.hoangbkit.AppFoundationTests.\(UUID().uuidString)"
    )
}

@Test func generateUsesStableRequestIDAndAttestationHeaders() async throws {
    let transport = MockTransport { request in
        #expect(request.value(forHTTPHeaderField: "X-App-ID") == "draftx")
        #expect(request.value(forHTTPHeaderField: "X-App-Attest-Key-ID") == "test-key")
        #expect(request.value(forHTTPHeaderField: "X-Test-Request-ID") == "request-123456")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (#"{"requestId":"request-123456","capability":"rewrite.polish","data":{"text":"Done"},"attestation":"verified","usage":{"limit":10,"used":1,"remaining":9,"resetsAt":"2026-09-01T00:00:00Z"}}"#.data(using: .utf8)!, response)
    }
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: MockAttestation()
    )
    let result: AppAIResponse<Output> = try await client.generate(capability: "rewrite.polish", input: Input(text: "Hello"), requestID: "request-123456")
    #expect(result.data == Output(text: "Done"))
    #expect(await transport.count() == 1)
    try await client.resetInstallationIdentity()
}

@Test func transportRetryReusesTheSameEncodedRequest() async throws {
    actor State { var calls = 0; func next() -> Int { calls += 1; return calls } }
    let state = State()
    let transport = MockTransport { request in
        let call = awaitSync { await state.next() }
        if call == 1 { throw URLError(.networkConnectionLost) }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (#"{"requestId":"request-654321","capability":"rewrite.polish","data":{"text":"Done"}}"#.data(using: .utf8)!, response)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: attestation
    )
    let _: AppAIResponse<Output> = try await client.generate(capability: "rewrite.polish", input: Input(text: "Hello"), requestID: "request-654321")
    #expect(await transport.count() == 2)
    #expect(await attestation.calls() == 2)
    try await client.resetInstallationIdentity()
}

private func awaitSync<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var value: T?
    Task { value = await operation(); semaphore.signal() }
    semaphore.wait()
    return value!
}

@Test func unknownServerKeyIsResetAndRegisteredAgainOnce() async throws {
    actor State { var calls = 0; func next() -> Int { calls += 1; return calls } }
    let state = State()
    let transport = MockTransport { request in
        let call = awaitSync { await state.next() }
        if call == 1 {
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (#"{"error":{"code":"attestation_key_not_registered","message":"Unknown key","requestId":"server"}}"#.data(using: .utf8)!, response)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (#"{"requestId":"request-key-reset","capability":"rewrite.polish","data":{"text":"Done"}}"#.data(using: .utf8)!, response)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: attestation
    )
    let _: AppAIResponse<Output> = try await client.generate(capability: "rewrite.polish", input: Input(text: "Hello"), requestID: "request-key-reset")
    #expect(await transport.count() == 2)
    #expect(await attestation.resets == 1)
    #expect(await attestation.calls() == 2)
    try await client.resetInstallationIdentity()
}

@Test func entitlementSyncUsesProtectedStableRequest() async throws {
    let transport = MockTransport { request in
        #expect(request.url?.path == "/v1/entitlements/sync")
        #expect(request.value(forHTTPHeaderField: "X-App-Attest-Key-ID") == "test-key")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["requestId"] as? String == "sync-request-123")
        #expect((json["transactions"] as? [String]) == ["signed-transaction"])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (#"{"requestId":"sync-request-123","synced":1,"access":{"plan":"paid","quotaLimit":250,"productId":"pro.yearly","productType":"auto_renewable","status":"active","expiresAt":"2026-09-01T00:00:00Z"}}"#.data(using: .utf8)!, response)
    }
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: MockAttestation()
    )
    let result = try await client.syncEntitlements(transactions: ["signed-transaction"], requestID: "sync-request-123")
    #expect(result.access.plan == "paid")
    #expect(result.access.quotaLimit == 250)
    try await client.resetInstallationIdentity()
}

@Test func resetInstallationIdentityUsesANewInstallationID() async throws {
    let transport = MockTransport { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (#"{"requestId":"reset-test","capability":"rewrite.polish","data":{"text":"Done"}}"#.data(using: .utf8)!, response)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(appID: "reset-test"),
        transport: transport,
        attestationProvider: attestation
    )

    let _: AppAIResponse<Output> = try await client.generate(capability: "rewrite.polish", input: Input(text: "Before"))
    try await client.resetInstallationIdentity()
    let _: AppAIResponse<Output> = try await client.generate(capability: "rewrite.polish", input: Input(text: "After"))

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(requests[0].value(forHTTPHeaderField: "X-Installation-ID") != requests[1].value(forHTTPHeaderField: "X-Installation-ID"))
    #expect(await attestation.resets == 1)
    #expect(await attestation.calls() == 2)
    try await client.resetInstallationIdentity()
}

@Test func endpointURLNormalizesLeadingAndTrailingSlashes() {
    let root = AppAIClient.endpointURL(baseURL: URL(string: "https://example.com/")!, path: "/v1/status")
    let nested = AppAIClient.endpointURL(baseURL: URL(string: "https://example.com/api/")!, path: "/v1/status")

    #expect(root.absoluteString == "https://example.com/v1/status")
    #expect(nested.absoluteString == "https://example.com/api/v1/status")
}

@Test func entitlementBatchesRespectServerLimit() {
    let transactions = (0..<45).map { "transaction-\($0)" }
    let batches = AppAIClient.entitlementBatches(transactions)

    #expect(batches.map(\.count) == [20, 20, 5])
    #expect(batches.flatMap { $0 } == transactions)
    #expect(AppAIClient.entitlementBatches([]).isEmpty)
}
