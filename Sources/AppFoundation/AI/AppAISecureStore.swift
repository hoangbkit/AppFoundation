import Foundation
#if canImport(Security)
import Security
#endif

actor AppAISecureStore {
    private let service: String

    #if canImport(Security) && targetEnvironment(simulator)
    /// Swift Package test bundles on CI can be ad-hoc signed without an application
    /// identifier entitlement, causing otherwise-valid Keychain operations to fail
    /// with errSecMissingEntitlement (-34018). Keep a process-local fallback for that
    /// specific simulator condition so tests exercise persistence semantics without
    /// weakening device Keychain behavior.
    private static let simulatorFallback = SimulatorSecureStoreFallback()
    #elseif !canImport(Security)
    private var memory: [String: Data] = [:]
    #endif

    init(service: String) {
        self.service = service
    }

    func data(for account: String) async throws -> Data? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        #if targetEnvironment(simulator)
        if status == errSecMissingEntitlement {
            return await Self.simulatorFallback.data(service: service, account: account)
        }
        #endif
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppAIError.secureStorageFailed(status)
        }
        return data
        #else
        return memory[account]
        #endif
    }

    func set(_ data: Data, for account: String) async throws {
        #if canImport(Security)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = lookup
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            #if targetEnvironment(simulator)
            if addStatus == errSecMissingEntitlement {
                await Self.simulatorFallback.set(data, service: service, account: account)
                return
            }
            #endif
            guard addStatus == errSecSuccess else { throw AppAIError.secureStorageFailed(addStatus) }
        } else {
            #if targetEnvironment(simulator)
            if updateStatus == errSecMissingEntitlement {
                await Self.simulatorFallback.set(data, service: service, account: account)
                return
            }
            #endif
            guard updateStatus == errSecSuccess else {
                throw AppAIError.secureStorageFailed(updateStatus)
            }
        }
        #else
        memory[account] = data
        #endif
    }

    func remove(_ account: String) async throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        #if targetEnvironment(simulator)
        if status == errSecMissingEntitlement {
            await Self.simulatorFallback.remove(service: service, account: account)
            return
        }
        #endif
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppAIError.secureStorageFailed(status)
        }
        #else
        memory.removeValue(forKey: account)
        #endif
    }

    func string(for account: String) async throws -> String? {
        guard let data = try await data(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for account: String) async throws {
        guard let data = value.data(using: .utf8) else { throw AppAIError.invalidResponse }
        try await set(data, for: account)
    }
}

#if canImport(Security) && targetEnvironment(simulator)
private actor SimulatorSecureStoreFallback {
    private var values: [String: Data] = [:]

    func data(service: String, account: String) -> Data? {
        values[key(service: service, account: account)]
    }

    func set(_ data: Data, service: String, account: String) {
        values[key(service: service, account: account)] = data
    }

    func remove(service: String, account: String) {
        values.removeValue(forKey: key(service: service, account: account))
    }

    private func key(service: String, account: String) -> String {
        "\(service)\u{0}\(account)"
    }
}
#endif
