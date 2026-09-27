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

private struct AppAnalyticsLifecycleModifier: ViewModifier {
    let analytics: AppAnalyticsClient

    func body(content: Content) -> some View {
        content
            .environment(\.appAnalytics, analytics)
            .task {
                if UIApplication.shared.applicationState == .active {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                Task {
                    try? await analytics.applicationWillResignActive()
                }
            }
    }
}
#endif
