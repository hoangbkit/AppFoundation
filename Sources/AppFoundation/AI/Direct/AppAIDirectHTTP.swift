import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum AppAIDirectHTTP {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder = JSONDecoder()

    static func endpoint(_ baseURL: URL, _ path: String) -> URL {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(relative)
    }

    static func request(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    static func validatedModel(_ value: String) throws -> String {
        let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw AppAIDirectError.invalidModel }
        return model
    }

    static func validatedMessages(
        _ values: [AppAIMessage]
    ) throws -> [AppAIMessage] {
        let messages = values.compactMap { message -> AppAIMessage? in
            let content = message.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return content.isEmpty
                ? nil
                : AppAIMessage(role: message.role, content: content)
        }
        guard !messages.isEmpty else {
            throw AppAIDirectError.invalidRequest(
                "At least one non-empty message is required."
            )
        }
        return messages
    }

    static func requiredCredential(
        _ providerID: AppAIProviderID,
        store: any AppAICredentialStoring
    ) async throws -> String {
        guard let value = try await store.credential(for: providerID)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            throw AppAIDirectError.missingCredential(providerID)
        }
        return value
    }

    static func apply(
        authentication: AppAIProviderAuthentication,
        credential: String,
        request: inout URLRequest,
        url: inout URL
    ) {
        switch authentication {
        case .bearer:
            request.setValue(
                "Bearer \(credential)",
                forHTTPHeaderField: "Authorization"
            )
        case .header(let name):
            request.setValue(credential, forHTTPHeaderField: name)
        case .query(let name):
            guard var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ) else {
                return
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: name, value: credential))
            components.queryItems = items
            if let updated = components.url { url = updated }
        }
    }

    static func perform(
        _ request: URLRequest,
        transport: any AppAITransport,
        completionUnknown: Bool
    ) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppAIDirectError {
            throw error
        } catch {
            throw AppAIDirectError.transport(
                message: error.localizedDescription,
                completionUnknown: completionUnknown
            )
        }
        guard (200..<300).contains(response.statusCode) else {
            throw error(data: data, response: response)
        }
        return data
    }

    static func decode<Value: Decodable>(_ data: Data) throws -> Value {
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw AppAIDirectError.invalidResponse
        }
    }

    static func response(
        text: String,
        providerID: AppAIProviderID,
        modelID: String,
        finishReason: String?,
        usage: AppAIDirectUsage?
    ) throws -> AppAIDirectResponse {
        let normalized = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else {
            throw AppAIDirectError.emptyOutput
        }
        return AppAIDirectResponse(
            text: normalized,
            providerID: providerID,
            modelID: modelID,
            finishReason: finishReason,
            usage: usage
        )
    }

    static func error(
        data: Data,
        response: HTTPURLResponse
    ) -> AppAIDirectError {
        let message = providerMessage(data: data)
            ?? HTTPURLResponse.localizedString(
                forStatusCode: response.statusCode
            )
        let lowered = message.lowercased()
        switch response.statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .permissionDenied
        case 402:
            return .insufficientCredits
        case 404 where lowered.contains("model"):
            return .modelUnavailable
        case 429:
            if lowered.contains("credit")
                || lowered.contains("quota")
                || lowered.contains("billing") {
                return .insufficientCredits
            }
            return .rateLimited(
                retryAfter: response.value(
                    forHTTPHeaderField: "Retry-After"
                )
            )
        default:
            if lowered.contains("model")
                && (lowered.contains("not found")
                    || lowered.contains("unavailable")) {
                return .modelUnavailable
            }
            return .provider(
                status: response.statusCode,
                message: message
            )
        }
    }

    static func providerMessage(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let dictionary = object as? [String: Any] {
            if let message = dictionary["message"] as? String {
                return message
            }
            if let error = dictionary["error"] as? String {
                return error
            }
            if let error = dictionary["error"] as? [String: Any] {
                if let message = error["message"] as? String {
                    return message
                }
                if let detail = error["detail"] as? String {
                    return detail
                }
            }
        }
        return nil
    }
}

extension AppAIResponseFormat {
    var schemaValue: AppAIJSONValue? {
        guard case .jsonSchema(let schema) = self else { return nil }
        return schema.schema
    }
}

struct OpenAIResponsesRequest: Encodable {
    struct Input: Encodable {
        struct Content: Encodable {
            let type = "input_text"
            let text: String
        }

        let type = "message"
        let role: String
        let content: [Content]

