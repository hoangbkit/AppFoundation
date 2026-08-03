import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor GeminiGenerateContentClient: AppAIDirectProviderClient {
    public nonisolated let providerID: AppAIProviderID = .gemini
    private let credentialStore: any AppAICredentialStoring
    private let transport: any AppAITransport
    private let baseURL: URL

    public init(
        credentialStore: any AppAICredentialStoring,
        transport: any AppAITransport = URLSessionAppAITransport(),
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
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
        let systemParts = messages.filter { $0.role == .system }.map { GeminiRequest.Part(text: $0.content) }
        var contents = messages.filter { $0.role != .system }.map {
            GeminiRequest.Content(
                role: $0.role == .assistant ? "model" : "user",
                parts: [.init(text: $0.content)]
            )
        }
        if contents.isEmpty { contents = [.init(role: "user", parts: [.init(text: "Complete the requested task.")])] }
        let body = GeminiRequest(
            systemInstruction: systemParts.isEmpty ? nil : .init(role: nil, parts: systemParts),
            contents: contents,
            generationConfig: .init(
                temperature: request.temperature,
                maxOutputTokens: request.maxOutputTokens,
                responseMimeType: request.responseFormat == .text ? nil : "application/json",
                responseSchema: request.responseFormat.schemaValue
            )
        )
        let normalizedModel = model.hasPrefix("models/") ? String(model.dropFirst("models/".count)) : model
        var urlRequest = AppAIDirectHTTP.request(
            url: AppAIDirectHTTP.endpoint(baseURL, "models/\(normalizedModel):generateContent"),
            method: "POST"
        )
        urlRequest.setValue(credential, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.httpBody = try AppAIDirectHTTP.encoder.encode(body)
        let data = try await AppAIDirectHTTP.perform(urlRequest, transport: transport, completionUnknown: true)
        let decoded: GeminiResponse = try AppAIDirectHTTP.decode(data)
        let text = decoded.candidates.first?.content.parts.compactMap(\.text).joined() ?? ""
        return try AppAIDirectHTTP.response(
            text: text,
            providerID: providerID,
            modelID: model,
            finishReason: decoded.candidates.first?.finishReason,
            usage: decoded.usageMetadata.map {
                AppAIDirectUsage(
                    inputTokens: $0.promptTokenCount,
                    outputTokens: $0.candidatesTokenCount,
                    cachedInputTokens: $0.cachedContentTokenCount
                )
            }
        )
    }

    public func availableModels() async throws -> [AppAIModel] {
        let credential = try await AppAIDirectHTTP.requiredCredential(providerID, store: credentialStore)
        var request = AppAIDirectHTTP.request(url: AppAIDirectHTTP.endpoint(baseURL, "models"), method: "GET")
        request.setValue(credential, forHTTPHeaderField: "x-goog-api-key")
        let data = try await AppAIDirectHTTP.perform(request, transport: transport, completionUnknown: false)
        let decoded: GeminiModelsResponse = try AppAIDirectHTTP.decode(data)
        return decoded.models.map {
            let id = $0.name.hasPrefix("models/") ? String($0.name.dropFirst("models/".count)) : $0.name
            return AppAIModel(id: id, displayName: $0.displayName, contextLength: $0.inputTokenLimit)
        }
    }
}
