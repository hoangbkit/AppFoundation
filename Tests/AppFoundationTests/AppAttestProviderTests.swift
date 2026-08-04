import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor AppAttestTestTransport: AppAITransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        switch request.url?.path {
        case "/v1/attest/challenge":
            let body = try #require(request.httpBody)
            let object = try #require(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            let purpose = try #require(object["purpose"] as? String)
            let payload: [String: Any] = [
                "challengeId": "\(purpose)-challenge-\(requests.count)",
                "challenge": "AQID",
                "expiresAt": "2026-09-01T00:00:00Z",
            ]
            return (try JSONSerialization.data(withJSONObject: payload), response)

        case "/v1/attest/register":
            return (Data("{}".utf8), response)

        default:
            Issue.record("Unexpected App Attest request path: \(request.url?.path ?? "nil")")
            return (Data("{}".utf8), response)
        }
    }

    func requestCount() -> Int { requests.count }
}

private actor AppAttestTestService: AppleAppAttestServicing {
    private let freshKeyID: String
    private var invalidAssertionFailuresRemaining: Int
    private var generateKeyCalls = 0
    private var attestedKeyIDs: [String] = []
    private var assertionKeyIDs: [String] = []

    init(
        freshKeyID: String = "fresh-app-attest-key",
        invalidAssertionFailures: Int
    ) {
        self.freshKeyID = freshKeyID
        self.invalidAssertionFailuresRemaining = invalidAssertionFailures
    }

    func isSupported() async -> Bool { true }

    func generateKey() async throws -> String {
        generateKeyCalls += 1
        return freshKeyID
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        attestedKeyIDs.append(keyID)
        return Data([0xA1])
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        assertionKeyIDs.append(keyID)
        if invalidAssertionFailuresRemaining > 0 {
            invalidAssertionFailuresRemaining -= 1
            throw AppleAppAttestServiceError.invalidKey("The App Attest key is invalid.")
        }
        return Data([0xB2])
    }

    func generatedKeyCount() -> Int { generateKeyCalls }
    func attestedKeys() -> [String] { attestedKeyIDs }
    func assertionKeys() -> [String] { assertionKeyIDs }
}

private func appAttestTestConfiguration(
    appID: String = "app-attest-reinstall-test"
) -> AppAIClientConfiguration {
    AppAIClientConfiguration(
        appID: appID,
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        attestationPolicy: .required,
        keychainService: "com.hoangbkit.AppFoundationTests.AppAttest.\(UUID().uuidString)"
    )
}

private func appAttestRequest() -> AppAIAttestationRequest {
    AppAIAttestationRequest(
        requestID: "request-after-reinstall",
        method: "POST",
        path: "/v1/ai/generate",
        body: Data("{\"requestId\":\"request-after-reinstall\"}".utf8)
    )
}

@Test func staleStoredAppAttestKeyIsReplacedAfterReinstall() async throws {
    let configuration = appAttestTestConfiguration()
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let keyAccount = "\(configuration.appID).app-attest-key"
    try await secureStore.set("stale-app-attest-key", for: keyAccount)

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(invalidAssertionFailures: 1)
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "installation-kept-in-keychain",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service
    )

    let headers = try await provider.headers(for: appAttestRequest())
    let storedKey = try await secureStore.string(for: keyAccount)

    #expect(headers["X-App-Attest-Key-ID"] == "fresh-app-attest-key")
    #expect(headers["X-App-Attest-Assertion"] == Data([0xB2]).base64EncodedString())
    #expect(storedKey == "fresh-app-attest-key")
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)

    try await secureStore.remove(keyAccount)
}

@Test func invalidFreshAppAttestKeyDoesNotCreateARecoveryLoop() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-no-loop-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let keyAccount = "\(configuration.appID).app-attest-key"
    try await secureStore.set("stale-app-attest-key", for: keyAccount)

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(invalidAssertionFailures: 2)
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "installation-kept-in-keychain",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service
    )

    var capturedError: AppAIError?
    do {
        _ = try await provider.headers(for: appAttestRequest())
        Issue.record("Expected the fresh App Attest assertion to fail.")
    } catch let error as AppAIError {
        capturedError = error
    }

    switch capturedError {
    case .attestationFailed:
        break
    default:
        Issue.record("Expected attestationFailed, received \(String(describing: capturedError)).")
    }

    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)

    try await secureStore.remove(keyAccount)
}
