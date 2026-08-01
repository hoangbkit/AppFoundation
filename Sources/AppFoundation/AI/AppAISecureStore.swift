import Foundation
#if canImport(Security)
import Security
#endif

actor AppAISecureStore {
    private let service: String
    #if !canImport(Security)
    private var memory: [String: Data] = [:]
    #endif

    init(service: String) {
        self.service = service
    }

    func data(for account: String) throws -> Data? {
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
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppAIError.secureStorageFailed(status)
        }
        return data
        #else
        return memory[account]
        #endif
    }

    func set(_ data: Data, for account: String) throws {
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
            guard addStatus == errSecSuccess else { throw AppAIError.secureStorageFailed(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw AppAIError.secureStorageFailed(updateStatus)
        }
        #else
        memory[account] = data
        #endif
    }

    func remove(_ account: String) throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppAIError.secureStorageFailed(status)
        }
        #else
        memory.removeValue(forKey: account)
        #endif
    }

    func string(for account: String) throws -> String? {
        guard let data = try data(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else { throw AppAIError.invalidResponse }
        try set(data, for: account)
    }
}
