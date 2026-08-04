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
    case featureUnsupported(String)
    case invalidInput(String)
    case invalidKey(String)
    case serverUnavailable(String)
    case unknownSystemFailure(String)
    case deviceCheck(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .featureUnsupported(let message),
             .invalidInput(let message),
             .invalidKey(let message),
             .serverUnavailable(let message),
             .unknownSystemFailure(let message):
            message
        case .deviceCheck(_, let message):
            message
        }
    }

    var diagnosticCode: String {
        switch self {
        case .featureUnsupported:
            "featureUnsupported"
        case .invalidInput:
            "invalidInput"
        case .invalidKey:
            "invalidKey"
        case .serverUnavailable:
            "serverUnavailable"
        case .unknownSystemFailure:
            "unknownSystemFailure"
        case .deviceCheck(let code, _):
            "deviceCheck_\(code)"
        }
    }

    var shouldRotateCachedAssertionKey: Bool {
        switch self {
        case .invalidKey, .invalidInput:
            true
        default:
            false
        }
    }

    var shouldDiscardPendingRegistration: Bool {
        switch self {
        case .invalidKey, .invalidInput:
            true
        default:
            false
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
        } catch is CancellationError {
            throw CancellationError()
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
        } catch is CancellationError {
            throw CancellationError()
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
        } catch is CancellationError {
            throw CancellationError()
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
        guard nsError.domain == DCError.errorDomain else { return error }

        switch nsError.code {
        case DCError.Code.featureUnsupported.rawValue:
            return AppleAppAttestServiceError.featureUnsupported(error.localizedDescription)
        case DCError.Code.invalidInput.rawValue:
            return AppleAppAttestServiceError.invalidInput(error.localizedDescription)
        case DCError.Code.invalidKey.rawValue:
            return AppleAppAttestServiceError.invalidKey(error.localizedDescription)
        case DCError.Code.serverUnavailable.rawValue:
            return AppleAppAttestServiceError.serverUnavailable(error.localizedDescription)
        case DCError.Code.unknownSystemFailure.rawValue:
            return AppleAppAttestServiceError.unknownSystemFailure(error.localizedDescription)
        default:
            return AppleAppAttestServiceError.deviceCheck(
                code: nsError.code,
                message: error.localizedDescription
            )
        }
        #else
        return error
        #endif
    }
}

