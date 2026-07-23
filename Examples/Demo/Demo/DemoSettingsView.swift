import AppFoundation
import SwiftUI

struct DemoSettingsView: View {
  @Environment(ThemeManager.self) private var themes

  private var theme: AppTheme { themes.effectiveTheme }

  var body: some View {
    NavigationStack {
      ZStack {
        AppThemeBackground(theme: theme)

        Form {
          Section("Developer Tools") {
            NavigationLink {
              ScreenshotStudioDemoView()
            } label: {
              Label("Screenshot Studio", systemImage: "photo.stack.fill")
            }
          }
          .listRowBackground(theme.surfaceColor)

          Section("About") {
            LabeledContent("Package", value: "AppFoundation")
            LabeledContent("Platform", value: "iOS 26")
          }
          .listRowBackground(theme.surfaceColor)
        }
        .scrollContentBackground(.hidden)
      }
      .foregroundStyle(theme.primaryForegroundColor)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
    }
    .tint(theme.accentColor)
  }
}
