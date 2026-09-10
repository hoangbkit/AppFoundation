import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor ContractMemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?
    private var removals = 0

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws {
        data = nil
        removals += 1
    }

    func removalCount() -> Int { removals }
    func snapshot() -> Data? { data }
}

private actor ContractAnalyticsTransport: AppAnalyticsTransport {
    enum Outcome: Sendable {
        case success
        case invalidRequestID
        case acceptedDays([String])
        case server(status: Int, code: String, message: String, retryAfter: String?)
    }

    private var outcomes: [Outcome]
    private var requests: [URLRequest] = []

    init(_ outcomes: [Outcome] = []) {
        self.outcomes = outcomes
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let body = try contractRequestBody(request)
        let requestID = try #require(body["requestId"] as? String)
        let days = try #require(body["days"] as? [[String: Any]])
        let actualDays = days.compactMap { $0["day"] as? String }
        let outcome = outcomes.isEmpty ? Outcome.success : outcomes.removeFirst()

        let payload: [String: Any]
        let status: Int
        let headers: [String: String]?
        switch outcome {
        case .success:
            status = 200
            headers = nil
            payload = ["ok": true, "requestId": requestID, "acceptedDays": actualDays]
        case .invalidRequestID:
            status = 200
            headers = nil
            payload = ["ok": true, "requestId": "wrong-request-id", "acceptedDays": actualDays]
        case .acceptedDays(let acceptedDays):
            status = 200
            headers = nil
            payload = ["ok": true, "requestId": requestID, "acceptedDays": acceptedDays]
        case .server(let responseStatus, let code, let message, let retryAfter):
            status = responseStatus
            headers = retryAfter.map { ["Retry-After": $0] }
            var detail: [String: Any] = ["code": code, "message": message]
            if let retryAfter { detail["retryAfter"] = retryAfter }
            payload = ["error": detail]
        }

        return (
            try JSONSerialization.data(withJSONObject: payload),
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
            )!
        )
    }

    func capturedRequests() -> [URLRequest] { requests }
    func requestCount() -> Int { requests.count }
}

private func contractConfiguration(
    keychainService: String? = nil,
    stateStorageKey: String? = nil,
    appVersion: String? = "1.2.3",
    uploadInterval: TimeInterval = 86_400
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: keychainService
            ?? "com.hoangbkit.AppFoundationContractTests.\(UUID().uuidString)",
        stateStorageKey: stateStorageKey
            ?? "analytics-contract-state-\(UUID().uuidString)",
        appVersion: appVersion,
        uploadInterval: uploadInterval,
        transportRetryCount: 0
    )
}

private func contractDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func contractRequestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

private func contractDays(_ request: URLRequest) throws -> [[String: Any]] {
    let body = try contractRequestBody(request)
    return try #require(body["days"] as? [[String: Any]])
}

private func contractEvents(_ day: [String: Any]) throws -> [[String: Any]] {
    try #require(day["events"] as? [[String: Any]])
}

