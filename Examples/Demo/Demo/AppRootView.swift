import AppFoundation
import SwiftUI

struct AppRootView: View {
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

  var body: some View {
    if hasCompletedOnboarding {
      TabView {
        HomeView()
          .tabItem {
            Label("Showcase", systemImage: "square.stack.3d.up.fill")
          }

        ScreenshotStudioDemoView()
          .tabItem {
            Label("Screenshots", systemImage: "photo.stack.fill")
          }

        PurchaseUpsellDemoView()
          .tabItem {
            Label("Upsells", systemImage: "crown.fill")
          }
      }
    } else {
      FoundationOnboardingView(
        pages: DemoConfiguration.onboardingPages
      ) {
        hasCompletedOnboarding = true
      }
    }
  }
}
