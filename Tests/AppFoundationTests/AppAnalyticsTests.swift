import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private final class MemoryAnalyticsStorage: AppAnalyticsStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func set(_ data: Data, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = data
    }
}

private actor AnalyticsTransport: AppAITransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let object = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        let requestID = object?["requestId"] as? String ?? "missing-request"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let payload: [String: Any] = [
            "ok": true,
            "requestId": requestID,
            "acceptedDays": [],
        ]
        return (try JSONSerialization.data(withJSONObject: payload), response)
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private actor AnalyticsAttestation: AppAIAttestationProviding {
    private var captured: [AppAIAttestationRequest] = []

    func prepare() async throws {}

    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        captured.append(request)
        return [
            "X-App-Attest-Key-ID": "analytics-test-key",
            "X-Test-Analytics-Request": request.requestID,
        ]
    }

    func resetKey() async throws {}

    func requests() -> [AppAIAttestationRequest] { captured }
}

private func analyticsTestStart() -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.startOfDay(for: Date()).addingTimeInterval(3_600)
}

private func analyticsConfiguration(
    appID: String = "analytics-tests"
) -> AppAIClientConfiguration {
    AppAIClientConfiguration(
        appID: appID,
        appKey: "analytics-test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        attestationPolicy: .required,
        keychainService: "com.hoangbkit.AppFoundationTests.analytics.\(UUID().uuidString)"
    )
}

@Test func analyticsAggregatesSessionsDurationAndEvents() async {
    let analytics = AppAnalytics(
        configuration: analyticsConfiguration(),
        appVersion: "1.5.0",
        storage: MemoryAnalyticsStorage()
    )
    let start = analyticsTestStart()

    await analytics.track("message_sent", dimension: nil, at: start)
    await analytics.track("message_sent", dimension: nil, at: start.addingTimeInterval(10))
    await analytics.track("message_sent", dimension: nil, at: start.addingTimeInterval(1_811))

    let batch = await analytics.buildBatch(now: start.addingTimeInterval(1_816))
    let day = batch?.days.first

    #expect(batch?.schemaVersion == 1)
    #expect(batch?.requestId.hasPrefix("native-") == true)
    #expect(day?.platform == .iOS)
    #expect(day?.appVersion == "1.5.0")
    #expect(day?.sessions == 2)
    #expect(day?.sessionSeconds == 1_815)
    #expect(day?.events == [AppAnalyticsEventCounter(name: "message_sent", count: 3)])
}

@Test func analyticsDropsUnsafeMetadataAndBoundsDistinctCounters() async {
    let analytics = AppAnalytics(
        configuration: analyticsConfiguration(),
        storage: MemoryAnalyticsStorage()
    )
    let start = analyticsTestStart()

    await analytics.track("Generation_Completed", dimension: nil, at: start)
    await analytics.track("generation_completed", dimension: "contains spaces", at: start)
    for index in 0..<60 {
        await analytics.track("event_\(index)", dimension: nil, at: start)
    }

    let batch = await analytics.buildBatch(now: start)
    let events = batch?.days.first?.events ?? []

    #expect(events.contains(AppAnalyticsEventCounter(name: "generation_completed", count: 1)))
    #expect(events.count == 50)
    #expect(!events.contains { $0.name == "Generation_Completed" })
    #expect(!events.contains { $0.dimension == "contains spaces" })
}

@Test func analyticsStateSurvivesClientRecreation() async {
    let storage = MemoryAnalyticsStorage()
    let configuration = analyticsConfiguration(appID: "analytics-persistence")
    let start = analyticsTestStart()

    let first = AppAnalytics(
        configuration: configuration,
        appVersion: "2.0.0",
        storage: storage
    )
    await first.track("export_completed", dimension: "pdf", at: start)

    let second = AppAnalytics(
        configuration: configuration,
        appVersion: "2.0.0",
        storage: storage
    )
    let batch = await second.buildBatch(now: start.addingTimeInterval(5))

    #expect(batch?.days.first?.sessions == 1)
    #expect(batch?.days.first?.events == [
        AppAnalyticsEventCounter(name: "export_completed", count: 1, dimension: "pdf")
    ])
}

@Test func analyticsSubmissionUsesExistingNativeSecurityPath() async throws {
    let transport = AnalyticsTransport()
    let attestation = AnalyticsAttestation()
    let client = AppAIClient(
        configuration: analyticsConfiguration(appID: "analytics-security"),
        transport: transport,
        attestationProvider: attestation
    )
    let batch = AppAnalyticsBatch(
        requestId: "analytics-request-123456",
        days: [
            AppAnalyticsDaySnapshot(
                day: {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                    let components = calendar.dateComponents([.year, .month, .day], from: Date())
                    return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
                }(),
                platform: .iOS,
                appVersion: "1.0.0",
                sessions: 1,
                sessionSeconds: 30,
                events: [AppAnalyticsEventCounter(name: "generation_completed", count: 1)]
            )
        ]
    )

    let result = try await client.submitAnalyticsBatch(batch)
    let requests = await transport.capturedRequests()
    let request = requests.first
    let attestationRequests = await attestation.requests()

    #expect(result.ok)
    #expect(result.requestId == batch.requestId)
    #expect(request?.url?.path == "/v1/analytics/batch")
    #expect(request?.value(forHTTPHeaderField: "X-App-ID") == "analytics-security")
    #expect(request?.value(forHTTPHeaderField: "X-App-Key") == "analytics-test-key-123456789")
    #expect((request?.value(forHTTPHeaderField: "X-Installation-ID")?.count ?? 0) >= 8)
    #expect(request?.value(forHTTPHeaderField: "X-Test-Analytics-Request") == batch.requestId)
    #expect(attestationRequests.first?.path == "/v1/analytics/batch")
    #expect(attestationRequests.first?.body == request?.httpBody)

    try await client.resetInstallationIdentity()
}
