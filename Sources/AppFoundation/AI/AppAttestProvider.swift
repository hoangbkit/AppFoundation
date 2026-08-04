import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(DeviceCheck) && os(iOS)
import DeviceCheck
#endif

enum AppleAppAttestServiceError: LocalizedError, Equatable, Sendable {
    case invalidKey(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey(let message):
            message
        }
    }
}

protocol AppleAppAttestServicing: Sendable {
    func isSupported() async -> Bool
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

struct SystemAppleAppAttestService: AppleAppAttestServicing {
    func isSupported() async -> Bool {
        #if canImport(DeviceCheck) && os(iOS)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }

    func generateKey() async throws -> String {
        #if canImport(DeviceCheck) && os(iOS)
        do {
            return try await DCAppAttestService.shared.generateKey()
        } catch {
            throw Self.normalized(error)
        }
        #else
        throw AppAIError.attestationUnavailable
        #endif
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck) && os(iOS)
        do {
            return try await DCAppAttestService.shared.attestKey(
                keyID,
                clientDataHash: clientDataHash
            )
        } catch {
            throw Self.normalized(error)
        }
        #else
        throw AppAIError.attestationUnavailable
        #endif
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck) && os(iOS)
        do {
            return try await DCAppAttestService.shared.generateAssertion(
                keyID,
                clientDataHash: clientDataHash
            )
        } catch {
            throw Self.normalized(error)
        }
        #else
        throw AppAIError.attestationUnavailable
        #endif
    }

    private static func normalized(_ error: Error) -> Error {
        #if canImport(DeviceCheck) && os(iOS)
        let nsError = error as NSError
        if nsError.domain == DCError.errorDomain,
           nsError.code == DCError.Code.invalidKey.rawValue {
            return AppleAppAttestServiceError.invalidKey(error.localizedDescription)
        }
        #endif
        return error
    }
}

