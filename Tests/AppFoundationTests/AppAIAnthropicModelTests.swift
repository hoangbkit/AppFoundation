import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppFoundation

private actor AnthropicModelTransport: AppAITransport {
    private var requests: [URLRequest] = []

    func data(
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)

        let components = try #require(
            URLComponents(
                url: try #require(request.url),
                resolvingAgainstBaseURL: false
            )
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            }
        )

        #expect(query["limit"] == "1000")
        #expect(
            request.value(forHTTPHeaderField: "x-api-key")
                == "anthropic-key"
        )
        #expect(
            request.value(forHTTPHeaderField: "anthropic-version")
                == "2023-06-01"
        )

        let body: String
        if requests.count == 1 {
            #expect(query["after_id"] == nil)
            body = #"""
            {
                "data": [
                    {
                        "id": "claude-model-a",
                        "display_name": "Claude Model A",
                        "max_input_tokens": 200000
                    }
                ],
                "has_more": true,
                "last_id": "claude-model-a"
            }
            """#
        } else {
            #expect(query["after_id"] == "claude-model-a")
            body = #"""
            {
                "data": [
                    {
                        "id": "claude-model-b",
                        "display_name": "Claude Model B",
                        "max_input_tokens": 100000
                    }
                ],
                "has_more": false,
                "last_id": "claude-model-b"
            }
            """#
        }

        return (
            Data(body.utf8),
            HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    func count() -> Int {
        requests.count
    }
}

@Test
func anthropicModelDiscoveryPaginatesAndMapsContextLength() async throws {
    let credentialStore = AppAIInMemoryCredentialStore(
        credentials: [.anthropic: "anthropic-key"]
    )
    let transport = AnthropicModelTransport()
    let client = AnthropicMessagesClient(
        credentialStore: credentialStore,
        transport: transport,
        baseURL: URL(string: "https://example.com/v1")!
    )

    let models = try await client.availableModels()

    #expect(models.map(\.id) == ["claude-model-a", "claude-model-b"])
    #expect(
        models.map(\.displayName)
            == ["Claude Model A", "Claude Model B"]
    )
    #expect(models.map(\.contextLength) == [200_000, 100_000])
    #expect(await transport.count() == 2)
}