        init(_ message: AppAIMessage) {
            role = message.role.rawValue
            content = [.init(text: message.content)]
        }
    }

    struct Text: Encodable {
        struct Format: Encodable {
            let type: String
            let name: String?
            let schema: AppAIJSONValue?
            let strict: Bool?
        }

        let format: Format

        init?(format: AppAIResponseFormat) {
            switch format {
            case .text:
                return nil
            case .jsonObject:
                self.format = .init(
                    type: "json_object",
                    name: nil,
                    schema: nil,
                    strict: nil
                )
            case .jsonSchema(let schema):
                self.format = .init(
                    type: "json_schema",
                    name: schema.name,
                    schema: schema.schema,
                    strict: schema.strict
                )
            }
        }
    }

    let model: String
    let input: [Input]
    let temperature: Double?
    let maxOutputTokens: Int?
    let store: Bool
    let text: Text?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case temperature
        case store
        case text
        case maxOutputTokens = "max_output_tokens"
    }
}

struct OpenAIResponsesResponse: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String?
            let text: String?
        }

        let content: [Content]
    }

    struct Usage: Decodable {
        struct Details: Decodable {
            let cachedTokens: Int?

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
            }
        }

        let inputTokens: Int?
        let outputTokens: Int?
        let inputTokensDetails: Details?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case inputTokensDetails = "input_tokens_details"
        }
    }

    let model: String?
    let status: String?
    let output: [Output]
    let usage: Usage?
}

struct AnthropicRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [Message]
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case system
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

struct AnthropicResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheReadInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
    }

    let model: String?
    let content: [Content]
    let stopReason: String?
    let usage: Usage?

    enum CodingKeys: String, CodingKey {
        case model
        case content
        case usage
        case stopReason = "stop_reason"
    }
}

struct GeminiRequest: Encodable {
    struct Part: Encodable {
        let text: String
    }

    struct Content: Encodable {
        let role: String?
        let parts: [Part]
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?
        let responseMimeType: String?
        let responseJsonSchema: AppAIJSONValue?
    }

    let systemInstruction: Content?
    let contents: [Content]
    let generationConfig: GenerationConfig
}

struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content
        let finishReason: String?
    }

    struct Usage: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let cachedContentTokenCount: Int?
    }

    let candidates: [Candidate]
    let usageMetadata: Usage?
}

struct GeminiModelsResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let displayName: String?
        let inputTokenLimit: Int?
        let supportedGenerationMethods: [String]?
    }

    let models: [Model]
    let nextPageToken: String?
}

struct OpenAICompatibleRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        struct JSONSchema: Encodable {
            let name: String
            let schema: AppAIJSONValue
            let strict: Bool
        }

        let type: String
        let jsonSchema: JSONSchema?

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }

        init?(_ format: AppAIResponseFormat) {
            switch format {
            case .text:
                return nil
            case .jsonObject:
                type = "json_object"
                jsonSchema = nil
            case .jsonSchema(let schema):
                type = "json_schema"
                jsonSchema = .init(
                    name: schema.name,
                    schema: schema.schema,
                    strict: schema.strict
                )
            }
        }
    }

    let model: String
    let messages: [Message]
    let temperature: Double?
    let maxTokens: Int?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

enum FlexibleText: Decodable {
    struct Part: Decodable {
        let type: String?
        let text: String?
    }

    case string(String)
    case parts([Part])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .parts(try container.decode([Part].self))
        }
    }

    var textValue: String {
        switch self {
        case .string(let value):
            value
        case .parts(let parts):
            parts.compactMap(\.text).joined()
        }
    }
}

struct OpenAICompatibleResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: FlexibleText
        }

        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Decodable {
        struct Details: Decodable {
            let cachedTokens: Int?

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
            }
        }

        let promptTokens: Int?
        let completionTokens: Int?
        let promptTokensDetails: Details?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case promptTokensDetails = "prompt_tokens_details"
        }
    }

    let model: String?
    let choices: [Choice]
    let usage: Usage?
}

struct StandardModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let displayName: String?
        let contextLength: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case displayName = "display_name"
            case contextLength = "context_length"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )
            id = try container.decode(String.self, forKey: .id)
            displayName = try container.decodeIfPresent(
                String.self,
                forKey: .displayName
            ) ?? container.decodeIfPresent(
                String.self,
                forKey: .name
            )
            contextLength = try container.decodeIfPresent(
                Int.self,
                forKey: .contextLength
            )
        }
    }

    let data: [Model]
}