private func persistedState(days: [String: [String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["days": days])
}

private func persistedDay(
    appVersion: String? = "1.2.3",
    sessions: Int = 0,
    sessionSeconds: Int = 0,
    events: [(name: String, dimension: String?, count: Int)] = []
) -> [String: Any] {
    var eventMap: [String: Any] = [:]
    for (index, event) in events.enumerated() {
        var payload: [String: Any] = ["name": event.name, "count": event.count]
        if let dimension = event.dimension { payload["dimension"] = dimension }
        eventMap["event-\(index)"] = payload
    }
    var result: [String: Any] = [
        "sessions": sessions,
        "sessionSeconds": sessionSeconds,
        "events": eventMap,
    ]
    if let appVersion { result["appVersion"] = appVersion }
    return result
}

private func eventCounters(_ count: Int, prefix: String) -> [(String, String?, Int)] {
    (0..<count).map { index in
        ("\(prefix)_\(String(format: "%03d", index))", nil, 1)
    }
}

@Test func analyticsRetentionKeepsSixDayOldSnapshotAndPrunesSevenDayOldSnapshot() async throws {
    let state = try persistedState(days: [
        "2026-09-01": persistedDay(events: [("old_event", nil, 1)]),
        "2026-09-02": persistedDay(events: [("kept_event", nil, 1)]),
    ])
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(data: state),
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    try await client.flush()
    let request = try #require(await transport.capturedRequests().first)
    let days = try contractDays(request)
    #expect(days.count == 1)
    #expect(days[0]["day"] as? String == "2026-09-02")
}

@Test func analyticsBatchContainsAtMostSevenUTCdays() async throws {
    let dayKeys = [
        "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05",
        "2026-09-06", "2026-09-07", "2026-09-08",
    ]
    let state = try persistedState(days: Dictionary(uniqueKeysWithValues: dayKeys.map {
        ($0, persistedDay(events: [("daily_event", nil, 1)]))
    }))
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(data: state),
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    try await client.flush()
    let requests = await transport.capturedRequests()
    #expect(requests.count == 1)
    #expect(try contractDays(requests[0]).count == 7)
}

@Test func analyticsHundredCounterBatchLimitSplitsLargeSnapshotSet() async throws {
    let state = try persistedState(days: [
        "2026-09-06": persistedDay(events: eventCounters(40, prefix: "first")),
        "2026-09-07": persistedDay(events: eventCounters(40, prefix: "second")),
        "2026-09-08": persistedDay(events: eventCounters(40, prefix: "third")),
    ])
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(data: state),
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    try await client.flush()
    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    let firstCount = try contractDays(requests[0]).reduce(0) { $0 + (try contractEvents($1).count) }
    let secondCount = try contractDays(requests[1]).reduce(0) { $0 + (try contractEvents($1).count) }
    #expect(firstCount == 80)
    #expect(secondCount == 40)
}

@Test func analyticsAllowsExactlyFiftyCountersButRejectsFiftyFirstUniqueCounter() async throws {
    let timestamp = contractDate("2026-09-08T12:00:00Z")
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    for index in 0..<50 {
        try await client.track("event_\(String(format: "%02d", index))")
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("event_50")
    }

    try await client.flush()
    let request = try #require(await transport.capturedRequests().last)
    let day = try #require(contractDays(request).first)
    #expect(try contractEvents(day).count == 50)
}

@Test func analyticsEventAndSessionValuesSaturateAtServerCaps() async throws {
    let timestamp = contractDate("2026-09-08T12:00:00Z")
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    try await client.track("generation_completed", count: 99_999)
    try await client.track("generation_completed", count: 10)
    try await client.flush()
    let request = try #require(await transport.capturedRequests().last)
    let day = try #require(contractDays(request).first)
    let event = try #require(contractEvents(day).first)
    #expect(event["count"] as? Int == 100_000)

    let boundedState = try persistedState(days: [
        "2026-09-08": persistedDay(sessions: 1_500, sessionSeconds: 100_000),
    ])
    let boundedTransport = ContractAnalyticsTransport()
    let boundedClient = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: boundedTransport,
        stateStore: ContractMemoryAnalyticsStateStore(data: boundedState),
        now: { timestamp }
    )
    try await boundedClient.flush()
    let boundedRequest = try #require(await boundedTransport.capturedRequests().first)
    let boundedDay = try #require(contractDays(boundedRequest).first)
    #expect(boundedDay["sessions"] as? Int == 1_000)
    #expect(boundedDay["sessionSeconds"] as? Int == 86_400)
}

