import XCTest
@testable import AppFoundation

final class StartupResilienceTests: XCTestCase {
    func testReadyComponentsRunInOrder() async {
        let recorder = StartupRecorder()
        let components = [
            StartupComponent(id: "one", name: "One") {
                await recorder.append("one")
            },
            StartupComponent(id: "two", name: "Two") {
                await recorder.append("two")
            },
        ]

        let report = await StartupResilience.run(components)

        XCTAssertEqual(report.readiness, .ready)
        XCTAssertTrue(report.canLaunch)
        XCTAssertEqual(report.components.map(\.resolution), [.ready, .ready])
        XCTAssertEqual(await recorder.values(), ["one", "two"])
    }

    func testRepairRetriesOriginalOperation() async {
        let state = StartupRepairState()
        let component = StartupComponent(
            id: "cache",
            name: "Cache",
            criticality: .important,
            operation: {
                guard await state.isRepaired else { throw TestError.failed }
                await state.recordLoad()
            },
            repair: {
                await state.repair()
            }
        )

        let report = await StartupResilience.run([component])

        XCTAssertEqual(report.readiness, .ready)
        XCTAssertEqual(report.components.first?.resolution, .repaired)
        XCTAssertEqual(report.components.first?.diagnostics.map(\.stage), [.operation])
        XCTAssertEqual(await state.loadCount, 1)
    }

    func testFallbackCreatesDegradedReadyState() async {
        let recorder = StartupRecorder()
        let component = StartupComponent(
            id: "projects",
            name: "Projects",
            criticality: .required,
            operation: { throw TestError.failed },
            fallback: {
                await recorder.append("empty-projects")
            }
        )

        let report = await StartupResilience.run([component])

        XCTAssertEqual(report.readiness, .degraded)
        XCTAssertTrue(report.canLaunch)
        XCTAssertEqual(report.components.first?.resolution, .fallback)
        XCTAssertEqual(await recorder.values(), ["empty-projects"])
    }

    func testOptionalFailureIsSkippedAndStartupContinues() async {
        let recorder = StartupRecorder()
        let components = [
            StartupComponent(
                id: "analytics-cache",
                name: "Analytics Cache",
                criticality: .optional,
                operation: { throw TestError.failed }
            ),
            StartupComponent(id: "content", name: "Content") {
                await recorder.append("content")
            },
        ]

        let report = await StartupResilience.run(components)

        XCTAssertEqual(report.readiness, .degraded)
        XCTAssertEqual(report.components.map(\.resolution), [.skipped, .ready])
        XCTAssertEqual(await recorder.values(), ["content"])
    }

    func testRequiredFailureStopsLaterComponents() async {
        let recorder = StartupRecorder()
        let components = [
            StartupComponent(
                id: "database",
                name: "Database",
                operation: { throw TestError.failed },
                repair: { throw TestError.failed },
                fallback: { throw TestError.failed }
            ),
            StartupComponent(id: "later", name: "Later") {
                await recorder.append("later")
            },
        ]

        let report = await StartupResilience.run(components)

        XCTAssertFalse(report.canLaunch)
        XCTAssertEqual(report.components.count, 1)
        XCTAssertEqual(
            report.components.first?.diagnostics.map(\.stage),
            [.operation, .repair, .fallback]
        )
        XCTAssertEqual(await recorder.values(), [])

        guard case .failed(let failure) = report.readiness else {
            return XCTFail("Expected fatal startup failure")
        }
        XCTAssertEqual(failure.componentID, "database")
        XCTAssertTrue(failure.diagnosticText.contains("Database"))
    }

    func testProgressReportsCurrentComponentAndCompletion() async {
        let recorder = StartupProgressRecorder()
        let components = [
            StartupComponent(id: "one", name: "One") {},
            StartupComponent(id: "two", name: "Two") {},
        ]

        _ = await StartupResilience.run(components) { progress in
            await recorder.append(progress)
        }

        let values = await recorder.values()
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].currentComponentID, "one")
        XCTAssertEqual(values[0].completedCount, 0)
        XCTAssertEqual(values[1].currentComponentID, "two")
        XCTAssertEqual(values[1].completedCount, 1)
        XCTAssertNil(values[2].currentComponentID)
        XCTAssertEqual(values[2].completedCount, 2)
    }
}

private enum TestError: Error {
    case failed
}

private actor StartupRecorder {
    private var storage: [String] = []

    func append(_ value: String) {
        storage.append(value)
    }

    func values() -> [String] {
        storage
    }
}

private actor StartupProgressRecorder {
    private var storage: [StartupProgress] = []

    func append(_ value: StartupProgress) {
        storage.append(value)
    }

    func values() -> [StartupProgress] {
        storage
    }
}

private actor StartupRepairState {
    private(set) var isRepaired = false
    private(set) var loadCount = 0

    func repair() {
        isRepaired = true
    }

    func recordLoad() {
        loadCount += 1
    }
}
