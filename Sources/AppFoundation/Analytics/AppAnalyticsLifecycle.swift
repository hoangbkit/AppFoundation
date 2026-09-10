#if canImport(SwiftUI) && canImport(UIKit)
import Combine
import SwiftUI
import UIKit

public extension View {
    func managesAnalytics(_ analytics: AppAnalyticsClient) -> some View {
        modifier(AppAnalyticsLifecycleModifier(analytics: analytics))
    }
}

private struct AppAnalyticsLifecycleModifier: ViewModifier {
    let analytics: AppAnalyticsClient

    func body(content: Content) -> some View {
        content
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
