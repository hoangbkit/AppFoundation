import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoAIConfigurationTests: XCTestCase {
    func testCatalogIncludesManagedAndDraftXStyleDirectProviders() {
        XCTAssertEqual(
            DemoAIConfiguration.catalog.backends.map(\.id),
            [
                .managed,
                .direct(.openRouter),
                .direct(.openAI),
                .direct(.anthropic),
                .direct(.gemini),
                .direct(.deepSeek),
                .direct(.nvidia),
            ]
        )
        XCTAssertEqual(
            DemoAIConfiguration.catalog.defaultBackendID,
            .managed
        )
    }

    func testManagedAndDirectGuaranteesStayDistinct() {
        let managed = DemoAIConfiguration.catalog.descriptor(for: .managed)
        let openAI = DemoAIConfiguration.catalog.descriptor(
            for: .direct(.openAI)
        )

        XCTAssertTrue(managed?.capabilities.providesManagedUsage == true)
        XCTAssertTrue(managed?.capabilities.guaranteesIdempotentReplay == true)
        XCTAssertFalse(openAI?.capabilities.providesManagedUsage == true)
        XCTAssertFalse(openAI?.capabilities.guaranteesIdempotentReplay == true)
    }

    func testManagerStartsWithAppOwnedPreferredModels() {
        let manager = DemoAIConfiguration.makeManager()

        XCTAssertEqual(manager.selectedBackendID, .managed)
        XCTAssertEqual(manager.model(for: .openRouter), "openai/gpt-4.1-mini")
        XCTAssertEqual(manager.model(for: .openAI), "gpt-4.1-mini")
        XCTAssertEqual(manager.model(for: .anthropic), "claude-haiku-4-5-20251001")
        XCTAssertEqual(manager.model(for: .gemini), "gemini-2.5-flash")
        XCTAssertEqual(manager.model(for: .deepSeek), "deepseek-chat")
        XCTAssertEqual(manager.model(for: .nvidia), "meta/llama-3.1-70b-instruct")
    }
}
