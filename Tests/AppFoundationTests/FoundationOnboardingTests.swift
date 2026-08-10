#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import AppFoundation

final class FoundationOnboardingTests: XCTestCase {
    func testConfigurationPreservesDefaults() {
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
        XCTAssertEqual(configuration.buttonAppearance, .legacyLight)
    }

    func testConfigurationClampsNegativeContentPadding() {
        let configuration = FoundationOnboardingConfiguration(
            contentHorizontalPadding: -12,
            contentVerticalPadding: -8
        )

        XCTAssertEqual(configuration.contentHorizontalPadding, 0)
        XCTAssertEqual(configuration.contentVerticalPadding, 0)
    }

    func testLegacyChromeConfigurationRemainsSourceCompatible() {
        let configuration = FoundationOnboardingConfiguration(
            headerTitle: nil,
            buttonAppearance: .themed
        )

        XCTAssertNil(configuration.headerTitle)
        XCTAssertEqual(configuration.buttonAppearance, .themed)
    }

    func testStandardPageAcceptsPerStepHeaderMetadata() {
        let page = FoundationOnboardingPage(
            id: "features",
            systemImage: "sparkles",
            eyebrow: "Features",
            title: "Everything you need",
            message: "A page with its own header pill.",
            headerTitle: "FEATURES",
            headerSystemImage: "square.grid.2x2.fill"
        )

        XCTAssertEqual(page.onboardingHeaderTitle, "FEATURES")
        XCTAssertEqual(page.onboardingHeaderSystemImage, "square.grid.2x2.fill")
    }

    @MainActor
    func testCustomBuilderAcceptsAppOwnedPages() {
        let pages = [TestOnboardingPage(id: "custom")]

        _ = FoundationOnboardingView(pages: pages) { page, context in
            Text("\(page.id)-\(context.index)")
        } onCompletion: {}
    }

    @MainActor
    func testCustomBuilderAcceptsPerStepHeaderProvider() {
        let pages = [
            TestHeaderOnboardingPage(
                id: "ready",
                onboardingHeaderTitle: "READY",
                onboardingHeaderSystemImage: "checkmark"
            )
        ]

        _ = FoundationOnboardingView(pages: pages) { page, _ in
            Text(page.id)
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

private struct TestHeaderOnboardingPage: Identifiable, FoundationOnboardingHeaderProviding {
    let id: String
    let onboardingHeaderTitle: String?
    let onboardingHeaderSystemImage: String?
}
#endif
