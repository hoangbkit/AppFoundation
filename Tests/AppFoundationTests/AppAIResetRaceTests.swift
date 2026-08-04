import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor ResetRaceTransport: AppAITransport {
    private var requests: [URLRequest] = []
    private var firstRequestStarted = false
    private var firstRequestWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstRequestRelease: CheckedContinuation<Void, Never>?

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let requestNumber = requests.count

        if requestNumber == 1 {
            firstRequestStarted = true
            let waiters = firstRequestWaiters
            firstRequestWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                firstRequestRelease = continuation
            }
        }

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

    func waitForFirstRequest() async {
        if firstRequestStarted { return }
        await withCheckedContinuation { continuation in
            firstRequestWaiters.append(continuation)
        }
    }

    func releaseFirstRequest() {
        firstRequestRelease?.resume()
        firstRequestRelease = nil
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private actor ResetRaceAttestation: AppAIAttestationProviding {
    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        ["X-App-Attest-Key-ID": "reset-race-key"]
    }

    func resetKey() async throws {}
}

private struct ResetRaceInput: Encodable, Sendable {
    let text: String
}

private struct ResetRaceOutput: Decodable, Sendable {
    let text: String
}

@Test func resetBetweenProtectedRequestsForcesTheNextRequestToReadANewIdentity() async throws {
    let configuration = AppAIClientConfiguration(
        appID: "reset-race-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        attestationPolicy: .required,
        keychainService: "com.hoangbkit.AppFoundationTests.ResetRace.\(UUID().uuidString)"
    )
    let transport = ResetRaceTransport()
    let client = AppAIClient(
        configuration: configuration,
        transport: transport,
        attestationProvider: ResetRaceAttestation()
    )

    let first = Task {
        let response: AppAIResponse<ResetRaceOutput> = try await client.generate(
            capability: "reset.race",
            input: ResetRaceInput(text: "before"),
            requestID: "reset-race-before"
        )
        return response
    }

    await transport.waitForFirstRequest()

    let reset = Task {
        try await client.resetInstallationIdentity()
    }

    // Give reset a chance to queue on the process-wide attestation gate before
    // the following request. The gate itself remains the synchronization source.
    await Task.yield()
    await Task.yield()

    let second = Task {
        let response: AppAIResponse<ResetRaceOutput> = try await client.generate(
            capability: "reset.race",
            input: ResetRaceInput(text: "after"),
            requestID: "reset-race-after"
        )
        return response
    }

    await transport.releaseFirstRequest()
    _ = try await first.value
    try await reset.value
    _ = try await second.value

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(
        requests[0].value(forHTTPHeaderField: "X-Installation-ID")
            != requests[1].value(forHTTPHeaderField: "X-Installation-ID")
    )

    try await client.resetInstallationIdentity()
}
