import Foundation

/// Creates a fresh Foundation codec for every operation so concurrent direct
/// provider actors never share mutable encoder or decoder instances.
enum AppAIDirectCodec {
    static func encode<Value: Encodable>(
        _ value: Value
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type = Value.self,
        from data: Data
    ) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AppAIDirectError.invalidResponse
        }
    }
}
