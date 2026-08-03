import Foundation

public protocol AppAIBackendPreferences: Sendable {
    func selectedBackend() async -> AppAIBackendID?
    func setSelectedBackend(_ backend: AppAIBackendID) async
    func model(for provider: AppAIProviderID) async -> String?
    func setModel(_ model: String?, for provider: AppAIProviderID) async
}

public actor UserDefaultsAppAIBackendPreferences: AppAIBackendPreferences {
    private let defaults: UserDefaults
    private let namespace: String

    public init(namespace: String, suiteName: String? = nil) {
        self.namespace = namespace
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func selectedBackend() async -> AppAIBackendID? {
        guard let value = defaults.string(forKey: key("selected-backend")) else { return nil }
        return AppAIBackendID(storedValue: value)
    }

    public func setSelectedBackend(_ backend: AppAIBackendID) async {
        defaults.set(backend.storedValue, forKey: key("selected-backend"))
    }

    public func model(for provider: AppAIProviderID) async -> String? {
        defaults.string(forKey: key("model.\(provider.rawValue)"))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func setModel(_ model: String?, for provider: AppAIProviderID) async {
        let normalized = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let modelKey = key("model.\(provider.rawValue)")
        if normalized.isEmpty { defaults.removeObject(forKey: modelKey) }
        else { defaults.set(normalized, forKey: modelKey) }
    }

    private func key(_ suffix: String) -> String { "\(namespace).ai.\(suffix)" }
}

public actor AppAIInMemoryBackendPreferences: AppAIBackendPreferences {
    private var backend: AppAIBackendID?
    private var models: [AppAIProviderID: String]

    public init(selectedBackend: AppAIBackendID? = nil, models: [AppAIProviderID: String] = [:]) {
        self.backend = selectedBackend
        self.models = models
    }

    public func selectedBackend() async -> AppAIBackendID? { backend }
    public func setSelectedBackend(_ backend: AppAIBackendID) async { self.backend = backend }
    public func model(for provider: AppAIProviderID) async -> String? { models[provider] }
    public func setModel(_ model: String?, for provider: AppAIProviderID) async {
        let normalized = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalized.isEmpty { models.removeValue(forKey: provider) }
        else { models[provider] = normalized }
    }
}
