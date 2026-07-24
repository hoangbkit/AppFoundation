import SwiftUI

@main
@MainActor
struct DemoMacApp: App {
  var body: some Scene {
    Window("AppFoundation for Mac", id: MacDemoWindowID.home) {
      MacHomeView()
        .frame(minWidth: 900, minHeight: 620)
    }
    .defaultSize(width: 1080, height: 720)
    .windowResizability(.contentMinSize)
    .commands {
      MacDemoCommands()
    }

    Window("Screenshot Studio", id: MacDemoWindowID.screenshotStudio) {
      MacStudioWindow {
        MacScreenshotStudioDemoView()
      }
      .frame(minWidth: 1120, minHeight: 720)
    }
    .defaultSize(width: 1320, height: 860)
    .windowResizability(.contentMinSize)

    Window("Promo Video Studio", id: MacDemoWindowID.promoVideoStudio) {
      MacStudioWindow {
        MacPromoVideoStudioDemoView()
      }
      .frame(minWidth: 1120, minHeight: 720)
    }
    .defaultSize(width: 1320, height: 860)
    .windowResizability(.contentMinSize)
  }
}
