import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AppAIAttestationPolicy: String, Sendable, Codable {
    case disabled
    case preferred
    case required
}

public struct AppAIClientConfiguration: Sendable {
    public var appID: String
    public var appKey: String
    public var baseURL: URL
    public var attestationPolicy: AppAIAttestationPolicy
    public var keychainService: String
    public var transportRetryCount: Int

    public init(
        appID: String,
        appKey: String,
        baseURL: URL,
        attestationPolicy: AppAIAttestationPolicy = .preferred,
        keychainService: String = "com.hoangbkit.AppFoundation.AppAI",
        transportRetryCount: Int = 1
    ) {
        self.appID = appID
        self.appKey = appKey
        self.baseURL = baseURL
        self.attestationPolicy = attestationPolicy
        self.keychainService = keychainService
        self.transportRetryCount = max(0, transportRetryCount)
    }
}

public struct AppAIUsage: Codable, Sendable, Equatable {
    public let limit: Int
    public let used: Int
    public let remaining: Int
    public let resetsAt: Date
}

public struct AppAIResponse<Output: Decodable & Sendable>: Decodable, Sendable {
    public let requestId: String
    public let capability: String
    public let data: Output
    public let plan: String?
    public let attestation: String?
    public let usage: AppAIUsage?
}

public struct AppAIStatus: Decodable, Sendable {
    public struct App: Decodable, Sendable {
        public let id: String
        public let displayName: String
    }

    public struct Entitlement: Decodable, Sendable {
        public let productId: String
        public let productType: String
        public let status: String
        public let expiresAt: Date?
    }

    public struct Attestation: Decodable, Sendable {
        public let mode: String
        public let status: String
    }

    public let app: App
    public let enabled: Bool
    public let plan: String
    public let entitlement: Entitlement?
    public let attestation: Attestation
    public let usage: AppAIUsage
}

public enum AppAIError: Error, LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case invalidResponse
    case transport(String)
    case server(code: String, message: String, retryAfter: String?)
    case attestationUnavailable
    case attestationFailed(String)
    case secureStorageFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message), .transport(let message), .attestationFailed(let message):
            message
        case .invalidResponse:
            "The AI service returned an invalid response."
        case .server(_, let message, _):
            message
        case .attestationUnavailable:
            "App Attest is not available on this device."
        case .secureStorageFailed:
            "Secure installation storage is unavailable."
        }
    }
}

public protocol AppAITransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionAppAITransport: AppAITransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw AppAIError.invalidResponse
        }
        return (data, response)
    }
}

public struct AppAIAttestationRequest: Sendable {
    public let requestID: String
    public let method: String
    public let path: String
    public let body: Data

    public init(requestID: String, method: String, path: String, body: Data) {
        self.requestID = requestID
        self.method = method
        self.path = path
        self.body = body
    }
}

public protocol AppAIAttestationProviding: Sendable {
    func headers(for request: AppAIAttestationRequest) async throws -> [String: String]
    func resetKey() async throws
}

public struct AppAIAccess: Decodable, Sendable, Equatable {
    public let plan: String
    public let quotaLimit: Int
    public let productId: String?
    public let productType: String?
    public let status: String?
    public let expiresAt: Date?
}

public struct AppAIEntitlementSyncResult: Decodable, Sendable, Equatable {
    public let requestId: String
    public let synced: Int
    public let access: AppAIAccess
}
