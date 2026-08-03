import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor CapturingTransport: AppAITransport {
    private(set) var requests: [URLRequest] = []
    let handler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try await handler(request)
    }

    func count() -> Int { requests.count }
}

private func response(for request: URLRequest, status: Int = 200, body: String) -> (Data, HTTPURLResponse) {
    (
        Data(body.utf8),
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
}

@Test func directResponseDecodesOuterJSONFence() throws {
    struct Output: Decodable, Equatable { let value: String }
    let response = AppAIDirectResponse(
        text: "```json\n{\"value\":\"ok\"}\n```",
        providerID: .openAI,
        modelID: "test"
    )
    #expect(try response.decodeJSON(Output.self) == Output(value: "ok"))
}

@Test func credentialStoreTrimsAndDeletesEmptyValues() async throws {
    let store = AppAIInMemoryCredentialStore()
    try await store.setCredential("  secret-value \n", for: .openAI)
    #expect(try await store.credential(for: .openAI) == "secret-value")
    #expect(await store.hasCredential(for: .openAI))
    #expect(!(await store.hasCredential(for: .anthropic)))

    try await store.setCredential("   ", for: .openAI)
    #expect(try await store.credential(for: .openAI) == nil)
}

@Test func backendIdentifiersRoundTripThroughPreferences() async {
    let preferences = AppAIInMemoryBackendPreferences()
    await preferences.setSelectedBackend(.direct(.openRouter))
    await preferences.setModel(" model-x ", for: .openRouter)
    #expect(await preferences.selectedBackend() == .direct(.openRouter))
    #expect(await preferences.model(for: .openRouter) == "model-x")
}

@Test func openAICompatibleClientBuildsStructuredRequestAndParsesUsage() async throws {
    let credentials = AppAIInMemoryCredentialStore(credentials: [.openRouter: "test-key"])
    let transport = CapturingTransport { request in
        #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "X-App") == "Test App")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "provider/model")
        #expect(json["max_tokens"] as? Int == 900)
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        return response(for: request, body: #"{"model":"provider/model","choices":[{"message":{"content":"{\"answer\":\"yes\"}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":12,"completion_tokens":4,"prompt_tokens_details":{"cached_tokens":3}}}"#)
    }
    let configuration = OpenAICompatibleConfiguration(
        providerID: .openRouter,
        title: "OpenRouter",
        baseURL: URL(string: "https://example.com/v1")!,
        additionalHeaders: ["X-App": "Test App"]
    )
    let client = OpenAICompatibleClient(configuration: configuration, credentialStore: credentials, transport: transport)
    let schema = AppAIJSONSchema(
        name: "answer",
        schema: .object([
            "type": .string("object"),
            "properties": .object([
                "answer": .object(["type": .string("string")])
            ])
        ])
    )
    let result = try await client.generate(.init(
        model: "provider/model",
        messages: [.init(role: .user, content: "Question")],
        responseFormat: .jsonSchema(schema),
        temperature: 0.2,
        maxOutputTokens: 900
    ))
    #expect(result.text == #"{"answer":"yes"}"#)
    #expect(result.usage == .init(inputTokens: 12, outputTokens: 4, cachedInputTokens: 3))
    #expect(await transport.count() == 1)
}

@Test func directGenerationDoesNotRetryAmbiguousTransportFailure() async throws {
    let credentials = AppAIInMemoryCredentialStore(credentials: [.deepSeek: "test-key"])
    let transport = CapturingTransport { _ in throw URLError(.networkConnectionLost) }
    let client = OpenAICompatibleClient(
        configuration: .init(
            providerID: .deepSeek,
            title: "DeepSeek",
            baseURL: URL(string: "https://example.com/v1")!
        ),
        credentialStore: credentials,
        transport: transport
    )

    do {
        _ = try await client.generate(.init(
            model: "deepseek-chat",
            messages: [.init(role: .user, content: "Hello")]
        ))
        Issue.record("Expected a transport error")
    } catch let error as AppAIDirectError {
        #expect(error.completionUnknown)
    }
    #expect(await transport.count() == 1)
}

@Test func openAIResponsesClientUsesResponsesAPI() async throws {
    let credentials = AppAIInMemoryCredentialStore(credentials: [.openAI: "openai-key"])
    let transport = CapturingTransport { request in
        #expect(request.url?.path == "/v1/responses")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer openai-key")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["store"] as? Bool == false)
        #expect(json["max_output_tokens"] as? Int == 50)
        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input.count == 2)
        #expect(input.allSatisfy { $0["type"] as? String == "message" })
        return response(for: request, body: #"{"model":"gpt-test","status":"completed","output":[{"content":[{"type":"output_text","text":"Done"}]}],"usage":{"input_tokens":5,"output_tokens":2}}"#)
    }
    let client = OpenAIResponsesClient(credentialStore: credentials, transport: transport, baseURL: URL(string: "https://example.com/v1")!)
    let result = try await client.generate(.init(
        model: "gpt-test",
        messages: [
            .init(role: .system, content: "Be concise"),
            .init(role: .user, content: "Hello")
        ],
        maxOutputTokens: 50
    ))
    #expect(result.text == "Done")
    #expect(result.finishReason == "completed")
}

@Test func anthropicClientAddsJSONInstructionForStructuredOutput() async throws {
    let credentials = AppAIInMemoryCredentialStore(credentials: [.anthropic: "anthropic-key"])
    let transport = CapturingTransport { request in
        #expect(request.url?.path == "/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "anthropic-key")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let system = try #require(json["system"] as? String)
        #expect(system.contains("Return only one valid JSON object"))
        return response(for: request, body: #"{"model":"claude-test","content":[{"type":"text","text":"{\"ok\":true}"}],"stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":3}}"#)
    }
    let client = AnthropicMessagesClient(credentialStore: credentials, transport: transport, baseURL: URL(string: "https://example.com/v1")!)
    let result = try await client.generate(.init(
        model: "claude-test",
        messages: [.init(role: .user, content: "Return status")],
        responseFormat: .jsonObject
    ))
    #expect(result.text == #"{"ok":true}"#)
}

@Test func geminiClientMapsJSONSchemaToGenerationConfig() async throws {
    let credentials = AppAIInMemoryCredentialStore(credentials: [.gemini: "gemini-key"])
    let transport = CapturingTransport { request in
        #expect(request.url?.path == "/v1beta/models/gemini-test:generateContent")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "gemini-key")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let config = try #require(json["generationConfig"] as? [String: Any])
        #expect(config["responseMimeType"] as? String == "application/json")
        #expect(config["responseJsonSchema"] != nil)
        #expect(config["responseSchema"] == nil)
        return response(for: request, body: #"{"candidates":[{"content":{"parts":[{"text":"{\"dish\":\"Pho\"}"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":20,"candidatesTokenCount":8}}"#)
    }
    let client = GeminiGenerateContentClient(credentialStore: credentials, transport: transport, baseURL: URL(string: "https://example.com/v1beta")!)
    let result = try await client.generate(.init(
        model: "gemini-test",
        messages: [.init(role: .user, content: "Interpret menu")],
        responseFormat: .jsonSchema(.init(name: "menu", schema: .object(["type": .string("object")]))),
        maxOutputTokens: 500
    ))
    #expect(result.text == #"{"dish":"Pho"}"#)
}
