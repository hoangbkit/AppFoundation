import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AppAIProviderAuthentication: Sendable, Equatable {
    case bearer
    case header(name: String)
    case query(name: String)
}

public struct OpenAICompatibleConfiguration: Sendable, Equatable {
    public let providerID: AppAIProviderID
    public let title: String
    public let baseURL: URL
    public let authentication: AppAIProviderAuthentication
    public let additionalHeaders: [String: String]
    public let defaultModel: String?
    public let chatCompletionsPath: String
    public let modelsPath: String?
    public let supportsStructuredOutput: Bool

    public init(
        providerID: AppAIProviderID,
        title: String,
        baseURL: URL,
        authentication: AppAIProviderAuthentication = .bearer,
        additionalHeaders: [String: String] = [:],
        defaultModel: String? = nil,
        chatCompletionsPath: String = "chat/completions",
        modelsPath: String? = "models",
        supportsStructuredOutput: Bool = true
    ) {
        self.providerID = providerID
        self.title = title
        self.baseURL = baseURL
        self.authentication = authentication
        self.additionalHeaders = additionalHeaders
        self.defaultModel = defaultModel
        self.chatCompletionsPath = chatCompletionsPath
        self.modelsPath = modelsPath
        self.supportsStructuredOutput = supportsStructuredOutput
    }
}

public enum AppAIProviderPresets {
    public static func openRouter(
        appName: String,
        siteURL: URL? = nil,
        defaultModel: String? = nil
    ) -> OpenAICompatibleConfiguration {
        var headers = ["X-OpenRouter-Title": appName]
        if let siteURL { headers["HTTP-Referer"] = siteURL.absoluteString }
        return OpenAICompatibleConfiguration(
            providerID: .openRouter,
            title: "OpenRouter",
            baseURL: URL(string: "https://openrouter.ai/api/v1")!,
            additionalHeaders: headers,
            defaultModel: defaultModel
        )
    }

    public static func deepSeek(defaultModel: String? = nil) -> OpenAICompatibleConfiguration {
        OpenAICompatibleConfiguration(
            providerID: .deepSeek,
            title: "DeepSeek",
            baseURL: URL(string: "https://api.deepseek.com/v1")!,
            defaultModel: defaultModel
        )
    }

    public static func nvidia(defaultModel: String? = nil) -> OpenAICompatibleConfiguration {
        OpenAICompatibleConfiguration(
            providerID: .nvidia,
            title: "NVIDIA",
            baseURL: URL(string: "https://integrate.api.nvidia.com/v1")!,
            defaultModel: defaultModel
        )
    }
}
