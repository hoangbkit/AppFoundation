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
    private(set) var prepares = 0
    private(set) var resets = 0
    private(set) var headerCalls = 0

    func prepare() async throws {
        prepares += 1
    }

    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        headerCalls += 1
        return [
            "X-App-Attest-Key-ID": "test-key",
            "X-Test-Request-ID": request.requestID,
            "X-Test-Assertion": String(headerCalls),
        ]
    }

    func resetKey() async throws {
        resets += 1
    }

    func prepareCount() -> Int { prepares }
    func calls() -> Int { headerCalls }
}

private actor OverlapDetectingTransport: AppAITransport {
    private var requests: [URLRequest] = []
    private var inFlight = 0
    private var maximumInFlight = 0

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        inFlight += 1
        maximumInFlight = max(maximumInFlight, inFlight)
        defer { inFlight -= 1 }

        try await Task<Never, Never>.sleep(nanoseconds: 40_000_000)

        guard let body = request.httpBody,
              let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let requestID = object["requestId"] as? String,
              let capability = object["capability"] as? String else {
            throw AppAIError.invalidResponse
        }

        let payload: [String: Any] = [
            "requestId": requestID,
            "capability": capability,
            "data": ["text": "Done"],
        ]
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (try JSONSerialization.data(withJSONObject: payload), response)
    }

    func maxInFlight() -> Int { maximumInFlight }
    func capturedRequests() -> [URLRequest] { requests }
}

private struct Input: Codable, Sendable {
    let text: String
}

private struct Output: Codable, Sendable, Equatable {
    let text: String
}

private func makeConfiguration(
    appID: String = "draftx",
    baseURL: URL = URL(string: "https://example.com")!
) -> AppAIClientConfiguration {
    AppAIClientConfiguration(
        appID: appID,
        appKey: "test-key-123456789",
        baseURL: baseURL,
        keychainService: "com.hoangbkit.AppFoundationTests.\(UUID().uuidString)"
    )
}

private func successfulGenerateResponse(
    for request: URLRequest,
    text: String = "Done"
) throws -> (Data, HTTPURLResponse) {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
          let requestID = object["requestId"] as? String,
          let capability = object["capability"] as? String else {
        throw AppAIError.invalidResponse
    }
    let payload: [String: Any] = [
        "requestId": requestID,
        "capability": capability,
        "data": ["text": text],
    ]
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    return (try JSONSerialization.data(withJSONObject: payload), response)
}

@Test func generateUsesStableRequestIDAndAttestationHeaders() async throws {
    let transport = MockTransport { request in
        #expect(request.value(forHTTPHeaderField: "X-App-ID") == "draftx")
        #expect(request.value(forHTTPHeaderField: "X-App-Attest-Key-ID") == "test-key")
        #expect(request.value(forHTTPHeaderField: "X-Test-Request-ID") == "request-123456")
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (
            #"{"requestId":"request-123456","capability":"rewrite.polish","data":{"text":"Done"},"attestation":"verified","usage":{"limit":10,"used":1,"remaining":9,"resetsAt":"2026-09-01T00:00:00Z"}}"#.data(using: .utf8)!,
            response
        )
    }
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: MockAttestation()
    )
    let result: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Hello"),
        requestID: "request-123456"
    )
    #expect(result.data == Output(text: "Done"))
    #expect(await transport.count() == 1)
    try await client.resetInstallationIdentity()
}

@Test func prepareAttestationWarmsTheInjectedProviderWithoutSendingAIRequest() async throws {
    let transport = MockTransport { request in
        Issue.record("Unexpected request during preparation: \(request.url?.absoluteString ?? "nil")")
        throw AppAIError.invalidResponse
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(appID: "prepare-test"),
        transport: transport,
        attestationProvider: attestation
    )

    try await client.prepareAttestation()

    #expect(await attestation.prepareCount() == 1)
    #expect(await attestation.calls() == 0)
    #expect(await transport.count() == 0)
    try await client.resetInstallationIdentity()
}

