import Foundation

struct AnthropicModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let displayName: String?
        let maxInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case maxInputTokens = "max_input_tokens"
        }
    }

    let data: [Model]
    let hasMore: Bool
    let lastID: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case lastID = "last_id"
    }
}
