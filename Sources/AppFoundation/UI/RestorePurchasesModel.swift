#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

/// Copy and timing knobs for restore surfaces built on `RestorePurchasesRowModel`
/// (see `RestorePurchasesView`). Labels are intentionally short: the control renders
/// every state on a single line.
public struct RestorePurchasesRowConfiguration: Sendable {
    public var title: String
    public var restoringTitle: String
    public var successLabel: String
    public var nothingFoundLabel: String
    public var failureLabel: String
    public var timeoutLabel: String

    /// Accessibility label for the trailing cancel affordance shown mid-flight.
    public var cancelTitle: String

    /// How long to wait for the App Store before showing the timeout state.
    /// Generous by design — App Store sign-in plus two-factor authentication can
    /// take a while, and a timer firing mid-login reads as an error.
    public var timeout: Duration
    /// How long the success state shows before the control removes itself (Pro
    /// becomes active). Info/failure states revert to idle after `messageDuration`.
    public var successDuration: Duration
    /// How long info and failure labels stay visible before returning to idle.
    public var messageDuration: Duration

    public init(
        title: String = "Restore Purchases",
        restoringTitle: String = "Restoring purchases…",
        successLabel: String = "Purchases restored",
        nothingFoundLabel: String = "No purchases found",
        failureLabel: String = "Restore failed",
        timeoutLabel: String = "Timed out",
        cancelTitle: String = "Cancel",
        timeout: Duration = .seconds(60),
        successDuration: Duration = .seconds(2),
        messageDuration: Duration = .seconds(6)
    ) {
        self.title = title
        self.restoringTitle = restoringTitle
        self.successLabel = successLabel
        self.nothingFoundLabel = nothingFoundLabel
        self.failureLabel = failureLabel
        self.timeoutLabel = timeoutLabel
        self.cancelTitle = cancelTitle
        self.timeout = timeout
        self.successDuration = successDuration
        self.messageDuration = messageDuration
    }
}

/// Presentation state shared by restore surfaces.
///
/// Display derives from the shared `PurchaseManager`; local state only attributes
/// outcomes to the attempt this surface started and owns the auto-clear timers.
/// That keeps recycled or duplicated surfaces consistent with one another.
@MainActor
@Observable
final class RestorePurchasesRowModel {
    enum Phase: Equatable, Hashable {
        case idle
        case restoring
        case result(RestoreResult)
    }

    enum RestoreResult: Equatable, Hashable {
        case restored
        case nothingToRestore
        case failure(PurchaseFailure)
    }

    private(set) var phase: Phase = .idle
    private(set) var hasLocalAttemptInFlight = false

    private var attemptToken = 0
    private var clearTask: Task<Void, Never>?

    func start(
        using manager: PurchaseManager,
        configuration: RestorePurchasesRowConfiguration
    ) {
        guard phase != .restoring, !manager.isBusy else { return }

        clearTimers()
        attemptToken += 1
        let token = attemptToken
        hasLocalAttemptInFlight = true
        phase = .restoring

        Task { [weak self] in
            let outcome = await manager.restorePurchases(timeout: configuration.timeout)
            guard let self, token == self.attemptToken else { return }
            self.hasLocalAttemptInFlight = false
            self.resolve(outcome, using: manager, configuration: configuration)
        }
    }

    func cancel(using manager: PurchaseManager) {
        clearTimers()
        attemptToken += 1
        hasLocalAttemptInFlight = false
        phase = .idle
        manager.cancelRestore()
    }

    /// Realigns display state after interruptions such as scene suspension or a view
    /// being recycled while its attempt was abandoned.
    func reconcile(using manager: PurchaseManager) {
        guard phase == .restoring, !hasLocalAttemptInFlight else { return }
        guard !manager.isBusy else { return }
        phase = .idle
    }

    #if DEBUG
    /// Reaches the orphaned-restoring display state that `reconcile` exists to clean
    /// up — unreachable through the public flow because a local attempt always owns
    /// `hasLocalAttemptInFlight`.
    func _debugSetRestoring(localAttemptInFlight: Bool) {
        phase = .restoring
        hasLocalAttemptInFlight = localAttemptInFlight
    }
    #endif

    private func resolve(
        _ outcome: RestoreOutcome,
        using manager: PurchaseManager,
        configuration: RestorePurchasesRowConfiguration
    ) {
        switch outcome {
        case .restored:
            phase = .result(.restored)
            scheduleAutoClear(after: configuration.successDuration)
        case .nothingToRestore:
            phase = .result(.nothingToRestore)
            scheduleAutoClear(after: configuration.messageDuration)
        case .failed(let failure):
            // Keep the failure scoped to this surface instead of letting it surface
            // as a purchase error on other surfaces bound to `activity`.
            manager.clearActivity()
            if failure.code == .userCancelled {
                phase = .idle
            } else {
                phase = .result(.failure(failure))
                scheduleAutoClear(after: configuration.messageDuration)
            }
        }
    }

    private func scheduleAutoClear(after duration: Duration) {
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.clearResult()
        }
    }

    private func clearResult() {
        if case .result = phase {
            phase = .idle
        }
    }

    private func clearTimers() {
        clearTask?.cancel()
        clearTask = nil
    }
}
#endif
