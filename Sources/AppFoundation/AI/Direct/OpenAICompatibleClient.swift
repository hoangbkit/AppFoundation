import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor OpenAICompatibleClient: AppAIDirectProviderClient {
    public nonisolated let providerID: AppAIProviderID
    public nonisolated let configuration: OpenAICompatibleConfiguration
    private let credentialStore: any AppAICredentialStoring
    private let transport: any AppAITransport

    public init(
        configuration: OpenAICompatibleConfiguration,
        credentialStore: any AppAICredentialStoring,
        transport: any AppAITransport = URLSessionAppAITransport()
    ) {
        self.configuration = configuration
        self.providerID = configuration.providerID
        self.credentialStore = credentialStore
        self.transport = transport
    }

    public func hasCredential() async -> Bool { await credentialStore.hasCredential(for: providerID) }
    public func saveCredential(_ value: String) async throws { try await credentialStore.setCredential(value, for: providerID) }
    public func removeCredential() async throws { try await credentialStore.removeCredential(for: providerID) }

    public func testConnection(model: String) async throws {
        _ = try await generate(.init(
            model: model,
            messages: [.init(role: .user, content: "Return exactly OK.")],
            maxOutputTokens: 16
        ))
    }

    public func generate(_ request: AppAIDirectRequest) async throws -> AppAIDirectResponse {
        let model = try AppAIDirectHTTP.validatedModel(request.model)
        let messages = try AppAIDirectHTTP.validatedMessages(request.messages)
        if !configuration.supportsStructuredOutput, request.responseFormat != .text {
            throw AppAIDirectError.structuredOutputUnsupported
        }
        let credential = try await AppAIDirectHTTP.requiredCredential(providerID, store: credentialStore)
        let body = OpenAICompatibleRequest(
            model: model,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature,
            maxTokens: request.maxOutputTokens,
            responseFormat: .init(request.responseFormat)
        )
        var url = AppAIDirectHTTP.endpoint(configuration.baseURL, configuration.chatCompletionsPath)
        var urlRequest = AppAIDirectHTTP.request(url: url, method: "POST")
        AppAIDirectHTTP.apply(
            authentication: configuration.authentication,
            credential: credential,
            request: &urlRequest,
            url: &url
        )
        urlRequest.url = url
        for (name, value) in configuration.additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = try AppAIDirectHTTP.encoder.encode(body)
        let data = try await AppAIDirectHTTP.perform(urlRequest, transport: transport, completionUnknown: true)
        let decoded: OpenAICompatibleResponse = try AppAIDirectHTTP.decode(data)
        let text = decoded.choices.first?.message.content.textValue ?? ""
        return try AppAIDirectHTTP.response(
            text: text,
            providerID: providerID,
            modelID: decoded.model ?? model,
            finishReason: decoded.choices.first?.finishReason,
            usage: decoded.usage.map {
                AppAIDirectUsage(
                    inputTokens: $0.promptTokens,
                    outputTokens: $0.completionTokens,
                    cachedInputTokens: $0.promptTokensDetails?.cachedTokens
                )
            }
        )
    }

    public func availableModels() async throws -> [AppAIModel] {
        guard let modelsPath = configuration.modelsPath else { return [] }
        let credential = try await AppAIDirectHTTP.requiredCredential(providerID, store: credentialStore)
        var url = AppAIDirectHTTP.endpoint(configuration.baseURL, modelsPath)
        var request = AppAIDirectHTTP.request(url: url, method: "GET")
        AppAIDirectHTTP.apply(authentication: configuration.authentication, credential: credential, request: &request, url: &url)
        request.url = url
        for (name, value) in configuration.additionalHeaders { request.setValue(value, forHTTPHeaderField: name) }
        let data = try await AppAIDirectHTTP.perform(request, transport: transport, completionUnknown: false)
        let decoded: StandardModelsResponse = try AppAIDirectHTTP.decode(data)
        return decoded.data.map { AppAIModel(id: $0.id, displayName: $0.displayName, contextLength: $0.contextLength) }
    }
}
