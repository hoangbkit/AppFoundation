#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import AppFoundation

final class FoundationOnboardingTests: XCTestCase {
    func testConfigurationPreservesLegacyDefaults() {
        let configuration = FoundationOnboardingConfiguration()

        XCTAssertEqual(configuration.headerTitle, "WELCOME")
        XCTAssertEqual(configuration.headerSystemImage, "sparkles")
        XCTAssertTrue(configuration.showsSkipButton)
        XCTAssertEqual(configuration.skipTitle, "Skip")
        XCTAssertEqual(configuration.continueTitle, "Continue")
        XCTAssertEqual(configuration.completionTitle, "Get Started")
        XCTAssertTrue(configuration.showsPageIndicator)
        XCTAssertTrue(configuration.centersPageContent)
        XCTAssertEqual(configuration.contentHorizontalPadding, 24)
        XCTAssertEqual(configuration.contentVerticalPadding, 8)
    }

    func testConfigurationClampsNegativeContentPadding() {
        let configuration = FoundationOnboardingConfiguration(
            contentHorizontalPadding: -12,
            contentVerticalPadding: -8
        )

        XCTAssertEqual(configuration.contentHorizontalPadding, 0)
        XCTAssertEqual(configuration.contentVerticalPadding, 0)
    }

    @MainActor
    func testCustomBuilderAcceptsAppOwnedPages() {
        let pages = [TestOnboardingPage(id: "custom")]

        _ = FoundationOnboardingView(pages: pages) { page, context in
            Text("\(page.id)-\(context.index)")
        } onCompletion: {}
    }

    @MainActor
    func testLegacyInitializerRemainsAvailable() {
        _ = FoundationOnboardingView(
            pages: [
                FoundationOnboardingPage(
                    id: "legacy",
                    systemImage: "sparkles",
                    eyebrow: "Welcome",
                    title: "Legacy API",
                    message: "Existing call sites remain source-compatible."
                )
            ]
        ) {}
    }
}

private struct TestOnboardingPage: Identifiable {
    let id: String
}
#endif