@Test func transportRetryReusesTheSameEncodedRequest() async throws {
    actor State {
        var calls = 0
        func next() -> Int {
            calls += 1
            return calls
        }
    }
    let state = State()
    let transport = MockTransport { request in
        let call = awaitSync { await state.next() }
        if call == 1 {
            throw URLError(.networkConnectionLost)
        }
        return try successfulGenerateResponse(for: request)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: attestation
    )
    let _: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Hello"),
        requestID: "request-654321"
    )
    #expect(await transport.count() == 2)
    #expect(await attestation.calls() == 2)
    let requests = await transport.capturedRequests()
    #expect(requests[0].httpBody == requests[1].httpBody)
    try await client.resetInstallationIdentity()
}

private func awaitSync<T: Sendable>(
    _ operation: @escaping @Sendable () async -> T
) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var value: T?
    Task {
        value = await operation()
        semaphore.signal()
    }
    semaphore.wait()
    return value!
}

@Test func unknownServerKeyIsResetAndRegisteredAgainOnce() async throws {
    actor State {
        var calls = 0
        func next() -> Int {
            calls += 1
            return calls
        }
    }
    let state = State()
    let transport = MockTransport { request in
        let call = awaitSync { await state.next() }
        if call == 1 {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (
                #"{"error":{"code":"attestation_key_not_registered","message":"Unknown key","requestId":"server"}}"#.data(using: .utf8)!,
                response
            )
        }
        return try successfulGenerateResponse(for: request)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: attestation
    )
    let _: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Hello"),
        requestID: "request-key-reset"
    )
    #expect(await transport.count() == 2)
    #expect(await attestation.resets == 1)
    #expect(await attestation.calls() == 2)
    try await client.resetInstallationIdentity()
}

@Test func rejectedAssertionIsRetriedOnceWithAFreshAssertion() async throws {
    actor State {
        var calls = 0
        func next() -> Int {
            calls += 1
            return calls
        }
    }
    let state = State()
    let transport = MockTransport { request in
        let call = awaitSync { await state.next() }
        if call == 1 {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: nil,
                headerFields: nil
            )!
            return (
                #"{"error":{"code":"attestation_replayed","message":"Counter race","requestId":"server"}}"#.data(using: .utf8)!,
                response
            )
        }
        return try successfulGenerateResponse(for: request)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(appID: "assertion-retry-test"),
        transport: transport,
        attestationProvider: attestation
    )

    let _: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Hello"),
        requestID: "request-assertion-retry"
    )

    #expect(await transport.count() == 2)
    #expect(await attestation.calls() == 2)
    #expect(await attestation.resets == 0)
    try await client.resetInstallationIdentity()
}

@Test func attestedProtectedRequestsDoNotOverlap() async throws {
    let transport = OverlapDetectingTransport()
    let configuration = makeConfiguration(appID: "concurrent-attestation-test")
    let client = AppAIClient(
        configuration: configuration,
        transport: transport,
        attestationProvider: MockAttestation()
    )

    async let first: AppAIResponse<Output> = client.generate(
        capability: "rewrite.polish",
        input: Input(text: "First"),
        requestID: "concurrent-request-1"
    )
    async let second: AppAIResponse<Output> = client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Second"),
        requestID: "concurrent-request-2"
    )

    _ = try await (first, second)

    #expect(await transport.maxInFlight() == 1)
    #expect(await transport.capturedRequests().count == 2)
    try await client.resetInstallationIdentity()
}

