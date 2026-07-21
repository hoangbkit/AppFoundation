import AppFoundation
import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            FoundationOnboardingView(
                pages: DemoConfiguration.onboardingPages
            ) {
                hasCompletedOnboarding = true
            }
        }
    }
}