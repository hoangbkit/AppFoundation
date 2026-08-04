import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor AppAttestTestTransport: AppAITransport {
    private var requests: [URLRequest] = []
    private var registerTransportFailuresRemaining: Int
    private let registerStatusCode: Int
    private let challengeLifetime: TimeInterval

    init(
        registerTransportFailures: Int = 0,
        registerStatusCode: Int = 200,
        challengeLifetime: TimeInterval = 3_600
    ) {
        self.registerTransportFailuresRemaining = registerTransportFailures
        self.registerStatusCode = registerStatusCode
        self.challengeLifetime = challengeLifetime
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)

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
                "expiresAt": ISO8601DateFormatter().string(
                    from: Date().addingTimeInterval(challengeLifetime)
                ),
            ]
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (try JSONSerialization.data(withJSONObject: payload), response)

        case "/v1/attest/register":
            if registerTransportFailuresRemaining > 0 {
                registerTransportFailuresRemaining -= 1
                throw URLError(.networkConnectionLost)
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: registerStatusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            if (200..<300).contains(registerStatusCode) {
                return (Data("{}".utf8), response)
            }
            return (
                Data(
                    #"{"error":{"code":"attestation_failed","message":"Registration rejected"}}"#.utf8
                ),
                response
            )

        default:
            Issue.record(
                "Unexpected App Attest request path: \(request.url?.path ?? "nil")"
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("{}".utf8), response)
        }
    }

    func requestCount() -> Int { requests.count }
    func capturedRequests() -> [URLRequest] { requests }
}

private actor AppAttestTestService: AppleAppAttestServicing {
    private let firstKeyID: String
    private var attestationFailures: [AppleAppAttestServiceError]
    private var assertionFailures: [AppleAppAttestServiceError]
    private var generateKeyCalls = 0
    private var attestedKeyIDs: [String] = []
    private var attestationHashes: [Data] = []
    private var assertionKeyIDs: [String] = []

    init(
        firstKeyID: String = "fresh-app-attest-key",
        attestationFailures: [AppleAppAttestServiceError] = [],
        assertionFailures: [AppleAppAttestServiceError] = []
    ) {
        self.firstKeyID = firstKeyID
        self.attestationFailures = attestationFailures
        self.assertionFailures = assertionFailures
    }

    func isSupported() async -> Bool { true }

    func generateKey() async throws -> String {
        generateKeyCalls += 1
        return generateKeyCalls == 1
            ? firstKeyID
            : "\(firstKeyID)-\(generateKeyCalls)"
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        attestedKeyIDs.append(keyID)
        attestationHashes.append(clientDataHash)
        if !attestationFailures.isEmpty {
            throw attestationFailures.removeFirst()
        }
        return Data([0xA1])
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        assertionKeyIDs.append(keyID)
        if !assertionFailures.isEmpty {
            throw assertionFailures.removeFirst()
        }
        return Data([0xB2])
    }

    func generatedKeyCount() -> Int { generateKeyCalls }
    func attestedKeys() -> [String] { attestedKeyIDs }
    func capturedAttestationHashes() -> [Data] { attestationHashes }
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

private func pendingDefaultsKey(for configuration: AppAIClientConfiguration) -> String {
    "\(configuration.keychainService).\(configuration.appID).app-attest-pending-registration.v1"
}

private func makeDefaultsSuite() throws -> (name: String, defaults: UserDefaults) {
    let name = "com.hoangbkit.AppFoundationTests.AppAttestDefaults.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return (name, defaults)
}

@Test func reinstallWithoutAnyLocalKeyRegistersAFreshAppAttestKey() async throws {
    let configuration = appAttestTestConfiguration()
    let secureStore = AppAISecureStore(service: configuration.keychainService)
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
    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "fresh-app-attest-key"
    )
    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) == nil)
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

@Test func validLegacyKeyMigratesWithoutGeneratingAnotherKey() async throws {
    let configuration = appAttestTestConfiguration(appID: "legacy-upgrade-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let legacyAccount = "\(configuration.appID).app-attest-key"
    try await secureStore.set("valid-legacy-key", for: legacyAccount)

    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

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

    #expect(headers["X-App-Attest-Key-ID"] == "valid-legacy-key")
    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "valid-legacy-key"
    )
    #expect(try await secureStore.string(for: legacyAccount) == nil)
    #expect(await service.generatedKeyCount() == 0)
    #expect(await service.attestedKeys().isEmpty)
    #expect(await service.assertionKeys() == ["valid-legacy-key"])
    #expect(await transport.requestCount() == 1)
}

@Test func staleLegacyKeyAfterReinstallMigratesThenRotatesOnce() async throws {
    let configuration = appAttestTestConfiguration(appID: "legacy-reinstall-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let legacyAccount = "\(configuration.appID).app-attest-key"
    try await secureStore.set("stale-legacy-key", for: legacyAccount)

    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        assertionFailures: [
            .invalidInput("The restored App Attest key is invalid.")
        ]
    )
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "installation-kept-in-keychain",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    let headers = try await provider.headers(for: appAttestRequest())

    #expect(headers["X-App-Attest-Key-ID"] == "fresh-app-attest-key")
    #expect(try await secureStore.string(for: legacyAccount) == nil)
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-legacy-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)
}

@Test func prepareRegistersAKeyWithoutGeneratingAnAssertion() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-prepare-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

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

    try await provider.prepare()

    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "fresh-app-attest-key"
    )
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(await service.assertionKeys().isEmpty)
    #expect(await transport.requestCount() == 2)
}

