import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(StoreKit)
import StoreKit
#endif

private actor AppAIProcessGate {
    static let shared = AppAIProcessGate()

    private var lockedKeys: Set<String> = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func acquire(_ key: String) async {
        if lockedKeys.insert(key).inserted { return }
        await withCheckedContinuation { continuation in
            waiters[key, default: []].append(continuation)
        }
    }

    func release(_ key: String) {
        guard lockedKeys.contains(key) else { return }
        guard var queued = waiters[key], !queued.isEmpty else {
            lockedKeys.remove(key)
            waiters.removeValue(forKey: key)
            return
        }

        let next = queued.removeFirst()
        if queued.isEmpty {
            waiters.removeValue(forKey: key)
        } else {
            waiters[key] = queued
        }
        next.resume()
    }
}

public actor AppAIClient {
    private struct GenerateEnvelope<Input: Encodable>: Encodable {
        let requestId: String
        let capability: String
        let input: Input
    }

    private struct ServerErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
            let retryAfter: String?
        }
        let error: Detail
    }

    private let configuration: AppAIClientConfiguration
    private let transport: any AppAITransport
    private let secureStore: AppAISecureStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let injectedAttestationProvider: (any AppAIAttestationProviding)?

    public init(
        configuration: AppAIClientConfiguration,
        transport: any AppAITransport = URLSessionAppAITransport(),
        attestationProvider: (any AppAIAttestationProviding)? = nil
    ) {
        self.configuration = configuration
        self.transport = transport
        self.secureStore = AppAISecureStore(service: configuration.keychainService)
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
        self.injectedAttestationProvider = attestationProvider
    }

    public func status() async throws -> AppAIStatus {
        let installationID = try await installationID()
        var request = try baseRequest(
            path: "/v1/status",
            method: "GET",
            installationID: installationID
        )
        request.setValue(nil, forHTTPHeaderField: "Content-Type")
        return try await perform(request, as: AppAIStatus.self)
    }

    public func prepareAttestation() async throws {
        guard configuration.attestationPolicy != .disabled else { return }
        let gateKey = attestationGateKey
        await AppAIProcessGate.shared.acquire(gateKey)
        do {
            try Task.checkCancellation()
            let installationID = try await installationID()
            let provider = resolvedAttestationProvider(
                installationID: installationID
            )
            try await provider?.prepare()
            await AppAIProcessGate.shared.release(gateKey)
        } catch {
            await AppAIProcessGate.shared.release(gateKey)
            throw error
        }
    }

    public func syncEntitlements(
        transactions: [String],
        requestID: String = UUID().uuidString
    ) async throws -> AppAIEntitlementSyncResult {
        guard !transactions.isEmpty, transactions.count <= 20 else {
            throw AppAIError.invalidConfiguration(
                "transactions must contain between 1 and 20 StoreKit JWS values."
            )
        }
        struct Envelope: Encodable {
            let requestId: String
            let transactions: [String]
        }
        let body = try encoder.encode(
            Envelope(requestId: requestID, transactions: transactions)
        )
        return try await protectedPost(
            path: "/v1/entitlements/sync",
            requestID: requestID,
            body: body,
            as: AppAIEntitlementSyncResult.self
        )
    }

    #if canImport(StoreKit)
    public func syncCurrentEntitlements() async throws -> AppAIStatus {
        var transactions: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified = result else { continue }
            transactions.append(result.jwsRepresentation)
        }
        for batch in Self.entitlementBatches(transactions) {
            _ = try await syncEntitlements(transactions: batch)
        }
        return try await status()
    }
    #endif

    public func generate<Input: Encodable & Sendable, Output: Decodable & Sendable>(
        capability: String,
        input: Input,
        requestID: String = UUID().uuidString,
        as outputType: Output.Type = Output.self
    ) async throws -> AppAIResponse<Output> {
        guard !capability.isEmpty else {
            throw AppAIError.invalidConfiguration("capability must not be empty.")
        }
        let body = try encoder.encode(
            GenerateEnvelope(
                requestId: requestID,
                capability: capability,
                input: input
            )
        )
        return try await protectedPost(
            path: "/v1/ai/generate",
            requestID: requestID,
            body: body,
            as: AppAIResponse<Output>.self
        )
    }

    public func resetInstallationIdentity() async throws {
        let attestationKey = attestationGateKey
        let identityKey = installationGateKey
        await AppAIProcessGate.shared.acquire(attestationKey)
        do {
            try Task.checkCancellation()
            await AppAIProcessGate.shared.acquire(identityKey)
            do {
                try Task.checkCancellation()
                if let injectedAttestationProvider {
                    try await injectedAttestationProvider.resetKey()
                } else {
                    let provider = AppleAppAttestationProvider(
                        configuration: configuration,
                        installationID: "",
                        transport: transport,
                        secureStore: secureStore
                    )
                    try await provider.resetKey()
                }

                try await secureStore.remove(installationAccount)
                await AppAIProcessGate.shared.release(identityKey)
            } catch {
                await AppAIProcessGate.shared.release(identityKey)
                throw error
            }
            await AppAIProcessGate.shared.release(attestationKey)
        } catch {
            await AppAIProcessGate.shared.release(attestationKey)
            throw error
        }
    }

    private var installationAccount: String {
        "\(configuration.appID).installation"
    }

    private var installationGateKey: String {
        "installation|\(configuration.keychainService)|\(configuration.appID)"
    }

    private var attestationGateKey: String {
        "attestation|\(configuration.keychainService)|\(configuration.appID)"
    }

    private func installationID() async throws -> String {
        let gateKey = installationGateKey
        await AppAIProcessGate.shared.acquire(gateKey)
        do {
            try Task.checkCancellation()
            let value: String
            if let stored = try await secureStore.string(for: installationAccount) {
                value = stored
            } else {
                let generated = UUID().uuidString.lowercased()
                try await secureStore.set(generated, for: installationAccount)
                value = generated
            }

            await AppAIProcessGate.shared.release(gateKey)
            return value
        } catch {
            await AppAIProcessGate.shared.release(gateKey)
            throw error
        }
    }

    private func resolvedAttestationProvider(
        installationID: String
    ) -> (any AppAIAttestationProviding)? {
        guard configuration.attestationPolicy != .disabled else { return nil }
        if let injectedAttestationProvider { return injectedAttestationProvider }

        return AppleAppAttestationProvider(
            configuration: configuration,
            installationID: installationID,
            transport: transport,
            secureStore: secureStore
        )
    }

    private func baseRequest(
        path: String,
        method: String,
        installationID: String
    ) throws -> URLRequest {
        guard configuration.baseURL.scheme == "https"
                || configuration.baseURL.host == "localhost" else {
            throw AppAIError.invalidConfiguration("baseURL must use HTTPS.")
        }
        var request = URLRequest(
            url: Self.endpointURL(baseURL: configuration.baseURL, path: path)
        )
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.appID, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            request.setValue(version, forHTTPHeaderField: "X-App-Version")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            request.setValue(build, forHTTPHeaderField: "X-App-Build")
        }
        return request
    }

    private func protectedPost<Response: Decodable & Sendable>(
        path: String,
        requestID: String,
        body: Data,
        as type: Response.Type
    ) async throws -> Response {
        guard configuration.attestationPolicy != .disabled else {
            let installationID = try await installationID()
            return try await protectedPostLoop(
                path: path,
                requestID: requestID,
                body: body,
                installationID: installationID,
                provider: nil,
                as: type
            )
        }

        // App Attest assertions contain a strictly increasing counter. Acquire
        // this gate before reading the installation identity so a concurrent reset
        // cannot clear the identity and then allow a queued request to use its old
        // value. Reset follows the same attestation-then-identity lock order.
        let gateKey = attestationGateKey
        await AppAIProcessGate.shared.acquire(gateKey)
        do {
            try Task.checkCancellation()
            let installationID = try await installationID()
            let provider = resolvedAttestationProvider(
                installationID: installationID
            )
            let result = try await protectedPostLoop(
                path: path,
                requestID: requestID,
                body: body,
                installationID: installationID,
                provider: provider,
                as: type
            )
            await AppAIProcessGate.shared.release(gateKey)
            return result
        } catch {
            await AppAIProcessGate.shared.release(gateKey)
            throw error
        }
    }

    private func protectedPostLoop<Response: Decodable & Sendable>(
        path: String,
        requestID: String,
        body: Data,
        installationID: String,
        provider: (any AppAIAttestationProviding)?,
        as type: Response.Type
    ) async throws -> Response {
        var didResetUnknownKey = false
        var didRetryRejectedAssertion = false
        var transportAttempts = 0

        while true {
            try Task.checkCancellation()
            var request = try baseRequest(
                path: path,
                method: "POST",
                installationID: installationID
            )
            request.httpBody = body

            if let provider {
                let headers = try await provider.headers(
                    for: AppAIAttestationRequest(
                        requestID: requestID,
                        method: "POST",
                        path: path,
                        body: body
                    )
                )
                for (name, value) in headers {
                    request.setValue(value, forHTTPHeaderField: name)
                }
            }

            do {
                return try await perform(request, as: type)
            } catch AppAIError.server(let code, _, _)
                where code == "attestation_key_not_registered"
                    && !didResetUnknownKey {
                didResetUnknownKey = true
                try await provider?.resetKey()
            } catch AppAIError.server(let code, _, _)
                where (code == "attestation_replayed"
                       || code == "attestation_counter_stale")
                    && !didRetryRejectedAssertion {
                didRetryRejectedAssertion = true
                // Obtain a fresh one-time challenge and a higher assertion counter.
            } catch AppAIError.transport
                where transportAttempts < configuration.transportRetryCount {
                transportAttempts += 1
                // Keep the logical request ID and exact body, but obtain a fresh
                // one-time assertion because the previous challenge may be consumed.
            }
        }
    }

    private func perform<Response: Decodable & Sendable>(
        _ request: URLRequest,
        as type: Response.Type
    ) async throws -> Response {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as AppAIError {
            throw error
        } catch {
            throw AppAIError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw Self.decodeServerError(
                data: data,
                response: response,
                decoder: decoder
            )
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AppAIError.invalidResponse
        }
    }

    static func decodeServerError(
        data: Data,
        response: HTTPURLResponse,
        decoder: JSONDecoder
    ) -> AppAIError {
        if let envelope = try? decoder.decode(ServerErrorEnvelope.self, from: data) {
            return .server(
                code: envelope.error.code,
                message: envelope.error.message,
                retryAfter: envelope.error.retryAfter
                    ?? response.value(forHTTPHeaderField: "Retry-After")
            )
        }
        return .server(
            code: "http_\(response.statusCode)",
            message: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
            retryAfter: response.value(forHTTPHeaderField: "Retry-After")
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func endpointURL(baseURL: URL, path: String) -> URL {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appending(path: relativePath)
    }

    static func entitlementBatches(_ transactions: [String]) -> [[String]] {
        stride(from: 0, to: transactions.count, by: 20).map { start in
            let end = min(start + 20, transactions.count)
            return Array(transactions[start..<end])
        }
    }
}
