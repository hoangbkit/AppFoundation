import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor CancellingAITransport: AppAITransport {
    enum Failure: Sendable {
        case taskCancellation
        case cancelledURL
    }

    private let failure: Failure
    private var requests = 0

    init(failure: Failure) {
        self.failure = failure
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests += 1
        switch failure {
        case .taskCancellation:
            throw CancellationError()
        case .cancelledURL:
            throw URLError(.cancelled)
        }
    }

    func requestCount() -> Int { requests }
}

private actor CancellationTestAttestation: AppAIAttestationProviding {
    private var calls = 0

    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        calls += 1
        return ["X-App-Attest-Key-ID": "cancellation-test-key"]
    }

    func resetKey() async throws {}

    func headerCount() -> Int { calls }
}

private struct CancellationInput: Encodable, Sendable {
    let value: String
}

private struct CancellationOutput: Decodable, Sendable {
    let value: String
}

private func cancellationConfiguration(_ suffix: String) -> AppAIClientConfiguration {
    AppAIClientConfiguration(
        appID: "cancellation-\(suffix)",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        attestationPolicy: .required,
        keychainService: "com.hoangbkit.AppFoundationTests.Cancellation.\(UUID().uuidString)",
        transportRetryCount: 3
    )
}

@Test(arguments: [
    CancellingAITransport.Failure.taskCancellation,
    CancellingAITransport.Failure.cancelledURL,
])
func cancellationIsPropagatedWithoutTransportRetry(
    failure: CancellingAITransport.Failure
) async throws {
    let transport = CancellingAITransport(failure: failure)
    let attestation = CancellationTestAttestation()
    let client = AppAIClient(
        configuration: cancellationConfiguration(String(describing: failure)),
        transport: transport,
        attestationProvider: attestation
    )

    do {
        let _: AppAIResponse<CancellationOutput> = try await client.generate(
            capability: "cancellation.test",
            input: CancellationInput(value: "test")
        )
        Issue.record("Expected cancellation to propagate.")
    } catch is CancellationError {
        // Expected.
    } catch {
        Issue.record("Expected CancellationError, received \(error).")
    }

    #expect(await transport.requestCount() == 1)
    #expect(await attestation.headerCount() == 1)
}
