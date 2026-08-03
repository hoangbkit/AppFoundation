import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor AnthropicMessagesClient: AppAIDirectProviderClient {
    public nonisolated let providerID: AppAIProviderID = .anthropic

    private let credentialStore: any AppAICredentialStoring
    private let transport: any AppAITransport
    private let baseURL: URL
    private let apiVersion: String

    public init(
        credentialStore: any AppAICredentialStoring,
        transport: any AppAITransport = URLSessionAppAITransport(),
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        apiVersion: String = "2023-06-01"
    ) {
        self.credentialStore = credentialStore
        self.transport = transport
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }

    public func hasCredential() async -> Bool {
        await credentialStore.hasCredential(for: providerID)
    }

    public func saveCredential(_ value: String) async throws {
        try await credentialStore.setCredential(value, for: providerID)
    }

    public func removeCredential() async throws {
        try await credentialStore.removeCredential(for: providerID)
    }

    public func testConnection(model: String) async throws {
        _ = try await generate(
            .init(
                model: model,
                messages: [
                    .init(role: .user, content: "Return exactly OK."),
                ],
                maxOutputTokens: 16
            )
        )
    }

    public func generate(
        _ request: AppAIDirectRequest
    ) async throws -> AppAIDirectResponse {
        let model = try AppAIDirectHTTP.validatedModel(request.model)
        let messages = try AppAIDirectHTTP.validatedMessages(
            request.messages
        )
        let credential = try await AppAIDirectHTTP.requiredCredential(
            providerID,
            store: credentialStore
        )
        let system = Self.systemPrompt(
            from: messages,
            responseFormat: request.responseFormat
        )
        var providerMessages = messages
            .filter { $0.role != .system }
            .map {
                AnthropicRequest.Message(
                    role: $0.role == .assistant ? "assistant" : "user",
                    content: $0.content
                )
            }
        if providerMessages.isEmpty {
            providerMessages = [
                .init(
                    role: "user",
                    content: "Complete the requested task."
                ),
            ]
        }

        let body = AnthropicRequest(
            model: model,
            maxTokens: request.maxOutputTokens ?? 1_024,
            system: system.isEmpty ? nil : system,
            messages: providerMessages,
            temperature: request.temperature
        )
        var urlRequest = AppAIDirectHTTP.request(
            url: AppAIDirectHTTP.endpoint(baseURL, "messages"),
            method: "POST"
        )
        urlRequest.setValue(
            credential,
            forHTTPHeaderField: "x-api-key"
        )
        urlRequest.setValue(
            apiVersion,
            forHTTPHeaderField: "anthropic-version"
        )
        urlRequest.httpBody = try AppAIDirectHTTP.encoder.encode(body)

        let data = try await AppAIDirectHTTP.perform(
            urlRequest,
            transport: transport,
            completionUnknown: true
        )
        let decoded: AnthropicResponse = try AppAIDirectHTTP.decode(data)
        let text = decoded.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()

        return try AppAIDirectHTTP.response(
            text: text,
            providerID: providerID,
            modelID: decoded.model ?? model,
            finishReason: decoded.stopReason,
            usage: decoded.usage.map {
                AppAIDirectUsage(
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    cachedInputTokens: $0.cacheReadInputTokens
                )
            }
        )
    }

    public func availableModels() async throws -> [AppAIModel] {
        let credential = try await AppAIDirectHTTP.requiredCredential(
            providerID,
            store: credentialStore
        )

        var models: [AppAIModel] = []
        var seenModelIDs: Set<String> = []
        var seenCursors: Set<String> = []
        var afterID: String?

        while true {
            var components = URLComponents(
                url: AppAIDirectHTTP.endpoint(baseURL, "models"),
                resolvingAgainstBaseURL: false
            )
            var queryItems = [
                URLQueryItem(name: "limit", value: "1000"),
            ]
            if let afterID {
                queryItems.append(
                    URLQueryItem(name: "after_id", value: afterID)
                )
            }
            components?.queryItems = queryItems

            guard let url = components?.url else {
                throw AppAIDirectError.invalidRequest(
                    "Unable to build the Anthropic models URL."
                )
            }

            var request = AppAIDirectHTTP.request(
                url: url,
                method: "GET"
            )
            request.setValue(
                credential,
                forHTTPHeaderField: "x-api-key"
            )
            request.setValue(
                apiVersion,
                forHTTPHeaderField: "anthropic-version"
            )

            let data = try await AppAIDirectHTTP.perform(
                request,
                transport: transport,
                completionUnknown: false
            )
            let decoded: AnthropicModelsResponse = try AppAIDirectHTTP.decode(
                data
            )

            for model in decoded.data {
                guard seenModelIDs.insert(model.id).inserted else {
                    continue
                }
                models.append(
                    AppAIModel(
                        id: model.id,
                        displayName: model.displayName,
                        contextLength: model.maxInputTokens
                    )
                )
            }

            guard decoded.hasMore,
                  let nextCursor = decoded.lastID?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !nextCursor.isEmpty,
                  seenCursors.insert(nextCursor).inserted else {
                break
            }
            afterID = nextCursor
        }

        return models
    }

    private static func systemPrompt(
        from messages: [AppAIMessage],
        responseFormat: AppAIResponseFormat
    ) -> String {
        var parts = messages
            .filter { $0.role == .system }
            .map(\.content)

        switch responseFormat {
        case .text:
            break
        case .jsonObject:
            parts.append(
                "Return only one valid JSON object. Do not wrap it in Markdown."
            )
        case .jsonSchema(let schema):
            let encoded = (try? schema.schema.encodedData())
                .flatMap { String(data: $0, encoding: .utf8) }
                ?? "{}"
            parts.append(
                "Return only JSON matching the schema named \(schema.name). "
                    + "Do not wrap it in Markdown. Schema: \(encoded)"
            )
        }

        return parts.joined(separator: "\n\n")
    }
}
