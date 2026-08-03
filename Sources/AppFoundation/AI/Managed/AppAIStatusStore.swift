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
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var queuedSyncEntitlements = false

    public init(
        client: (any AppAIStatusServing)?,
        configurationError: AppAIError? = nil
    ) {
        self.client = client
        self.configurationError = configurationError
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

    public func refresh(syncEntitlements: Bool) {
        if refreshTask != nil {
            queuedSyncEntitlements = queuedSyncEntitlements || syncEntitlements
            return
        }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(syncEntitlements: syncEntitlements)
            await self.finishRefreshCycle()
        }
    }

    public func refreshAndWait(syncEntitlements: Bool) async {
        if let refreshTask {
            queuedSyncEntitlements = queuedSyncEntitlements || syncEntitlements
            await refreshTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(syncEntitlements: syncEntitlements)
            await self.finishRefreshCycle()
        }
        refreshTask = task
        await task.value
    }

    public func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        queuedSyncEntitlements = false
    }

    private func finishRefreshCycle() async {
        refreshTask = nil
        guard queuedSyncEntitlements else { return }
        queuedSyncEntitlements = false
        await refreshAndWait(syncEntitlements: true)
    }

    private func performRefresh(syncEntitlements: Bool) async {
        guard let client else {
            state = .failed(configurationError ?? .invalidConfiguration("The managed AI client is unavailable."))
            return
        }
        let previous = status.map { ($0, lastUpdatedAt ?? .now) }
        state = .refreshing
        do {
            let result = if syncEntitlements {
                try await client.syncCurrentEntitlements()
            } else {
                try await client.status()
            }
            try Task.checkCancellation()
            state = .current(result, updatedAt: .now)
        } catch is CancellationError {
            applyFailure(.transport("The managed AI status refresh was cancelled."), previous: previous)
        } catch let error as AppAIError {
            applyFailure(error, previous: previous)
        } catch {
            applyFailure(.transport(error.localizedDescription), previous: previous)
        }
    }

    private func applyFailure(_ error: AppAIError, previous: (AppAIStatus, Date)?) {
        if let previous {
            state = .stale(previous.0, updatedAt: previous.1, error: error)
        } else {
            state = .failed(error)
        }
    }
}
