#if canImport(SwiftUI)
import SwiftUI

public extension View {
    func managesAnalytics(_ analytics: AppAnalyticsClient) -> some View {
        modifier(AppAnalyticsLifecycleModifier(analytics: analytics))
    }
}

private struct AppAnalyticsLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let analytics: AppAnalyticsClient

    func body(content: Content) -> some View {
        content
            .task {
                if scenePhase == .active {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    switch newPhase {
                    case .active:
                        try? await analytics.applicationDidBecomeActive()
                    case .inactive, .background:
                        try? await analytics.applicationWillResignActive()
                    @unknown default:
                        break
                    }
                }
            }
    }
}
#endif
