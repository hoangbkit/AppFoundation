import Foundation

public struct AppAIProviderID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let openAI = Self(rawValue: "openai")
    public static let anthropic = Self(rawValue: "anthropic")
    public static let gemini = Self(rawValue: "gemini")
    public static let openRouter = Self(rawValue: "openrouter")
    public static let deepSeek = Self(rawValue: "deepseek")
    public static let nvidia = Self(rawValue: "nvidia")
}

public enum AppAIBackendID: Hashable, Codable, Sendable {
    case managed
    case direct(AppAIProviderID)

    public var providerID: AppAIProviderID? {
        guard case .direct(let providerID) = self else { return nil }
        return providerID
    }

    var storedValue: String {
        switch self {
        case .managed: "managed"
        case .direct(let providerID): "direct:\(providerID.rawValue)"
        }
    }

    init?(storedValue: String) {
        if storedValue == "managed" {
            self = .managed
        } else if storedValue.hasPrefix("direct:") {
            let rawValue = String(storedValue.dropFirst("direct:".count))
            guard !rawValue.isEmpty else { return nil }
            self = .direct(AppAIProviderID(rawValue: rawValue))
        } else {
            return nil
        }
    }
}

public struct AppAIBackendCapabilities: Sendable, Equatable {
    public let supportsText: Bool
    public let supportsStructuredOutput: Bool
    public let supportsModelDiscovery: Bool
    public let providesManagedUsage: Bool
    public let guaranteesIdempotentReplay: Bool

    public init(
        supportsText: Bool = true,
        supportsStructuredOutput: Bool,
        supportsModelDiscovery: Bool,
        providesManagedUsage: Bool,
        guaranteesIdempotentReplay: Bool
    ) {
        self.supportsText = supportsText
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsModelDiscovery = supportsModelDiscovery
        self.providesManagedUsage = providesManagedUsage
        self.guaranteesIdempotentReplay = guaranteesIdempotentReplay
    }

    public static let managed = Self(
        supportsStructuredOutput: true,
        supportsModelDiscovery: false,
        providesManagedUsage: true,
        guaranteesIdempotentReplay: true
    )

    public static func direct(
        supportsStructuredOutput: Bool = true,
        supportsModelDiscovery: Bool = true
    ) -> Self {
        Self(
            supportsStructuredOutput: supportsStructuredOutput,
            supportsModelDiscovery: supportsModelDiscovery,
            providesManagedUsage: false,
            guaranteesIdempotentReplay: false
        )
    }
}

public struct AppAIBackendDescriptor: Identifiable, Sendable, Equatable {
    public let id: AppAIBackendID
    public let title: String
    public let subtitle: String?
    public let symbolName: String?
    public let preferredModel: String?
    public let allowsManualModelEntry: Bool
    public let capabilities: AppAIBackendCapabilities

    public init(
        id: AppAIBackendID,
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        preferredModel: String? = nil,
        allowsManualModelEntry: Bool = true,
        capabilities: AppAIBackendCapabilities
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.preferredModel = preferredModel
        self.allowsManualModelEntry = allowsManualModelEntry
        self.capabilities = capabilities
    }

    public static func managed(
        title: String,
        subtitle: String? = nil,
        symbolName: String? = "sparkles"
    ) -> Self {
        Self(
            id: .managed,
            title: title,
            subtitle: subtitle,
            symbolName: symbolName,
            allowsManualModelEntry: false,
            capabilities: .managed
        )
    }

    public static func direct(
        providerID: AppAIProviderID,
        title: String,
        subtitle: String? = nil,
        symbolName: String? = "key.horizontal",
        preferredModel: String? = nil,
        allowsManualModelEntry: Bool = true,
        supportsStructuredOutput: Bool = true,
        supportsModelDiscovery: Bool = true
    ) -> Self {
        Self(
            id: .direct(providerID),
            title: title,
            subtitle: subtitle,
            symbolName: symbolName,
            preferredModel: preferredModel,
            allowsManualModelEntry: allowsManualModelEntry,
            capabilities: .direct(
                supportsStructuredOutput: supportsStructuredOutput,
                supportsModelDiscovery: supportsModelDiscovery
            )
        )
    }
}

public struct AppAIBackendCatalog: Sendable {
    public let backends: [AppAIBackendDescriptor]

    public init(backends: [AppAIBackendDescriptor]) {
        var seen: Set<AppAIBackendID> = []
        self.backends = backends.filter { seen.insert($0.id).inserted }
    }

    public var defaultBackendID: AppAIBackendID? { backends.first?.id }

    public func contains(_ id: AppAIBackendID) -> Bool {
        descriptor(for: id) != nil
    }

    public func descriptor(for id: AppAIBackendID) -> AppAIBackendDescriptor? {
        backends.first { $0.id == id }
    }

    public func descriptor(for providerID: AppAIProviderID) -> AppAIBackendDescriptor? {
        descriptor(for: .direct(providerID))
    }
}