@Test func analyticsTokenAndAppVersionBoundariesMatchServerContract() async throws {
    let timestamp = contractDate("2026-09-08T12:00:00Z")
    let validName = "a" + String(repeating: "b", count: 47)
    let invalidName = "a" + String(repeating: "b", count: 48)
    let validDimension = "A" + String(repeating: "b", count: 63)
    let invalidDimension = "A" + String(repeating: "b", count: 64)
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track(validName, dimension: validDimension)
    await #expect(throws: AppAnalyticsError.self) { try await client.track(invalidName) }
    await #expect(throws: AppAnalyticsError.self) { try await client.track("valid_name", dimension: invalidDimension) }
    await #expect(throws: AppAnalyticsError.self) { try await client.track("Uppercase") }
    await #expect(throws: AppAnalyticsError.self) { try await client.track("valid_name", dimension: "-invalid") }

    let validVersion = "A" + String(repeating: "b", count: 63)
    let versionTransport = ContractAnalyticsTransport()
    let versionClient = AppAnalyticsClient(
        configuration: contractConfiguration(appVersion: validVersion),
        transport: versionTransport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    try await versionClient.track("generation_completed")
    let versionRequest = try #require(await versionTransport.capturedRequests().first)
    #expect(versionRequest.value(forHTTPHeaderField: "X-App-Version") == validVersion)
}

@Test func oversizedPersistedAnalyticsBatchIsRejectedBeforeTransport() async throws {
    let oversizedEvents: [(String, String?, Int)] = (0..<40).map { index in
        ("e\(index)_" + String(repeating: "x", count: 1_000), nil, 1)
    }
    let state = try persistedState(days: [
        "2026-09-08": persistedDay(events: oversizedEvents),
    ])
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(data: state),
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    await #expect(throws: AppAnalyticsError.self) { try await client.flush() }
    #expect(await transport.requestCount() == 0)
}

@Test func analyticsRejectsMismatchedAndReorderedSuccessfulResponses() async throws {
    let stateData = try persistedState(days: [
        "2026-09-07": persistedDay(events: [("first_event", nil, 1)]),
        "2026-09-08": persistedDay(events: [("second_event", nil, 1)]),
    ])
    let now = contractDate("2026-09-08T12:00:00Z")

    let wrongIDTransport = ContractAnalyticsTransport([.invalidRequestID])
    let wrongIDClient = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: wrongIDTransport,
        stateStore: ContractMemoryAnalyticsStateStore(data: stateData),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) { try await wrongIDClient.flush() }
    #expect(try await wrongIDClient.pendingDayCount() == 2)

    let reorderedTransport = ContractAnalyticsTransport([
        .acceptedDays(["2026-09-08", "2026-09-07"]),
    ])
    let reorderedClient = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: reorderedTransport,
        stateStore: ContractMemoryAnalyticsStateStore(data: stateData),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) { try await reorderedClient.flush() }
    #expect(try await reorderedClient.pendingDayCount() == 2)
}

@Test func analyticsRejectsMissingOrExtraAcceptedDays() async throws {
    let days = [
        "2026-09-07": persistedDay(events: [("first_event", nil, 1)]),
        "2026-09-08": persistedDay(events: [("second_event", nil, 1)]),
    ]
    let now = contractDate("2026-09-08T12:00:00Z")

    let missingTransport = ContractAnalyticsTransport([.acceptedDays(["2026-09-07"])])
    let missingClient = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: missingTransport,
        stateStore: ContractMemoryAnalyticsStateStore(data: try persistedState(days: days)),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) { try await missingClient.flush() }
    #expect(try await missingClient.pendingDayCount() == 2)

    let extraTransport = ContractAnalyticsTransport([
        .acceptedDays(["2026-09-07", "2026-09-08", "2026-09-06"]),
    ])
    let extraClient = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: extraTransport,
        stateStore: ContractMemoryAnalyticsStateStore(data: try persistedState(days: days)),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) { try await extraClient.flush() }
    #expect(try await extraClient.pendingDayCount() == 2)
}

