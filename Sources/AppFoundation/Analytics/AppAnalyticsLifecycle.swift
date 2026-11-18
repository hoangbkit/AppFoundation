#if canImport(SwiftUI) && canImport(UIKit)
import Combine
import SwiftUI
import UIKit

private struct AppAnalyticsEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppAnalyticsClient? = nil
}

extension EnvironmentValues {
    var appAnalytics: AppAnalyticsClient? {
        get { self[AppAnalyticsEnvironmentKey.self] }
        set { self[AppAnalyticsEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Manages application analytics lifecycle and exposes the same optional client
    /// to AppFoundation-owned descendant views.
    func managesAnalytics(_ analytics: AppAnalyticsClient) -> some View {
        modifier(AppAnalyticsLifecycleModifier(analytics: analytics))
    }
}

/// Holds a short background execution assertion so the background flush can finish
/// before iOS suspends the app. The assertion is acquired on `willResignActive` (as
/// early as possible) and released once the flush completes or the app becomes active.
private final class AppAnalyticsBackgroundTaskCoordinator: ObservableObject, @unchecked Sendable {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    @MainActor
    func beginIfNeeded() {
        guard identifier == .invalid else { return }
        identifier = UIApplication.shared.beginBackgroundTask(
            withName: "AppFoundation.analytics.backgroundFlush"
        ) { [weak self] in
            Task { @MainActor in
                self?.endIfNeeded()
            }
        }
    }

    @MainActor
    func endIfNeeded() {
        guard identifier != .invalid else { return }
        let current = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(current)
    }
}

private struct AppAnalyticsLifecycleModifier: ViewModifier {
    let analytics: AppAnalyticsClient
    @StateObject private var backgroundTask = AppAnalyticsBackgroundTaskCoordinator()

    func body(content: Content) -> some View {
        content
            .environment(\.appAnalytics, analytics)
            .task {
                if UIApplication.shared.applicationState == .active {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                backgroundTask.endIfNeeded()
                Task {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                backgroundTask.beginIfNeeded()
                Task {
                    try? await analytics.applicationWillResignActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                backgroundTask.beginIfNeeded()
                Task {
                    try? await analytics.applicationDidEnterBackground()
                    backgroundTask.endIfNeeded()
                }
            }
    }
}
#endif
