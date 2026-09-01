import AppFoundation
import SwiftUI

struct StartupResilienceDemoView: View {
    @Environment(\.appFoundationTheme) private var theme

    @State private var scenario: Scenario = .degraded
    @State private var report: StartupRunReport?
    @State private var isRunning = false
    @State private var isShowingRecovery = false

    var body: some View {
        List {
            Section("Scenario") {
                Picker("Startup outcome", selection: $scenario) {
                    ForEach(Scenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }

                Text(scenario.explanation)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)

                Button("Run simulated startup", systemImage: "play.fill") {
                    Task { await runSelectedScenario() }
                }
                .disabled(isRunning)
            }

            if isRunning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Running startup components…")
                    }
                }
            }

            if let report {
                resultSection(report)
                componentSection(report)
            }

            Section("Policy") {
                Text("Load → repair → retry → safe fallback. Only an exhausted required component blocks launch.")
                    .font(.callout)
                Text("Important and optional components may degrade or be skipped so one broken subsystem does not brick the app.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryForegroundColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppThemeBackground(theme: theme))
        .foregroundStyle(theme.primaryForegroundColor)
        .navigationTitle("Startup Resilience")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accentColor)
        .fullScreenCover(isPresented: $isShowingRecovery) {
            StartupRecoveryView(
                configuration: StartupRecoveryConfiguration(
                    title: "We Couldn't Open Your Data",
                    message: "The Demo exhausted every safe startup recovery path.",
                    dataSafetyMessage: "The simulated existing data has not been deleted.",
                    resetConfirmationMessage: "The Demo will clear the simulated failure and return to a healthy startup."
                ),
                style: StartupRecoveryStyle(
                    backgroundColor: theme.backgroundColor,
                    foregroundColor: theme.primaryForegroundColor,
                    secondaryForegroundColor: theme.secondaryForegroundColor,
                    accentColor: theme.accentColor,
                    cardColor: theme.surfaceColor
                ),
                retry: {
                    scenario = .healthy
                    await runSelectedScenario()
                    isShowingRecovery = false
                },
                makeRecoveryCopy: {
                    let text = fatalDiagnosticText
                    return try await ExportFileWriter().write(
                        Data(text.utf8),
                        filename: "AppFoundation Startup Recovery",
                        fileExtension: "txt"
                    )
                },
                startFresh: {
                    report = nil
                    scenario = .healthy
                    isShowingRecovery = false
                }
            )
        }
    }

    @ViewBuilder
    private func resultSection(_ report: StartupRunReport) -> some View {
        Section("Result") {
            LabeledContent("Can launch", value: report.canLaunch ? "Yes" : "No")
            LabeledContent("Readiness", value: readinessTitle(report.readiness))
            LabeledContent("Degraded components", value: "\(report.degradedComponents.count)")

            if case .failed = report.readiness {
                Button("Preview recovery screen", systemImage: "exclamationmark.triangle") {
                    isShowingRecovery = true
                }
            }
        }
    }

    private func componentSection(_ report: StartupRunReport) -> some View {
        Section("Components") {
            ForEach(Array(report.components.enumerated()), id: \.offset) { _, component in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(component.name)
                        Spacer()
                        Text(component.resolution.rawValue.capitalized)
                            .foregroundStyle(component.isDegraded ? .orange : theme.accentColor)
                    }
                    .font(.subheadline.weight(.semibold))

                    Text(component.criticality.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryForegroundColor)

                    if !component.diagnostics.isEmpty {
                        Text(component.diagnostics.map { "\($0.stage.rawValue): \($0.message)" }.joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    @MainActor
    private func runSelectedScenario() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let components = makeComponents(for: scenario)
        let newReport = await StartupResilience.run(components)
        report = newReport

        if case .failed = newReport.readiness {
            isShowingRecovery = true
        }
    }

    private func makeComponents(for scenario: Scenario) -> [StartupComponent] {
        switch scenario {
        case .healthy:
            return [
                StartupComponent(id: "data", name: "Main Data") {},
                StartupComponent(id: "cache", name: "Derived Cache", criticality: .optional) {},
            ]

        case .repaired:
            let state = DemoRepairState()
            return [
                StartupComponent(
                    id: "data",
                    name: "Main Data",
                    operation: {
                        guard await state.isRepaired else { throw StartupDemoError.needsRepair }
                    },
                    repair: {
                        await state.markRepaired()
                    }
                )
            ]

        case .degraded:
            return [
                StartupComponent(id: "data", name: "Main Data") {},
                StartupComponent(
                    id: "search-index",
                    name: "Search Index",
                    criticality: .important,
                    operation: { throw StartupDemoError.corruptDerivedData },
                    fallback: {
                        // The app has explicitly decided that an empty index is a safe state.
                    }
                ),
            ]

        case .fatal:
            return [
                StartupComponent(
                    id: "database",
                    name: "Primary Database",
                    criticality: .required,
                    operation: { throw StartupDemoError.databaseUnavailable },
                    repair: { throw StartupDemoError.repairFailed },
                    fallback: { throw StartupDemoError.fallbackFailed }
                )
            ]
        }
    }

    private func readinessTitle(_ readiness: StartupReadiness) -> String {
        switch readiness {
        case .ready: "Ready"
        case .degraded: "Degraded but ready"
        case .failed: "Blocked"
        }
    }

    private var fatalDiagnosticText: String {
        guard let report, case .failed(let failure) = report.readiness else {
            return "No fatal startup failure is currently available."
        }
        return failure.diagnosticText
    }
}

private enum Scenario: String, CaseIterable, Identifiable {
    case healthy
    case repaired
    case degraded
    case fatal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthy: "Healthy"
        case .repaired: "Auto-repaired"
        case .degraded: "Safe fallback"
        case .fatal: "Fatal"
        }
    }

    var explanation: String {
        switch self {
        case .healthy:
            "Every component loads normally."
        case .repaired:
            "The first load fails, repair runs, and the original operation succeeds on retry."
        case .degraded:
            "A noncritical derived index fails and explicitly falls back to an empty safe state."
        case .fatal:
            "A required database fails load, repair, and fallback, so the last-resort recovery screen appears."
        }
    }
}

private enum StartupDemoError: LocalizedError, Sendable {
    case needsRepair
    case corruptDerivedData
    case databaseUnavailable
    case repairFailed
    case fallbackFailed

    var errorDescription: String? {
        switch self {
        case .needsRepair: "The data needs repair."
        case .corruptDerivedData: "The derived index is corrupt."
        case .databaseUnavailable: "The primary database could not be opened."
        case .repairFailed: "Automatic repair did not succeed."
        case .fallbackFailed: "No safe fallback could be established."
        }
    }
}

private actor DemoRepairState {
    private(set) var isRepaired = false

    func markRepaired() {
        isRepaired = true
    }
}