public struct AppAIMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public indirect enum AppAIJSONValue: Codable, Sendable, Equatable {
    case object([String: AppAIJSONValue])
    case array([AppAIJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: AppAIJSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([AppAIJSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public func encodedData(using encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(self)
    }
}

public struct AppAIJSONSchema: Sendable, Equatable {
    public let name: String
    public let schema: AppAIJSONValue
    public let strict: Bool

    public init(name: String, schema: AppAIJSONValue, strict: Bool = true) {
        self.name = name
        self.schema = schema
        self.strict = strict
    }
}

public enum AppAIResponseFormat: Sendable, Equatable {
    case text
    case jsonObject
    case jsonSchema(AppAIJSONSchema)
}

public struct AppAIDirectRequest: Sendable, Equatable {
    public let model: String
    public let messages: [AppAIMessage]
    public let responseFormat: AppAIResponseFormat
    public let temperature: Double?
    public let maxOutputTokens: Int?

    public init(
        model: String,
        messages: [AppAIMessage],
        responseFormat: AppAIResponseFormat = .text,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.responseFormat = responseFormat
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

public struct AppAIDirectUsage: Sendable, Equatable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cachedInputTokens: Int?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil, cachedInputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
    }
}

public struct AppAIDirectResponse: Sendable, Equatable {
    public let text: String
    public let providerID: AppAIProviderID
    public let modelID: String
    public let finishReason: String?
    public let usage: AppAIDirectUsage?

    public init(
        text: String,
        providerID: AppAIProviderID,
        modelID: String,
        finishReason: String? = nil,
        usage: AppAIDirectUsage? = nil
    ) {
        self.text = text
        self.providerID = providerID
        self.modelID = modelID
        self.finishReason = finishReason
        self.usage = usage
    }

    public func decodeJSON<Value: Decodable>(
        _ type: Value.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        let normalized = Self.removingOuterJSONFence(from: text)
        guard let data = normalized.data(using: .utf8) else {
            throw AppAIDirectError.invalidResponse
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AppAIDirectError.invalidResponse
        }
    }

    static func removingOuterJSONFence(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2, lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" else {
            return trimmed
        }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct AppAIModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let contextLength: Int?

    public init(id: String, displayName: String? = nil, contextLength: Int? = nil) {
        self.id = id
        self.displayName = displayName ?? id
        self.contextLength = contextLength
    }
}

public enum AppAIDirectError: Error, LocalizedError, Sendable, Equatable {
    case missingCredential(AppAIProviderID)
    case invalidModel
    case invalidRequest(String)
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case insufficientCredits
    case rateLimited(retryAfter: String?)
    case modelUnavailable
    case emptyOutput
    case structuredOutputUnsupported
    case transport(message: String, completionUnknown: Bool)
    case provider(status: Int, message: String)
    case credentialStorage(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredential(let provider): "An API key is required for \(provider.rawValue)."
        case .invalidModel: "Choose a valid AI model."
        case .invalidRequest(let message): message
        case .invalidResponse: "The AI provider returned an invalid response."
        case .authenticationFailed: "The API key was rejected by the AI provider."
        case .permissionDenied: "The API key does not have permission for this request."
        case .insufficientCredits: "The AI provider account has insufficient credit."
        case .rateLimited: "The AI provider rate limit was reached."
        case .modelUnavailable: "The selected AI model is unavailable."
        case .emptyOutput: "The AI provider returned no usable output."
        case .structuredOutputUnsupported: "The selected provider does not support this structured output request."
        case .transport(let message, _): message
        case .provider(_, let message): message
        case .credentialStorage(let message): message
        }
    }

    public var completionUnknown: Bool {
        guard case .transport(_, let completionUnknown) = self else { return false }
        return completionUnknown
    }
}

public protocol AppAIDirectProviderClient: Sendable {
    var providerID: AppAIProviderID { get }

    func hasCredential() async -> Bool
    func saveCredential(_ value: String) async throws
    func removeCredential() async throws
    func testConnection(model: String) async throws
    func generate(_ request: AppAIDirectRequest) async throws -> AppAIDirectResponse
    func availableModels() async throws -> [AppAIModel]
}

public extension AppAIBackendDescriptor {
    static func openAI(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .openAI, title: "OpenAI", subtitle: subtitle, preferredModel: preferredModel)
    }

    static func anthropic(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .anthropic, title: "Anthropic", subtitle: subtitle, preferredModel: preferredModel)
    }

    static func gemini(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .gemini, title: "Gemini", subtitle: subtitle, preferredModel: preferredModel)
    }

    static func openRouter(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .openRouter, title: "OpenRouter", subtitle: subtitle, preferredModel: preferredModel)
    }

    static func deepSeek(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .deepSeek, title: "DeepSeek", subtitle: subtitle, preferredModel: preferredModel)
    }

    static func nvidia(preferredModel: String? = nil, subtitle: String? = nil) -> Self {
        .direct(providerID: .nvidia, title: "NVIDIA", subtitle: subtitle, preferredModel: preferredModel)
    }
}
