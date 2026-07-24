import SwiftUI

@main
@MainActor
struct DemoMacApp: App {
  var body: some Scene {
    WindowGroup {
      MacHomeView()
        .frame(minWidth: 980, minHeight: 680)
    }
    .defaultSize(width: 1180, height: 780)
  }
}
