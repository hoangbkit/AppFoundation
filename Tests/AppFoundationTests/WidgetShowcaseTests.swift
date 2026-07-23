import XCTest
@testable import AppFoundationWidgetShowcase

final class WidgetShowcaseTests: XCTestCase {
    func testFamiliesProduceExpectedResponsiveRatios() {
        let small = WidgetShowcaseFamily.small.previewSize(availableWidth: 350)
        let medium = WidgetShowcaseFamily.medium.previewSize(availableWidth: 350)
        let large = WidgetShowcaseFamily.large.previewSize(availableWidth: 350)

        XCTAssertEqual(small.width, small.height, accuracy: 0.001)
        XCTAssertEqual(medium.width / medium.height, 2.08, accuracy: 0.001)
        XCTAssertEqual(large.width / large.height, 0.95, accuracy: 0.001)
    }

    func testSpecificGoalCreatesFamilyAndConfigurationSteps() {
        let guide = WidgetInstallGuideConfiguration(appName: "AF")
        let descriptor = WidgetShowcaseDescriptor(
            id: "commerce-small",
            title: "Commerce Pulse",
            subtitle: "Entitlement status",
            detail: "Shows current premium access.",
            family: .small,
            configurationName: "Commerce Pulse"
        )

        let steps = guide.steps(for: WidgetInstallGoal(descriptor: descriptor))

        XCTAssertEqual(steps.count, 5)
        XCTAssertEqual(steps[2].title, "Find AF")
        XCTAssertEqual(steps[3].title, "Add the small widget")
        XCTAssertEqual(steps[4].title, "Choose Commerce Pulse")
    }

    func testGeneralGoalOmitsConfigurationStep() {
        let guide = WidgetInstallGuideConfiguration(appName: "AF")
        let steps = guide.steps(for: .general)

        XCTAssertEqual(steps.count, 4)
        XCTAssertEqual(steps.last?.title, "Choose a size")
    }
}