#if canImport(Security)
@Test func clientsSharingAConfigurationUseTheSameInstallationIdentity() async throws {
    let transport = OverlapDetectingTransport()
    let configuration = makeConfiguration(appID: "shared-installation-test")
    let firstClient = AppAIClient(
        configuration: configuration,
        transport: transport,
        attestationProvider: MockAttestation()
    )
    let secondClient = AppAIClient(
        configuration: configuration,
        transport: transport,
        attestationProvider: MockAttestation()
    )

    async let first: AppAIResponse<Output> = firstClient.generate(
        capability: "rewrite.polish",
        input: Input(text: "First"),
        requestID: "shared-installation-1"
    )
    async let second: AppAIResponse<Output> = secondClient.generate(
        capability: "rewrite.polish",
        input: Input(text: "Second"),
        requestID: "shared-installation-2"
    )

    _ = try await (first, second)

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(
        requests[0].value(forHTTPHeaderField: "X-Installation-ID")
            == requests[1].value(forHTTPHeaderField: "X-Installation-ID")
    )
    try await firstClient.resetInstallationIdentity()
}
#endif

@Test func entitlementSyncUsesProtectedStableRequest() async throws {
    let transport = MockTransport { request in
        #expect(request.url?.path == "/v1/entitlements/sync")
        #expect(request.value(forHTTPHeaderField: "X-App-Attest-Key-ID") == "test-key")
        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["requestId"] as? String == "sync-request-123")
        #expect((json["transactions"] as? [String]) == ["signed-transaction"])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (
            #"{"requestId":"sync-request-123","synced":1,"access":{"plan":"paid","quotaLimit":250,"productId":"pro.yearly","productType":"auto_renewable","status":"active","expiresAt":"2026-09-01T00:00:00Z"}}"#.data(using: .utf8)!,
            response
        )
    }
    let client = AppAIClient(
        configuration: makeConfiguration(),
        transport: transport,
        attestationProvider: MockAttestation()
    )
    let result = try await client.syncEntitlements(
        transactions: ["signed-transaction"],
        requestID: "sync-request-123"
    )
    #expect(result.access.plan == "paid")
    #expect(result.access.quotaLimit == 250)
    try await client.resetInstallationIdentity()
}

@Test func resetBeforeFirstUseClearsPersistedDefaultAttestationState() async throws {
    let configuration = makeConfiguration(appID: "reset-before-use-test")
    let registeredKey = "\(configuration.keychainService).\(configuration.appID).app-attest-key"
    let pendingKey = "\(configuration.keychainService).\(configuration.appID).app-attest-pending-registration.v1"
    UserDefaults.standard.set("cached-key", forKey: registeredKey)
    UserDefaults.standard.set(Data([0x01]), forKey: pendingKey)
    defer {
        UserDefaults.standard.removeObject(forKey: registeredKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    let client = AppAIClient(
        configuration: configuration,
        transport: MockTransport { request in
            Issue.record("Unexpected reset request: \(request.url?.absoluteString ?? "nil")")
            throw AppAIError.invalidResponse
        }
    )

    try await client.resetInstallationIdentity()

    #expect(UserDefaults.standard.string(forKey: registeredKey) == nil)
    #expect(UserDefaults.standard.data(forKey: pendingKey) == nil)
}

@Test func resetInstallationIdentityUsesANewInstallationID() async throws {
    let transport = MockTransport { request in
        try successfulGenerateResponse(for: request)
    }
    let attestation = MockAttestation()
    let client = AppAIClient(
        configuration: makeConfiguration(appID: "reset-test"),
        transport: transport,
        attestationProvider: attestation
    )

    let _: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "Before")
    )
    try await client.resetInstallationIdentity()
    let _: AppAIResponse<Output> = try await client.generate(
        capability: "rewrite.polish",
        input: Input(text: "After")
    )

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(
        requests[0].value(forHTTPHeaderField: "X-Installation-ID")
            != requests[1].value(forHTTPHeaderField: "X-Installation-ID")
    )
    #expect(await attestation.resets == 1)
    #expect(await attestation.calls() == 2)
    try await client.resetInstallationIdentity()
}

@Test func endpointURLNormalizesLeadingAndTrailingSlashes() {
    let root = AppAIClient.endpointURL(
        baseURL: URL(string: "https://example.com/")!,
        path: "/v1/status"
    )
    let nested = AppAIClient.endpointURL(
        baseURL: URL(string: "https://example.com/api/")!,
        path: "/v1/status"
    )

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
