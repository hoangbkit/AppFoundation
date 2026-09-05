import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor MemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
}

private actor MockAnalyticsTransport: AppAnalyticsTransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let body = request.httpBody,
              let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let requestID = object["requestId"] as? String,
              let days = object["days"] as? [[String: Any]] else {
            throw AppAnalyticsError.invalidResponse
        }
        let acceptedDays = days.compactMap { $0["day"] as? String }
        let payload: [String: Any] = [
            "ok": true,
            "requestId": requestID,
            "acceptedDays": acceptedDays,
        ]
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (try JSONSerialization.data(withJSONObject: payload), response)
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private actor MockAIStatusTransport: AppAITransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let payload = #"{"app":{"id":"analytics-test","displayName":"Analytics Test"},"enabled":true,"plan":"free","entitlement":null,"attestation":{"mode":"disabled","status":"not_required"},"usage":{"limit":0,"used":0,"remaining":0,"resetsAt":"2026-10-01T00:00:00Z"}}"#
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (payload.data(using: .utf8)!, response)
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private func analyticsConfiguration(
    appID: String = "analytics-test",
    keychainService: String = "com.hoangbkit.AppFoundationTests.\(UUID().uuidString)"
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: appID,
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: keychainService,
        stateStorageKey: "analytics-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: 21_600,
        transportRetryCount: 0
    )
}

private func isoDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func requestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

@Test func analyticsFlushMatchesNativeServerContract() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let timestamp = isoDate("2026-09-05T10:00:00Z")
    let configuration = analyticsConfiguration()
    let client = AppAnalyticsClient(
        configuration: configuration,
        transport: transport,
        stateStore: store,
        now: { timestamp }
    )

    try await client.track("generation_completed", dimension: "nano", count: 2)
    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.url?.path == "/v1/analytics/batch")
    #expect(request.value(forHTTPHeaderField: "X-App-ID") == configuration.appID)
    #expect(request.value(forHTTPHeaderField: "X-App-Key") == configuration.appKey)
    #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.2.3")
    #expect(request.value(forHTTPHeaderField: "X-Installation-ID")?.isEmpty == false)

    let body = try requestBody(request)
    #expect(body["schemaVersion"] as? Int == 1)
    #expect((body["requestId"] as? String)?.hasPrefix("native-") == true)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days.count == 1)
    #expect(days[0]["day"] as? String == "2026-09-05")
    #expect(days[0]["platform"] as? String == "ios")
    let events = try #require(days[0]["events"] as? [[String: Any]])
    #expect(events.count == 1)
    #expect(events[0]["name"] as? String == "generation_completed")
    #expect(events[0]["dimension"] as? String == "nano")
    #expect(events[0]["count"] as? Int == 2)
}

@Test func analyticsSessionAccountingExcludesBackgroundAndUsesThirtyMinuteTimeout() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let flushTime = isoDate("2026-09-05T11:05:00Z")
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(),
        transport: transport,
        stateStore: store,
        now: { flushTime }
    )

    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T10:00:00Z"))
    try await client.applicationWillResignActive(at: isoDate("2026-09-05T10:10:00Z"))
    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T10:20:00Z"))
    try await client.applicationWillResignActive(at: isoDate("2026-09-05T10:25:00Z"))
    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T11:00:00Z"))
    try await client.applicationWillResignActive(at: flushTime)
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let body = try requestBody(request)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days[0]["sessions"] as? Int == 2)
    #expect(days[0]["sessionSeconds"] as? Int == 1_200)
}

@Test func analyticsReusesManagedAIInstallationIdentity() async throws {
    let keychainService = "com.hoangbkit.AppFoundationTests.\(UUID().uuidString)"
    let appID = "analytics-test"
    let analyticsTransport = MockAnalyticsTransport()
    let analytics = AppAnalyticsClient(
        configuration: analyticsConfiguration(appID: appID, keychainService: keychainService),
        transport: analyticsTransport,
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )
    try await analytics.track("export_completed")
    try await analytics.flush()
    let analyticsRequest = try #require(await analyticsTransport.capturedRequests().first)
    let analyticsInstallation = try #require(
        analyticsRequest.value(forHTTPHeaderField: "X-Installation-ID")
    )

    let aiTransport = MockAIStatusTransport()
    let ai = AppAIClient(
        configuration: AppAIClientConfiguration(
            appID: appID,
            appKey: "test-key-123456789",
            baseURL: URL(string: "https://example.com")!,
            attestationPolicy: .disabled,
            keychainService: keychainService
        ),
        transport: aiTransport
    )
    _ = try await ai.status()
    let aiRequest = try #require(await aiTransport.capturedRequests().first)
    #expect(aiRequest.value(forHTTPHeaderField: "X-Installation-ID") == analyticsInstallation)
    try await ai.resetInstallationIdentity()
}

@Test func analyticsRejectsInvalidEventNamesBeforePersistence() async throws {
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(),
        transport: MockAnalyticsTransport(),
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("Not Valid")
    }
    #expect(try await client.pendingDayCount() == 0)
}
