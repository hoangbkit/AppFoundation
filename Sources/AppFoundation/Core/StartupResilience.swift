import Foundation

public enum StartupComponentCriticality: String, Sendable, Equatable, CaseIterable {
    /// Startup cannot safely continue unless this component loads or reaches an explicit fallback state.
    case required

    /// The app can launch without this component, but should treat the result as degraded.
    case important

    /// The app can launch without this component and may choose not to surface the degradation.
    case optional
}

public struct StartupComponent: Sendable {
    public let id: String
    public let name: String
    public let criticality: StartupComponentCriticality

    let operation: @Sendable () async throws -> Void
    let repair: (@Sendable () async throws -> Void)?
    let fallback: (@Sendable () async throws -> Void)?

    public init(
        id: String,
        name: String,
        criticality: StartupComponentCriticality = .required,
        operation: @escaping @Sendable () async throws -> Void,
        repair: (@Sendable () async throws -> Void)? = nil,
        fallback: (@Sendable () async throws -> Void)? = nil
    ) {
        self.id = id
        self.name = name
        self.criticality = criticality
        self.operation = operation
        self.repair = repair
        self.fallback = fallback
    }
}

public enum StartupAttemptStage: String, Sendable, Equatable {
    case operation
    case repair
    case retry
    case fallback
}

public struct StartupDiagnostic: Sendable, Equatable {
    public let stage: StartupAttemptStage
    public let message: String

    public init(stage: StartupAttemptStage, message: String) {
        self.stage = stage
        self.message = message
    }
}

public enum StartupComponentResolution: String, Sendable, Equatable {
    case ready
    case repaired
    case fallback
    case skipped
}

public struct StartupComponentReport: Sendable, Equatable {
    public let id: String
    public let name: String
    public let criticality: StartupComponentCriticality
    public let resolution: StartupComponentResolution
    public let diagnostics: [StartupDiagnostic]

    public init(
        id: String,
        name: String,
        criticality: StartupComponentCriticality,
        resolution: StartupComponentResolution,
        diagnostics: [StartupDiagnostic] = []
    ) {
        self.id = id
        self.name = name
        self.criticality = criticality
        self.resolution = resolution
        self.diagnostics = diagnostics
    }

    public var isDegraded: Bool {
        switch resolution {
        case .ready, .repaired:
            false
        case .fallback, .skipped:
            true
        }
    }
}

public struct StartupFatalFailure: Sendable, Equatable {
    public let componentID: String
    public let componentName: String
    public let diagnostics: [StartupDiagnostic]

    public init(
        componentID: String,
        componentName: String,
        diagnostics: [StartupDiagnostic]
    ) {
        self.componentID = componentID
        self.componentName = componentName
        self.diagnostics = diagnostics
    }

    public var diagnosticText: String {
        let details = diagnostics
            .map { "\($0.stage.rawValue): \($0.message)" }
            .joined(separator: "\n")
        return "Startup failed in \(componentName) [\(componentID)]\n\(details)"
    }
}

public enum StartupReadiness: Sendable, Equatable {
    case ready
    case degraded
    case failed(StartupFatalFailure)
}

public struct StartupRunReport: Sendable, Equatable {
    public let readiness: StartupReadiness
    public let components: [StartupComponentReport]

    public init(readiness: StartupReadiness, components: [StartupComponentReport]) {
        self.readiness = readiness
        self.components = components
    }

    public var degradedComponents: [StartupComponentReport] {
        components.filter(\.isDegraded)
    }

    public var canLaunch: Bool {
        if case .failed = readiness { return false }
        return true
    }
}

public struct StartupProgress: Sendable, Equatable {
    public let completedCount: Int
    public let totalCount: Int
    public let currentComponentID: String?
    public let currentComponentName: String?

    public init(
        completedCount: Int,
        totalCount: Int,
        currentComponentID: String?,
        currentComponentName: String?
    ) {
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.currentComponentID = currentComponentID
        self.currentComponentName = currentComponentName
    }
}

public enum StartupResilience {
    public typealias ProgressHandler = @Sendable (StartupProgress) async -> Void

    /// Runs startup components in order.
    ///
    /// A failed operation first gets an optional repair attempt. A successful repair is followed by
    /// a retry of the original operation. If loading still fails, an optional fallback may establish
    /// a safe degraded state. Required components stop startup only after all configured recovery
    /// paths are exhausted. Important and optional components may be skipped so the app can launch.
    public static func run(
        _ components: [StartupComponent],
        progress: ProgressHandler? = nil
    ) async -> StartupRunReport {
        var reports: [StartupComponentReport] = []
        let total = components.count

        for (index, component) in components.enumerated() {
            await progress?(
                StartupProgress(
                    completedCount: index,
                    totalCount: total,
                    currentComponentID: component.id,
                    currentComponentName: component.name
                )
            )

            let result = await run(component)
            reports.append(result.report)

            if let fatalFailure = result.fatalFailure {
                await progress?(
                    StartupProgress(
                        completedCount: reports.count,
                        totalCount: total,
                        currentComponentID: nil,
                        currentComponentName: nil
                    )
                )
                return StartupRunReport(
                    readiness: .failed(fatalFailure),
                    components: reports
                )
            }
        }

        await progress?(
            StartupProgress(
                completedCount: reports.count,
                totalCount: total,
                currentComponentID: nil,
                currentComponentName: nil
            )
        )

        return StartupRunReport(
            readiness: reports.contains(where: \.isDegraded) ? .degraded : .ready,
            components: reports
        )
    }

    private static func run(
        _ component: StartupComponent
    ) async -> (report: StartupComponentReport, fatalFailure: StartupFatalFailure?) {
        do {
            try await component.operation()
            return (report(component, resolution: .ready), nil)
        } catch {
            var diagnostics = [diagnostic(stage: .operation, error: error)]

            if let repair = component.repair {
                do {
                    try await repair()
                    do {
                        try await component.operation()
                        return (report(component, resolution: .repaired, diagnostics: diagnostics), nil)
                    } catch {
                        diagnostics.append(diagnostic(stage: .retry, error: error))
                    }
                } catch {
                    diagnostics.append(diagnostic(stage: .repair, error: error))
                }
            }

            if let fallback = component.fallback {
                do {
                    try await fallback()
                    return (report(component, resolution: .fallback, diagnostics: diagnostics), nil)
                } catch {
                    diagnostics.append(diagnostic(stage: .fallback, error: error))
                }
            }

            let skipped = report(component, resolution: .skipped, diagnostics: diagnostics)
            guard component.criticality == .required else {
                return (skipped, nil)
            }

            return (
                skipped,
                StartupFatalFailure(
                    componentID: component.id,
                    componentName: component.name,
                    diagnostics: diagnostics
                )
            )
        }
    }

    private static func report(
        _ component: StartupComponent,
        resolution: StartupComponentResolution,
        diagnostics: [StartupDiagnostic] = []
    ) -> StartupComponentReport {
        StartupComponentReport(
            id: component.id,
            name: component.name,
            criticality: component.criticality,
            resolution: resolution,
            diagnostics: diagnostics
        )
    }

    private static func diagnostic(stage: StartupAttemptStage, error: any Error) -> StartupDiagnostic {
        StartupDiagnostic(stage: stage, message: error.localizedDescription)
    }
}