@Test func analyticsStructuredServerErrorsPreserveCodeMessageAndRetryAfter() async throws {
    let cases: [(Int, String, String, String?)] = [
        (401, "unauthorized", "Unauthorized.", nil),
        (403, "installation_suspended", "Installation suspended.", nil),
        (429, "rate_limited", "Slow down.", "60"),
        (503, "app_disabled", "Analytics disabled.", "120"),
    ]

    for (status, code, message, retryAfter) in cases {
        let state = try persistedState(days: [
            "2026-09-08": persistedDay(events: [("generation_completed", nil, 1)]),
        ])
        let transport = ContractAnalyticsTransport([
            .server(status: status, code: code, message: message, retryAfter: retryAfter),
        ])
        let client = AppAnalyticsClient(
            configuration: contractConfiguration(),
            transport: transport,
            stateStore: ContractMemoryAnalyticsStateStore(data: state),
            now: { contractDate("2026-09-08T12:00:00Z") }
        )

        do {
            try await client.flush()
            Issue.record("Expected server error \(code).")
        } catch let error as AppAnalyticsError {
            #expect(error == .server(code: code, message: message, retryAfter: retryAfter))
        }
    }
}

@Test func corruptAnalyticsPersistenceRecoversToCleanState() async throws {
    let store = ContractMemoryAnalyticsStateStore(data: Data("not-valid-json".utf8))
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(),
        transport: ContractAnalyticsTransport(),
        stateStore: store,
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    try await client.track("generation_completed")
    #expect(await store.removalCount() == 1)
    #expect(try await client.pendingDayCount() == 1)
    #expect(await store.snapshot() != nil)
}

@Test func resetAnalyticsStatePreservesInstallationIdentity() async throws {
    let service = "com.hoangbkit.AppFoundationContractReset.\(UUID().uuidString)"
    let transport = ContractAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: contractConfiguration(keychainService: service, uploadInterval: 0),
        transport: transport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { contractDate("2026-09-08T12:00:00Z") }
    )

    try await client.track("generation_completed", count: 3)
    let firstRequest = try #require(await transport.capturedRequests().first)
    let firstID = try #require(firstRequest.value(forHTTPHeaderField: "X-Installation-ID"))

    try await client.resetLocalState()
    try await client.track("generation_completed")

    let secondRequest = try #require(await transport.capturedRequests().last)
    let secondID = try #require(secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))
    #expect(secondID == firstID)
    let day = try #require(contractDays(secondRequest).first)
    #expect(try contractEvents(day).first?["count"] as? Int == 1)
}

#if canImport(Security)
@Test func analyticsInstallationIdentityIsStableAcrossClientInstances() async throws {
    let service = "com.hoangbkit.AppFoundationContractStable.\(UUID().uuidString)"
    let configuration = contractConfiguration(keychainService: service, uploadInterval: 0)
    let timestamp = contractDate("2026-09-08T12:00:00Z")
    let firstTransport = ContractAnalyticsTransport()
    let secondTransport = ContractAnalyticsTransport()

    let first = AppAnalyticsClient(
        configuration: configuration,
        transport: firstTransport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    let second = AppAnalyticsClient(
        configuration: configuration,
        transport: secondTransport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    try await first.track("first_event")
    try await second.track("second_event")

    let firstRequest = try #require(await firstTransport.capturedRequests().first)
    let secondRequest = try #require(await secondTransport.capturedRequests().first)
    #expect(firstRequest.value(forHTTPHeaderField: "X-Installation-ID")
            == secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))
}

@Test func concurrentAnalyticsClientsShareFirstInstallationIdentity() async throws {
    let service = "com.hoangbkit.AppFoundationContractConcurrent.\(UUID().uuidString)"
    let configuration = contractConfiguration(keychainService: service, uploadInterval: 0)
    let timestamp = contractDate("2026-09-08T12:00:00Z")
    let firstTransport = ContractAnalyticsTransport()
    let secondTransport = ContractAnalyticsTransport()
    let first = AppAnalyticsClient(
        configuration: configuration,
        transport: firstTransport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    let second = AppAnalyticsClient(
        configuration: configuration,
        transport: secondTransport,
        stateStore: ContractMemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    async let firstTrack: Void = first.track("first_event")
    async let secondTrack: Void = second.track("second_event")
    _ = try await (firstTrack, secondTrack)

    let firstRequest = try #require(await firstTransport.capturedRequests().first)
    let secondRequest = try #require(await secondTransport.capturedRequests().first)
    #expect(firstRequest.value(forHTTPHeaderField: "X-Installation-ID")
            == secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))
}
#endif
