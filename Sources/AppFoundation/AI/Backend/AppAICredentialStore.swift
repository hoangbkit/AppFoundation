import Foundation

public protocol AppAICredentialStoring: Sendable {
    func hasCredential(for provider: AppAIProviderID) async -> Bool
    func credential(for provider: AppAIProviderID) async throws -> String?
    func setCredential(_ credential: String, for provider: AppAIProviderID) async throws
    func removeCredential(for provider: AppAIProviderID) async throws
}

public actor AppAIKeychainCredentialStore: AppAICredentialStoring {
    private let secureStore: AppAISecureStore
    private let accountPrefix: String

    public init(service: String, accountPrefix: String = "provider") {
        self.secureStore = AppAISecureStore(service: service)
        self.accountPrefix = accountPrefix
    }

    public func hasCredential(for provider: AppAIProviderID) async -> Bool {
        guard let value = try? await credential(for: provider) else { return false }
        return !value.isEmpty
    }

    public func credential(for provider: AppAIProviderID) async throws -> String? {
        do {
            return try await secureStore.string(for: account(for: provider))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw AppAIDirectError.credentialStorage(error.localizedDescription)
        }
    }

    public func setCredential(_ credential: String, for provider: AppAIProviderID) async throws {
        let normalized = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            try await removeCredential(for: provider)
            return
        }
        do {
            try await secureStore.set(normalized, for: account(for: provider))
        } catch {
            throw AppAIDirectError.credentialStorage(error.localizedDescription)
        }
    }

    public func removeCredential(for provider: AppAIProviderID) async throws {
        do {
            try await secureStore.remove(account(for: provider))
        } catch {
            throw AppAIDirectError.credentialStorage(error.localizedDescription)
        }
    }

    private func account(for provider: AppAIProviderID) -> String {
        "\(accountPrefix).\(provider.rawValue).api-key"
    }
}

public actor AppAIInMemoryCredentialStore: AppAICredentialStoring {
    private var credentials: [AppAIProviderID: String]

    public init(credentials: [AppAIProviderID: String] = [:]) {
        self.credentials = credentials
    }

    public func hasCredential(for provider: AppAIProviderID) async -> Bool {
        guard let credential = credentials[provider] else { return false }
        return !credential.isEmpty
    }

    public func credential(for provider: AppAIProviderID) async throws -> String? {
        credentials[provider]
    }

    public func setCredential(_ credential: String, for provider: AppAIProviderID) async throws {
        let normalized = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { credentials.removeValue(forKey: provider) }
        else { credentials[provider] = normalized }
    }

    public func removeCredential(for provider: AppAIProviderID) async throws {
        credentials.removeValue(forKey: provider)
    }
}
