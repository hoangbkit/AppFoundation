import Foundation

extension OpenAIResponsesRequest.Input {
    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("message", forKey: .type)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

extension GeminiRequest.GenerationConfig {
    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens
        case responseMimeType
        case responseJsonSchema
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            temperature,
            forKey: .temperature
        )
        try container.encodeIfPresent(
            maxOutputTokens,
            forKey: .maxOutputTokens
        )
        try container.encodeIfPresent(
            responseMimeType,
            forKey: .responseMimeType
        )
        try container.encodeIfPresent(
            responseJsonSchema,
            forKey: .responseJsonSchema
        )
    }
}
