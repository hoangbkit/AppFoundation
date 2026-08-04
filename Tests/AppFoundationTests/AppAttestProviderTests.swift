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
    func capturedRequests() -> [URLRequest] { requests }
}

private actor AppAttestTestService: AppleAppAttestServicing {
    private let freshKeyID: String
    private var invalidAssertionFailuresRemaining: Int
    private var generateKeyCalls = 0
    private var attestedKeyIDs: [String] = []
    private var assertionKeyIDs: [String] = []

    init(
        freshKeyID: String = "fresh-app-attest-key",
        invalidAssertionFailures: Int = 0
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

private func defaultsKey(for configuration: AppAIClientConfiguration) -> String {
    "\(configuration.keychainService).\(configuration.appID).app-attest-key"
}

private func makeDefaultsSuite() throws -> (name: String, defaults: UserDefaults) {
    let name = "com.hoangbkit.AppFoundationTests.AppAttestDefaults.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return (name, defaults)
}

@Test func reinstallWithoutLocalKeyRegistersAFreshAppAttestKey() async throws {
    let configuration = appAttestTestConfiguration()
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let legacyAccount = "\(configuration.appID).app-attest-key"
    try await secureStore.set("legacy-keychain-key", for: legacyAccount)

    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService()
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "installation-kept-in-keychain",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    let headers = try await provider.headers(for: appAttestRequest())
    let requests = await transport.capturedRequests()

    #expect(headers["X-App-Attest-Key-ID"] == "fresh-app-attest-key")
    #expect(headers["X-App-Attest-Assertion"] == Data([0xB2]).base64EncodedString())
    #expect(suite.defaults.string(forKey: defaultsKey(for: configuration)) == "fresh-app-attest-key")
    #expect(try await secureStore.string(for: legacyAccount) == nil)
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(await service.assertionKeys() == ["fresh-app-attest-key"])
    #expect(await transport.requestCount() == 3)
    #expect(
        requests.allSatisfy {
            $0.value(forHTTPHeaderField: "X-Installation-ID")
                == "installation-kept-in-keychain"
        }
    )
}

@Test func existingLocalKeyIsReusedWithoutRegisteringAnotherKey() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-existing-key-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set("existing-app-attest-key", forKey: defaultsKey(for: configuration))

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService()
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    let headers = try await provider.headers(for: appAttestRequest())

    #expect(headers["X-App-Attest-Key-ID"] == "existing-app-attest-key")
    #expect(await service.generatedKeyCount() == 0)
    #expect(await service.attestedKeys().isEmpty)
    #expect(await service.assertionKeys() == ["existing-app-attest-key"])
    #expect(await transport.requestCount() == 1)
}

@Test func invalidLocalAppAttestKeyIsRotatedOnce() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-key-rotation-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set("stale-app-attest-key", forKey: defaultsKey(for: configuration))

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(invalidAssertionFailures: 1)
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    let headers = try await provider.headers(for: appAttestRequest())

    #expect(headers["X-App-Attest-Key-ID"] == "fresh-app-attest-key")
    #expect(suite.defaults.string(forKey: defaultsKey(for: configuration)) == "fresh-app-attest-key")
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)
}

@Test func invalidFreshAppAttestKeyDoesNotCreateARecoveryLoop() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-no-loop-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set("stale-app-attest-key", forKey: defaultsKey(for: configuration))

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(invalidAssertionFailures: 2)
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
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

    #expect(suite.defaults.string(forKey: defaultsKey(for: configuration)) == nil)
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)
}
