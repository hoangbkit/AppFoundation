import AppFoundation
import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            FoundationOnboardingView(
                pages: DemoConfiguration.onboardingPages,
                configuration: FoundationOnboardingConfiguration(
                    headerTitle: "APPFOUNDATION",
                    completionTitle: "Explore Demo",
                    buttonAppearance: .themed
                )
            ) { page, context in
                DemoOnboardingPageView(page: page, context: context)
            } onCompletion: {
                hasCompletedOnboarding = true
            }
        }
    }
}
