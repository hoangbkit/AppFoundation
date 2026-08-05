#if !canImport(SwiftUI)
import Foundation

/// Reusable editable state for a direct-provider configuration screen.
///
/// This fallback keeps the pure configuration state available on platforms
/// where SwiftUI is not importable, including cross-platform package tests.
public struct AppAIProviderConfigurationDraft: Equatable, Sendable {
    public var apiKey: String
    public var model: String

    private var savedAPIKey: String
    private var savedModel: String

    public init(apiKey: String = "", model: String = "") {
        let normalizedAPIKey = Self.normalize(apiKey)
        let normalizedModel = Self.normalize(model)
        self.apiKey = normalizedAPIKey
        self.model = normalizedModel
        self.savedAPIKey = normalizedAPIKey
        self.savedModel = normalizedModel
    }

    public var normalizedAPIKey: String {
        Self.normalize(apiKey)
    }

    public var normalizedModel: String {
        Self.normalize(model)
    }

    public var hasSavedCredential: Bool {
        !savedAPIKey.isEmpty
    }

    public var hasUnsavedChanges: Bool {
        normalizedAPIKey != savedAPIKey
            || normalizedModel != savedModel
    }

    public var canSave: Bool {
        !normalizedModel.isEmpty && hasUnsavedChanges
    }

    public var canTest: Bool {
        !normalizedAPIKey.isEmpty && !normalizedModel.isEmpty
    }

    public mutating func load(apiKey: String, model: String) {
        let normalizedAPIKey = Self.normalize(apiKey)
        let normalizedModel = Self.normalize(model)
        self.apiKey = normalizedAPIKey
        self.model = normalizedModel
        self.savedAPIKey = normalizedAPIKey
        self.savedModel = normalizedModel
    }

    public mutating func markSaved() {
        apiKey = normalizedAPIKey
        model = normalizedModel
        savedAPIKey = apiKey
        savedModel = model
    }

    public mutating func discardChanges() {
        apiKey = savedAPIKey
        model = savedModel
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
