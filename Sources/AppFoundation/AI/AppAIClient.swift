import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(StoreKit)
import StoreKit
#endif

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
    private var installationIDCache: String?
    private var defaultAttestationProvider: (any AppAIAttestationProviding)?

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
        self.defaultAttestationProvider = nil
    }

    public func status() async throws -> AppAIStatus {
        let installationID = try await installationID()
        var request = try baseRequest(path: "/v1/status", method: "GET", installationID: installationID)
        request.setValue(nil, forHTTPHeaderField: "Content-Type")
        return try await perform(request, as: AppAIStatus.self)
    }

    public func syncEntitlements(
        transactions: [String],
        requestID: String = UUID().uuidString
    ) async throws -> AppAIEntitlementSyncResult {
        guard !transactions.isEmpty, transactions.count <= 20 else {
            throw AppAIError.invalidConfiguration("transactions must contain between 1 and 20 StoreKit JWS values.")
        }
        struct Envelope: Encodable {
            let requestId: String
            let transactions: [String]
        }
        let body = try encoder.encode(Envelope(requestId: requestID, transactions: transactions))
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
        guard !capability.isEmpty else { throw AppAIError.invalidConfiguration("capability must not be empty.") }
        let body = try encoder.encode(GenerateEnvelope(requestId: requestID, capability: capability, input: input))
        return try await protectedPost(
            path: "/v1/ai/generate",
            requestID: requestID,
            body: body,
            as: AppAIResponse<Output>.self
        )
    }

    public func resetInstallationIdentity() async throws {
        try await injectedAttestationProvider?.resetKey()
        try await defaultAttestationProvider?.resetKey()
        try await secureStore.remove(installationAccount)
        installationIDCache = nil
        defaultAttestationProvider = nil
    }

    private var installationAccount: String { "\(configuration.appID).installation" }

    private func installationID() async throws -> String {
        if let installationIDCache { return installationIDCache }
        if let stored = try await secureStore.string(for: installationAccount) {
            installationIDCache = stored
            return stored
        }
        let value = UUID().uuidString.lowercased()
        try await secureStore.set(value, for: installationAccount)
        installationIDCache = value
        return value
    }

    private func resolvedAttestationProvider(installationID: String) async throws -> (any AppAIAttestationProviding)? {
        guard configuration.attestationPolicy != .disabled else { return nil }
        if let injectedAttestationProvider { return injectedAttestationProvider }
        if let defaultAttestationProvider { return defaultAttestationProvider }
        let provider = AppleAppAttestationProvider(
            configuration: configuration,
            installationID: installationID,
            transport: transport,
            secureStore: secureStore
        )
        defaultAttestationProvider = provider
        return provider
    }

    private func baseRequest(path: String, method: String, installationID: String) throws -> URLRequest {
        guard configuration.baseURL.scheme == "https" || configuration.baseURL.host == "localhost" else {
            throw AppAIError.invalidConfiguration("baseURL must use HTTPS.")
        }
        var request = URLRequest(url: Self.endpointURL(baseURL: configuration.baseURL, path: path))
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


    private func protectedPost<Response: Decodable>(
        path: String,
        requestID: String,
        body: Data,
        as type: Response.Type
    ) async throws -> Response {
        let installationID = try await installationID()
        let provider = try await resolvedAttestationProvider(installationID: installationID)
        var didResetUnknownKey = false
        var transportAttempts = 0

        while true {
            var request = try baseRequest(path: path, method: "POST", installationID: installationID)
            request.httpBody = body
            if let provider {
                let headers = try await provider.headers(for: AppAIAttestationRequest(
                    requestID: requestID,
                    method: "POST",
                    path: path,
                    body: body
                ))
                for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
            }
            do {
                return try await perform(request, as: type)
            } catch AppAIError.server(let code, _, _) where code == "attestation_key_not_registered" && !didResetUnknownKey {
                didResetUnknownKey = true
                try await provider?.resetKey()
            } catch AppAIError.transport where transportAttempts < configuration.transportRetryCount {
                transportAttempts += 1
                // Keep the logical request ID and exact body, but obtain a fresh one-time assertion.
            }
        }
    }

    private func perform<Response: Decodable>(_ request: URLRequest, as type: Response.Type) async throws -> Response {
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch let error as AppAIError { throw error }
        catch { throw AppAIError.transport(error.localizedDescription) }

        guard (200..<300).contains(response.statusCode) else {
            throw Self.decodeServerError(data: data, response: response, decoder: decoder)
        }
        do { return try decoder.decode(type, from: data) }
        catch { throw AppAIError.invalidResponse }
    }

    static func decodeServerError(data: Data, response: HTTPURLResponse, decoder: JSONDecoder) -> AppAIError {
        if let envelope = try? decoder.decode(ServerErrorEnvelope.self, from: data) {
            return .server(
                code: envelope.error.code,
                message: envelope.error.message,
                retryAfter: envelope.error.retryAfter ?? response.value(forHTTPHeaderField: "Retry-After")
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