actor AppleAppAttestationProvider: AppAIAttestationProviding {
    private struct ChallengeResponse: Decodable {
        let challengeId: String
        let challenge: String
        let expiresAt: Date
    }

    private struct ChallengeRequest: Encodable {
        let purpose: String
        let requestId: String?
        let method: String?
        let path: String?
        let bodyHash: String?
    }

    private struct RegisterRequest: Encodable {
        let challengeId: String
        let challenge: String
        let keyId: String
        let attestationObject: String
    }

    private struct RegisteredKey {
        let id: String
        let cameFromLocalStore: Bool
    }

    private let configuration: AppAIClientConfiguration
    private let installationID: String
    private let transport: any AppAITransport
    private let secureStore: AppAISecureStore
    private let appAttestService: any AppleAppAttestServicing
    private let appAttestDefaultsSuiteName: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: AppAIClientConfiguration,
        installationID: String,
        transport: any AppAITransport,
        secureStore: AppAISecureStore,
        appAttestService: any AppleAppAttestServicing = SystemAppleAppAttestService(),
        appAttestDefaultsSuiteName: String? = nil
    ) {
        self.configuration = configuration
        self.installationID = installationID
        self.transport = transport
        self.secureStore = secureStore
        self.appAttestService = appAttestService
        self.appAttestDefaultsSuiteName = appAttestDefaultsSuiteName
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
    }

    func headers(for request: AppAIAttestationRequest) async throws -> [String: String] {
        guard configuration.attestationPolicy != .disabled else { return [:] }
        guard await appAttestService.isSupported() else {
            if configuration.attestationPolicy == .required {
                throw AppAIError.attestationUnavailable
            }
            return [:]
        }

        do {
            return try await assertionHeaders(
                for: request,
                allowsLocalKeyRecovery: true
            )
        } catch {
            if configuration.attestationPolicy == .preferred { return [:] }
            if let error = error as? AppAIError { throw error }
            throw AppAIError.attestationFailed(error.localizedDescription)
        }
    }

    func resetKey() async throws {
        appAttestDefaults.removeObject(forKey: keyDefaultsKey)
        try await secureStore.remove(legacyKeyAccount)
    }

    private var keyDefaultsKey: String {
        "\(configuration.keychainService).\(configuration.appID).app-attest-key"
    }

    private var legacyKeyAccount: String {
        "\(configuration.appID).app-attest-key"
    }

    private var appAttestDefaults: UserDefaults {
        guard let appAttestDefaultsSuiteName else { return .standard }
        return UserDefaults(suiteName: appAttestDefaultsSuiteName) ?? .standard
    }

    private func assertionHeaders(
        for request: AppAIAttestationRequest,
        allowsLocalKeyRecovery: Bool
    ) async throws -> [String: String] {
        let registeredKey = try await registeredKey()
        let bodyHash = Self.base64URL(Self.sha256(request.body))
        let challenge = try await fetchChallenge(
            ChallengeRequest(
                purpose: "assert",
                requestId: request.requestID,
                method: request.method,
                path: request.path,
                bodyHash: bodyHash
            )
        )
        let timestamp = Int64(Date().timeIntervalSince1970 * 1_000)
        let clientData = try Self.canonicalClientData(
            appID: configuration.appID,
            bodyHash: bodyHash,
            challenge: challenge.challenge,
            challengeID: challenge.challengeId,
            method: request.method,
            path: request.path,
            requestID: request.requestID,
            timestamp: timestamp
        )

        let assertion: Data
        do {
            assertion = try await appAttestService.generateAssertion(
                registeredKey.id,
                clientDataHash: Self.sha256(clientData)
            )
        } catch let error as AppleAppAttestServiceError {
            guard case .invalidKey = error else {
                throw errorAsAttestationFailure(error)
            }

            appAttestDefaults.removeObject(forKey: keyDefaultsKey)

            guard allowsLocalKeyRecovery,
                  registeredKey.cameFromLocalStore else {
                throw errorAsAttestationFailure(error)
            }

            // The locally cached identifier can become unusable after restore or
            // unusual device state. Register a fresh key and retry this logical
            // request once with a fresh one-time challenge.
            return try await assertionHeaders(
                for: request,
                allowsLocalKeyRecovery: false
            )
        } catch {
            throw errorAsAttestationFailure(error)
        }

        return [
            "X-App-Attest-Key-ID": registeredKey.id,
            "X-App-Attest-Challenge-ID": challenge.challengeId,
            "X-App-Attest-Challenge": challenge.challenge,
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
            "X-App-Attest-Timestamp": String(timestamp),
        ]
    }

    private func registeredKey() async throws -> RegisteredKey {
        if let stored = appAttestDefaults.string(forKey: keyDefaultsKey),
           !stored.isEmpty {
            return RegisteredKey(id: stored, cameFromLocalStore: true)
        }

        // Older AppFoundation builds cached this identifier in Keychain. Ignore
        // and clean that legacy value: it can outlive an uninstall even though
        // the underlying App Attest key does not.
        try? await secureStore.remove(legacyKeyAccount)

        let keyID = try await appAttestService.generateKey()
        let challenge = try await fetchChallenge(
            ChallengeRequest(
                purpose: "register",
                requestId: nil,
                method: nil,
                path: nil,
                bodyHash: nil
            )
        )
        guard let challengeData = Data(base64URL: challenge.challenge) else {
            throw AppAIError.invalidResponse
        }

        let attestation: Data
        do {
            attestation = try await appAttestService.attestKey(
                keyID,
                clientDataHash: Self.sha256(challengeData)
            )
        } catch {
            throw errorAsAttestationFailure(error)
        }

        let body = RegisterRequest(
            challengeId: challenge.challengeId,
            challenge: challenge.challenge,
            keyId: keyID,
            attestationObject: attestation.base64EncodedString()
        )
        _ = try await send(
            path: "/v1/attest/register",
            body: body,
            response: EmptyResponse.self
        )
        appAttestDefaults.set(keyID, forKey: keyDefaultsKey)
        return RegisteredKey(id: keyID, cameFromLocalStore: false)
    }

    private func fetchChallenge(_ body: ChallengeRequest) async throws -> ChallengeResponse {
        try await send(
            path: "/v1/attest/challenge",
            body: body,
            response: ChallengeResponse.self
        )
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        response: Response.Type
    ) async throws -> Response {
        let data = try encoder.encode(body)
        var request = URLRequest(
            url: AppAIClient.endpointURL(baseURL: configuration.baseURL, path: path)
        )
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.appID, forHTTPHeaderField: "X-App-ID")
        request.setValue(configuration.appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            (responseData, httpResponse) = try await transport.data(for: request)
        } catch let error as AppAIError {
            throw error
        } catch {
            throw AppAIError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppAIClient.decodeServerError(
                data: responseData,
                response: httpResponse,
                decoder: decoder
            )
        }
        guard let decoded = try? decoder.decode(Response.self, from: responseData) else {
            throw AppAIError.invalidResponse
        }
        return decoded
    }

    private func errorAsAttestationFailure(_ error: Error) -> Error {
        if let error = error as? AppAIError { return error }
        return AppAIError.attestationFailed(error.localizedDescription)
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

    private static func sha256(_ data: Data) -> Data {
        #if canImport(CryptoKit)
        Data(SHA256.hash(data: data))
        #else
        fatalError("CryptoKit is required on Apple platforms")
        #endif
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func canonicalClientData(
        appID: String,
        bodyHash: String,
        challenge: String,
        challengeID: String,
        method: String,
        path: String,
        requestID: String,
        timestamp: Int64
    ) throws -> Data {
        let values: [String: Any] = [
            "appId": appID,
            "bodyHash": bodyHash,
            "challenge": challenge,
            "challengeId": challengeID,
            "method": method,
            "path": path,
            "requestId": requestID,
            "timestamp": timestamp,
            "version": 1,
        ]
        return try JSONSerialization.data(
            withJSONObject: values,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }
}

private struct EmptyResponse: Decodable {}

private extension Data {
    init?(base64URL value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized += String(
            repeating: "=",
            count: (4 - normalized.count % 4) % 4
        )
        self.init(base64Encoded: normalized)
    }
}
