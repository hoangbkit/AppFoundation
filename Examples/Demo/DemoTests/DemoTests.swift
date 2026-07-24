import AppFoundation
import XCTest

@testable import Demo

@MainActor
final class DemoTests: XCTestCase {
    func testPurchaseConfigurationUsesAllSupportedPlansInOrder() {
        XCTAssertEqual(
            DemoConfiguration.purchases.productIDs,
            [
                DemoConfiguration.weeklyProductID,
                DemoConfiguration.monthlyProductID,
                DemoConfiguration.yearlyProductID,
                DemoConfiguration.lifetimeProductID,
            ]
        )
        XCTAssertEqual(
            DemoConfiguration.purchases.preferredProductID,
            DemoConfiguration.yearlyProductID
        )
    }

    func testSimulatedCatalogContainsWeeklyAndLifetimePlans() {
        let weekly = DemoConfiguration.simulatedProducts.first {
            $0.id == DemoConfiguration.weeklyProductID
        }
        let lifetime = DemoConfiguration.simulatedProducts.first {
            $0.id == DemoConfiguration.lifetimeProductID
        }

        XCTAssertEqual(weekly?.subscriptionPeriod, .init(value: 1, unit: .week))
        XCTAssertTrue(lifetime?.isLifetime == true)
        XCTAssertNil(lifetime?.subscriptionPeriod)
    }

    func testModernPaywallPrefersAndHighlightsYearlyProduct() {
        XCTAssertEqual(
            DemoConfiguration.modernPaywall.preferredProductID,
            DemoConfiguration.purchases.preferredProductID
        )
        XCTAssertEqual(
            DemoConfiguration.modernPaywall.highlightedProductID,
            DemoConfiguration.yearlyProductID
        )
        XCTAssertFalse(DemoConfiguration.modernPaywall.features.isEmpty)
    }

    func testAllPaywallsFollowActiveThemeByDefault() {
        XCTAssertNil(DemoConfiguration.modernPaywall.tint)
        XCTAssertNil(DemoConfiguration.modernPaywall.themeOverride)

        XCTAssertTrue(DemoConfiguration.legacyPaywall.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.legacyPaywall.themeOverride)

        XCTAssertTrue(DemoConfiguration.legacyClaudePaywall.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.legacyClaudePaywall.themeOverride)
    }

    func testSettingsFollowActiveThemeByDefault() {
        XCTAssertTrue(DemoConfiguration.settings.followsActiveTheme)
        XCTAssertNil(DemoConfiguration.settings.themeOverride)
    }

    func testExplicitFoundationThemeRemainsFixed() {
        let paywall = FoundationPaywallConfiguration(
            title: "Fixed",
            subtitle: "Compatibility",
            features: [],
            theme: .indigo
        )
        let settings = FoundationSettingsConfiguration(
            appName: "Fixed",
            theme: .indigo
        )

        XCTAssertFalse(paywall.followsActiveTheme)
        XCTAssertNil(paywall.themeOverride)
        XCTAssertFalse(settings.followsActiveTheme)
        XCTAssertNil(settings.themeOverride)
    }

    func testBackupConfigurationMatchesDemoBundle() {
        XCTAssertEqual(
            DemoConfiguration.backupConfiguration.appIdentifier,
            "com.hoangbkit.afdemo"
        )
        XCTAssertEqual(DemoConfiguration.backupConfiguration.fileExtension, "afdemo")
    }

    func testSampleDeepLinkIsStable() {
        XCTAssertEqual(
            DemoConfiguration.sampleDeepLink.url?.absoluteString,
            "appfoundation-demo://showcase/exports/latest?source=widget"
        )
    }

    func testOnboardingHasStableUniqueIdentifiers() {
        let identifiers = DemoConfiguration.onboardingPages.map(\.id)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertFalse(identifiers.isEmpty)
    }

    func testScreenshotTemplateGalleryRegistersEveryPublicTemplate() {
        let settings = ScreenshotTemplateDemoSettings()
        let catalog = ScreenshotTemplateDemoCatalog.make(settings: settings)
        let identifiers = catalog.screenshots.map(\.id)

        XCTAssertEqual(identifiers, ScreenshotTemplateDemoCatalog.templateIDs)
        XCTAssertEqual(identifiers.count, 10)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(
            catalog.presets.map(\.id),
            [
                ScreenshotDevicePreset.iPhone69Portrait.id,
                ScreenshotDevicePreset.iPhone65Portrait.id,
            ]
        )
    }

    func testPromoVideoDemoRegistersTheCompleteStory() {
        let settings = DemoPromoVideoSettings()
        let project = DemoPromoVideoProject.make(settings: settings)
        let identifiers = project.scenes.map(\.id)

        XCTAssertEqual(identifiers, DemoPromoVideoProject.sceneIDs)
        XCTAssertEqual(identifiers.count, 6)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(project.defaultPresetID, PromoVideoOutputPreset.verticalFullHD.id)
        XCTAssertEqual(project.defaultFrameRate, .fps30)
        XCTAssertGreaterThan(project.totalDuration, 10)
    }

    func testPromoVideoTimelineUsesOverlappingTransitions() {
        let settings = DemoPromoVideoSettings()
        let project = DemoPromoVideoProject.make(settings: settings)
        let starts = project.sceneStartTimes

        XCTAssertEqual(starts.first, 0)
        XCTAssertEqual(starts.count, project.scenes.count)
        XCTAssertLessThan(starts[1], project.scenes[0].duration)
        XCTAssertGreaterThan(project.totalDuration, starts.last ?? 0)
    }
}