actor AppleAppAttestationProvider: AppAIAttestationProviding {
    private struct ChallengeResponse: Codable, Sendable {
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

    private struct RegisteredKey: Sendable {
        let id: String
        let cameFromLocalStore: Bool
    }

    private struct PendingRegistration: Codable, Sendable {
        let keyID: String
        let challenge: ChallengeResponse
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

    func prepare() async throws {
        guard configuration.attestationPolicy != .disabled else { return }
        guard await appAttestService.isSupported() else {
            if configuration.attestationPolicy == .required {
                throw AppAIError.attestationUnavailable
            }
            return
        }

        do {
            _ = try await registeredKey()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if configuration.attestationPolicy == .preferred { return }
            throw publicError(from: error)
        }
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
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if configuration.attestationPolicy == .preferred { return [:] }
            throw publicError(from: error)
        }
    }

    func resetKey() async throws {
        clearRegisteredKey()
        clearPendingRegistration()
        try await secureStore.remove(legacyKeyAccount)
    }

    private var keyDefaultsKey: String {
        "\(configuration.keychainService).\(configuration.appID).app-attest-key"
    }

    private var pendingRegistrationDefaultsKey: String {
        "\(configuration.keychainService).\(configuration.appID).app-attest-pending-registration.v1"
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
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppleAppAttestServiceError {
            guard error.shouldRotateCachedAssertionKey else {
                throw errorAsAttestationFailure(error, stage: "generateAssertion")
            }

            clearRegisteredKey()
            clearPendingRegistration()

            guard allowsLocalKeyRecovery,
                  registeredKey.cameFromLocalStore else {
                throw errorAsAttestationFailure(error, stage: "generateAssertion")
            }

            // A restored or otherwise stale local identifier can surface as either
            // invalidKey or invalidInput on real devices. Rotate once only, then
            // retry this logical request with a fresh key and challenge.
            return try await assertionHeaders(
                for: request,
                allowsLocalKeyRecovery: false
            )
        } catch {
            throw errorAsAttestationFailure(error, stage: "generateAssertion")
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

        // Preserve a valid key during the one-time migration from older
        // AppFoundation versions. After a reinstall the migrated identifier is
        // stale, and the bounded invalidKey/invalidInput recovery above rotates it.
        if let legacy = try await secureStore.string(for: legacyKeyAccount),
           !legacy.isEmpty {
            appAttestDefaults.set(legacy, forKey: keyDefaultsKey)
            try await secureStore.remove(legacyKeyAccount)
            return RegisteredKey(id: legacy, cameFromLocalStore: true)
        }

        try? await secureStore.remove(legacyKeyAccount)
        return try await registerNewKey()
    }

    private func registerNewKey() async throws -> RegisteredKey {
        let pending = try await resolvedPendingRegistration()
        guard let challengeData = Data(base64URL: pending.challenge.challenge) else {
            clearPendingRegistration()
            throw AppAIError.invalidResponse
        }

        let attestation: Data
        do {
            attestation = try await appAttestService.attestKey(
                pending.keyID,
                clientDataHash: Self.sha256(challengeData)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppleAppAttestServiceError {
            if error.shouldDiscardPendingRegistration {
                clearPendingRegistration()
            }
            throw errorAsAttestationFailure(error, stage: "attestKey")
        } catch {
            throw errorAsAttestationFailure(error, stage: "attestKey")
        }

        let body = RegisterRequest(
            challengeId: pending.challenge.challengeId,
            challenge: pending.challenge.challenge,
            keyId: pending.keyID,
            attestationObject: attestation.base64EncodedString()
        )

        // Once Apple has attested the key, remember it before contacting the app
        // server. If the response is lost after the server commits registration,
        // the next assertion can still prove whether registration succeeded. The
        // client's unknown-key recovery handles the opposite outcome.
        appAttestDefaults.set(pending.keyID, forKey: keyDefaultsKey)
        clearPendingRegistration()

        _ = try await send(
            path: "/v1/attest/register",
            body: body,
            response: EmptyResponse.self
        )
        return RegisteredKey(id: pending.keyID, cameFromLocalStore: false)
    }

    private func resolvedPendingRegistration() async throws -> PendingRegistration {
        if let pending = loadPendingRegistration() {
            if pending.challenge.expiresAt.timeIntervalSinceNow > 1 {
                return pending
            }

            let challenge = try await fetchChallenge(
                ChallengeRequest(
                    purpose: "register",
                    requestId: nil,
                    method: nil,
                    path: nil,
                    bodyHash: nil
                )
            )
            let refreshed = PendingRegistration(
                keyID: pending.keyID,
                challenge: challenge
            )
            try savePendingRegistration(refreshed)
            return refreshed
        }

        // Ask the app server to initiate registration before allocating a key.
        // This gives the server control over rollout and attestation request rate.
        let challenge = try await fetchChallenge(
            ChallengeRequest(
                purpose: "register",
                requestId: nil,
                method: nil,
                path: nil,
                bodyHash: nil
            )
        )

        let keyID: String
        do {
            keyID = try await appAttestService.generateKey()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw errorAsAttestationFailure(error, stage: "generateKey")
        }

        let pending = PendingRegistration(keyID: keyID, challenge: challenge)
        try savePendingRegistration(pending)
        return pending
    }

    private func loadPendingRegistration() -> PendingRegistration? {
        guard let data = appAttestDefaults.data(forKey: pendingRegistrationDefaultsKey) else {
            return nil
        }
        guard let pending = try? decoder.decode(PendingRegistration.self, from: data),
              !pending.keyID.isEmpty,
              !pending.challenge.challengeId.isEmpty,
              !pending.challenge.challenge.isEmpty else {
            clearPendingRegistration()
            return nil
        }
        return pending
    }

    private func savePendingRegistration(_ pending: PendingRegistration) throws {
        let data = try encoder.encode(pending)
        appAttestDefaults.set(data, forKey: pendingRegistrationDefaultsKey)
    }

    private func clearRegisteredKey() {
        appAttestDefaults.removeObject(forKey: keyDefaultsKey)
    }

    private func clearPendingRegistration() {
        appAttestDefaults.removeObject(forKey: pendingRegistrationDefaultsKey)
    }

    private func fetchChallenge(_ body: ChallengeRequest) async throws -> ChallengeResponse {
        try await send(
            path: "/v1/attest/challenge",
            body: body,
            response: ChallengeResponse.self
        )
    }

    private func send<Body: Encodable, Response: Decodable & Sendable>(
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
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
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

    private func publicError(from error: Error) -> Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? AppAIError { return error }
        return errorAsAttestationFailure(error, stage: "unknown")
    }

    private func errorAsAttestationFailure(_ error: Error, stage: String) -> Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? AppAIError { return error }
        if let error = error as? AppleAppAttestServiceError {
            return AppAIError.attestationFailed(
                "App Attest \(stage) failed (\(error.diagnosticCode)): \(error.localizedDescription)"
            )
        }

        let nsError = error as NSError
        return AppAIError.attestationFailed(
            "App Attest \(stage) failed [\(nsError.domain):\(nsError.code)]: \(error.localizedDescription)"
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

private struct EmptyResponse: Decodable, Sendable {}

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
