import SwiftUI

enum MacDemoWindowID {
  static let home = "home"
  static let screenshotStudio = "screenshot-studio"
  static let promoVideoStudio = "promo-video-studio"
}

@MainActor
struct MacStudioWindow<Content: View>: View {
  @Environment(\.openWindow) private var openWindow

  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .toolbar {
        ToolbarItem(placement: .navigation) {
          Button {
            openWindow(id: MacDemoWindowID.home)
          } label: {
            Label("Home", systemImage: "house")
          }
          .help("Show AppFoundation Home (⌘0)")
        }
      }
  }
}

struct MacDemoCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandMenu("Studios") {
      Button("Show Home") {
        openWindow(id: MacDemoWindowID.home)
      }
      .keyboardShortcut("0", modifiers: [.command])

      Divider()

      Button("Open Screenshot Studio") {
        openWindow(id: MacDemoWindowID.screenshotStudio)
      }
      .keyboardShortcut("1", modifiers: [.command])

      Button("Open Promo Video Studio") {
        openWindow(id: MacDemoWindowID.promoVideoStudio)
      }
      .keyboardShortcut("2", modifiers: [.command])
    }
  }
}
