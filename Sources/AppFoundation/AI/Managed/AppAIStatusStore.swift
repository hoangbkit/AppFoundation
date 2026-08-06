import Foundation
import Observation
#if canImport(StoreKit)
import StoreKit
#endif

public protocol AppAIStatusServing: Sendable {
    func status() async throws -> AppAIStatus
    func syncCurrentEntitlements() async throws -> AppAIStatus
}

#if canImport(StoreKit)
extension AppAIClient: AppAIStatusServing {}
#endif

@MainActor
@Observable
public final class AppAIStatusStore {
    public static let defaultFreshnessInterval: TimeInterval = 60

    public enum State: Sendable {
        case idle
        case refreshing
        case current(AppAIStatus, updatedAt: Date)
        case stale(AppAIStatus, updatedAt: Date, error: AppAIError)
        case failed(AppAIError)
    }

    public private(set) var state: State = .idle

    @ObservationIgnored private let client: (any AppAIStatusServing)?
    @ObservationIgnored private let configurationError: AppAIError?
    @ObservationIgnored private let freshnessInterval: TimeInterval
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var activeRefreshID: UUID?
    @ObservationIgnored private var activeRefreshSyncEntitlements = false
    @ObservationIgnored private var stateBeforeRefresh: State?
    @ObservationIgnored private var queuedSyncEntitlements = false

    public init(
        client: (any AppAIStatusServing)?,
        configurationError: AppAIError? = nil,
        freshnessInterval: TimeInterval = AppAIStatusStore.defaultFreshnessInterval
    ) {
        self.client = client
        self.configurationError = configurationError
        self.freshnessInterval = max(0, freshnessInterval)
    }

    public var status: AppAIStatus? {
        switch state {
        case .current(let status, _), .stale(let status, _, _): status
        case .idle, .refreshing, .failed: nil
        }
    }

    public var usage: AppAIUsage? { status?.usage }

    public var isRefreshing: Bool {
        guard case .refreshing = state else { return false }
        return true
    }

    public var isFresh: Bool {
        hasFreshStatus(maxAge: freshnessInterval)
    }

    public var isStale: Bool {
        guard case .stale = state else { return false }
        return true
    }

    public var error: AppAIError? {
        switch state {
        case .stale(_, _, let error), .failed(let error): error
        case .idle, .refreshing, .current: nil
        }
    }

    public var lastUpdatedAt: Date? {
        switch state {
        case .current(_, let date), .stale(_, let date, _): date
        case .idle, .refreshing, .failed: nil
        }
    }

    public func purchaseStateDidChange() {
        refresh(syncEntitlements: true)
    }

    public func generationDidComplete() {
        refresh(syncEntitlements: false)
    }

    public func refreshIfNeeded(
        syncEntitlements: Bool,
        maxAge: TimeInterval? = nil
    ) {
        if refreshTask != nil {
            queueEntitlementSyncIfNeeded(syncEntitlements)
            return
        }
        guard !hasFreshStatus(maxAge: maxAge ?? freshnessInterval) else {
            return
        }
        _ = startRefresh(syncEntitlements: syncEntitlements)
    }

    public func refreshIfNeededAndWait(
        syncEntitlements: Bool,
        maxAge: TimeInterval? = nil
    ) async {
        if let refreshTask {
            queueEntitlementSyncIfNeeded(syncEntitlements)
            await refreshTask.value
            return
        }
        guard !hasFreshStatus(maxAge: maxAge ?? freshnessInterval) else {
            return
        }
        let task = startRefresh(syncEntitlements: syncEntitlements)
        await task.value
    }

    public func refresh(syncEntitlements: Bool) {
        if refreshTask != nil {
            queueEntitlementSyncIfNeeded(syncEntitlements)
            return
        }
        _ = startRefresh(syncEntitlements: syncEntitlements)
    }

    public func refreshAndWait(syncEntitlements: Bool) async {
        if let refreshTask {
            queueEntitlementSyncIfNeeded(syncEntitlements)
            await refreshTask.value
            return
        }
        let task = startRefresh(syncEntitlements: syncEntitlements)
        await task.value
    }

    public func cancelRefresh() {
        let previousState = stateBeforeRefresh
        activeRefreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
        activeRefreshSyncEntitlements = false
        queuedSyncEntitlements = false
        stateBeforeRefresh = nil

        if case .refreshing = state {
            state = previousState ?? .idle
        }
    }

    @discardableResult
    private func startRefresh(
        syncEntitlements: Bool
    ) -> Task<Void, Never> {
        let refreshID = UUID()
        activeRefreshID = refreshID
        activeRefreshSyncEntitlements = syncEntitlements
        stateBeforeRefresh = state

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(
                syncEntitlements: syncEntitlements,
                refreshID: refreshID
            )
            await self.finishRefreshCycle(refreshID: refreshID)
        }
        refreshTask = task
        return task
    }

    private func finishRefreshCycle(refreshID: UUID) async {
        guard activeRefreshID == refreshID else { return }

        activeRefreshID = nil
        refreshTask = nil
        activeRefreshSyncEntitlements = false
        stateBeforeRefresh = nil

        guard queuedSyncEntitlements else { return }
        queuedSyncEntitlements = false
        await refreshAndWait(syncEntitlements: true)
    }

    private func performRefresh(
        syncEntitlements: Bool,
        refreshID: UUID
    ) async {
        guard activeRefreshID == refreshID else { return }

        guard let client else {
            state = .failed(
                configurationError
                    ?? .invalidConfiguration(
                        "The managed AI client is unavailable."
                    )
            )
            return
        }

        let previous = previousStatus(from: stateBeforeRefresh)
        state = .refreshing

        do {
            let result = if syncEntitlements {
                try await client.syncCurrentEntitlements()
            } else {
                try await client.status()
            }
            try Task.checkCancellation()
            guard activeRefreshID == refreshID else { return }
            state = .current(result, updatedAt: .now)
        } catch is CancellationError {
            guard activeRefreshID == refreshID else { return }
            applyFailure(
                .transport("The managed AI status refresh was cancelled."),
                previous: previous
            )
        } catch let error as AppAIError {
            guard activeRefreshID == refreshID else { return }
            applyFailure(error, previous: previous)
        } catch {
            guard activeRefreshID == refreshID else { return }
            applyFailure(
                .transport(error.localizedDescription),
                previous: previous
            )
        }
    }

    private func queueEntitlementSyncIfNeeded(
        _ syncEntitlements: Bool
    ) {
        guard syncEntitlements, !activeRefreshSyncEntitlements else {
            return
        }
        queuedSyncEntitlements = true
    }

    private func hasFreshStatus(maxAge: TimeInterval) -> Bool {
        guard maxAge > 0,
              case .current(_, let updatedAt) = state else {
            return false
        }
        return Date.now.timeIntervalSince(updatedAt) < maxAge
    }

    private func previousStatus(
        from state: State?
    ) -> (AppAIStatus, Date)? {
        switch state {
        case .current(let status, let date),
             .stale(let status, let date, _):
            return (status, date)
        case .idle, .refreshing, .failed, nil:
            return nil
        }
    }

    private func applyFailure(
        _ error: AppAIError,
        previous: (AppAIStatus, Date)?
    ) {
        if let previous {
            state = .stale(
                previous.0,
                updatedAt: previous.1,
                error: error
            )
        } else {
            state = .failed(error)
        }
    }
}
