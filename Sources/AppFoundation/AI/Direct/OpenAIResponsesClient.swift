import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor OpenAIResponsesClient: AppAIDirectProviderClient {
    public nonisolated let providerID: AppAIProviderID = .openAI
    private let credentialStore: any AppAICredentialStoring
    private let transport: any AppAITransport
    private let baseURL: URL

    public init(
        credentialStore: any AppAICredentialStoring,
        transport: any AppAITransport = URLSessionAppAITransport(),
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) {
        self.credentialStore = credentialStore
        self.transport = transport
        self.baseURL = baseURL
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
        let credential = try await AppAIDirectHTTP.requiredCredential(providerID, store: credentialStore)
        let body = OpenAIResponsesRequest(
            model: model,
            input: messages.map(OpenAIResponsesRequest.Input.init),
            temperature: request.temperature,
            maxOutputTokens: request.maxOutputTokens,
            store: false,
            text: OpenAIResponsesRequest.Text(format: request.responseFormat)
        )
        var urlRequest = AppAIDirectHTTP.request(url: AppAIDirectHTTP.endpoint(baseURL, "responses"), method: "POST")
        urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try AppAIDirectHTTP.encoder.encode(body)
        let data = try await AppAIDirectHTTP.perform(urlRequest, transport: transport, completionUnknown: true)
        let decoded: OpenAIResponsesResponse = try AppAIDirectHTTP.decode(data)
        let text = decoded.output
            .flatMap(\.content)
            .filter { $0.type == "output_text" || $0.type == nil }
            .compactMap(\.text)
            .joined()
        return try AppAIDirectHTTP.response(
            text: text,
            providerID: providerID,
            modelID: decoded.model ?? model,
            finishReason: decoded.status,
            usage: decoded.usage.map {
                AppAIDirectUsage(
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    cachedInputTokens: $0.inputTokensDetails?.cachedTokens
                )
            }
        )
    }

    public func availableModels() async throws -> [AppAIModel] {
        let credential = try await AppAIDirectHTTP.requiredCredential(providerID, store: credentialStore)
        var request = AppAIDirectHTTP.request(url: AppAIDirectHTTP.endpoint(baseURL, "models"), method: "GET")
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        let data = try await AppAIDirectHTTP.perform(request, transport: transport, completionUnknown: false)
        let decoded: StandardModelsResponse = try AppAIDirectHTTP.decode(data)
        return decoded.data.map { AppAIModel(id: $0.id, displayName: $0.displayName, contextLength: $0.contextLength) }
    }
}