@Test func existingLocalKeyIsReusedWithoutRegisteringAnotherKey() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-existing-key-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set(
        "existing-app-attest-key",
        forKey: defaultsKey(for: configuration)
    )

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

@Test func transientAttestationFailureReusesTheSameKeyAndClientDataHash() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-transient-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        attestationFailures: [
            .serverUnavailable("Apple App Attest is temporarily unavailable.")
        ]
    )
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    do {
        try await provider.prepare()
        Issue.record("Expected the first attestation attempt to fail.")
    } catch let error as AppAIError {
        guard case .attestationFailed(let message) = error else {
            Issue.record("Expected attestationFailed, received \(error).")
            return
        }
        #expect(message.contains("attestKey"))
        #expect(message.contains("serverUnavailable"))
    }

    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) != nil)

    try await provider.prepare()

    let hashes = await service.capturedAttestationHashes()
    #expect(await service.generatedKeyCount() == 1)
    #expect(
        await service.attestedKeys()
            == ["fresh-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(hashes.count == 2)
    #expect(hashes[0] == hashes[1])
    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "fresh-app-attest-key"
    )
    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) == nil)
    #expect(await transport.requestCount() == 2)
}

@Test func nonTransientAttestationFailureDiscardsPendingKey() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-discard-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        attestationFailures: [
            .unknownSystemFailure("Apple rejected the pending key."),
        ]
    )
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    do {
        try await provider.prepare()
        Issue.record("Expected the first attestation attempt to fail.")
    } catch {
        #expect(error is AppAIError)
    }

    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) == nil)

    try await provider.prepare()

    #expect(await service.generatedKeyCount() == 2)
    #expect(
        await service.attestedKeys()
            == ["fresh-app-attest-key", "fresh-app-attest-key-2"]
    )
}

@Test func uncertainRegistrationResponseDoesNotReattestTheSameKey() async throws {
    let configuration = appAttestTestConfiguration(
        appID: "app-attest-register-uncertain-test"
    )
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport(registerTransportFailures: 1)
    let service = AppAttestTestService()
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    do {
        try await provider.prepare()
        Issue.record("Expected the registration response to be lost.")
    } catch let error as AppAIError {
        guard case .transport = error else {
            Issue.record("Expected transport error, received \(error).")
            return
        }
    }

    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "fresh-app-attest-key"
    )
    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) == nil)

    let headers = try await provider.headers(for: appAttestRequest())

    #expect(headers["X-App-Attest-Key-ID"] == "fresh-app-attest-key")
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(await service.assertionKeys() == ["fresh-app-attest-key"])
}

@Test func definiteRegistrationRejectionDiscardsTheKey() async throws {
    let configuration = appAttestTestConfiguration(appID: "register-rejection-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }

    let transport = AppAttestTestTransport(registerStatusCode: 401)
    let service = AppAttestTestService()
    let provider = AppleAppAttestationProvider(
        configuration: configuration,
        installationID: "stable-installation",
        transport: transport,
        secureStore: secureStore,
        appAttestService: service,
        appAttestDefaultsSuiteName: suite.name
    )

    do {
        try await provider.prepare()
        Issue.record("Expected server registration rejection.")
    } catch let error as AppAIError {
        guard case .server(let code, _, _) = error else {
            Issue.record("Expected server error, received \(error).")
            return
        }
        #expect(code == "attestation_failed")
    }

    #expect(suite.defaults.string(forKey: defaultsKey(for: configuration)) == nil)
    #expect(suite.defaults.data(forKey: pendingDefaultsKey(for: configuration)) == nil)
}

@Test func invalidLocalAppAttestKeyIsRotatedOnce() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-key-rotation-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set(
        "stale-app-attest-key",
        forKey: defaultsKey(for: configuration)
    )

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        assertionFailures: [
            .invalidKey("The App Attest key is invalid.")
        ]
    )
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
    #expect(
        suite.defaults.string(forKey: defaultsKey(for: configuration))
            == "fresh-app-attest-key"
    )
    #expect(await service.generatedKeyCount() == 1)
    #expect(await service.attestedKeys() == ["fresh-app-attest-key"])
    #expect(
        await service.assertionKeys()
            == ["stale-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)
}

@Test func invalidInputFromCachedAssertionKeyIsAlsoRotatedOnce() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-invalid-input-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set(
        "restored-app-attest-key",
        forKey: defaultsKey(for: configuration)
    )

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        assertionFailures: [
            .invalidInput("The App Attest input is invalid.")
        ]
    )
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
    #expect(await service.generatedKeyCount() == 1)
    #expect(
        await service.assertionKeys()
            == ["restored-app-attest-key", "fresh-app-attest-key"]
    )
    #expect(await transport.requestCount() == 4)
}

@Test func invalidFreshAppAttestKeyDoesNotCreateARecoveryLoop() async throws {
    let configuration = appAttestTestConfiguration(appID: "app-attest-no-loop-test")
    let secureStore = AppAISecureStore(service: configuration.keychainService)
    let suite = try makeDefaultsSuite()
    defer { suite.defaults.removePersistentDomain(forName: suite.name) }
    suite.defaults.set(
        "stale-app-attest-key",
        forKey: defaultsKey(for: configuration)
    )

    let transport = AppAttestTestTransport()
    let service = AppAttestTestService(
        assertionFailures: [
            .invalidKey("The cached App Attest key is invalid."),
            .invalidKey("The fresh App Attest key is invalid."),
        ]
    )
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
    case .attestationFailed(let message):
        #expect(message.contains("generateAssertion"))
        #expect(message.contains("invalidKey"))
    default:
        Issue.record(
            "Expected attestationFailed, received \(String(describing: capturedError))."
        )
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
