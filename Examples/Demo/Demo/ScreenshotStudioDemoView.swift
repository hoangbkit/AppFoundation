import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
private final class DemoScreenshotSettings {
  var mood: DemoScreenshotMood = .indigo
  var backgroundStyle: ScreenshotBackgroundStyle = .aurora
  var density: DemoScreenshotDensity = .balanced
  var showSupportingLabels = true
  var highlightExport = true
}

private enum DemoScreenshotMood: String, CaseIterable, Identifiable {
  case indigo
  case rose
  case midnight

  var id: String { rawValue }
  var title: String { rawValue.capitalized }

  var accent: Color {
    switch self {
    case .indigo: .indigo
    case .rose: .pink
    case .midnight: .cyan
    }
  }

  var background: [Color] {
    switch self {
    case .indigo:
      [
        Color(red: 0.08, green: 0.07, blue: 0.20),
        Color(red: 0.22, green: 0.16, blue: 0.48),
        Color(red: 0.45, green: 0.24, blue: 0.82),
        Color(red: 0.18, green: 0.52, blue: 0.92),
      ]
    case .rose:
      [
        Color(red: 0.23, green: 0.05, blue: 0.12),
        Color(red: 0.58, green: 0.13, blue: 0.30),
        Color(red: 0.96, green: 0.34, blue: 0.58),
        Color(red: 0.95, green: 0.55, blue: 0.34),
      ]
    case .midnight:
      [
        Color(red: 0.02, green: 0.05, blue: 0.09),
        Color(red: 0.04, green: 0.20, blue: 0.26),
        Color(red: 0.08, green: 0.52, blue: 0.62),
        Color(red: 0.20, green: 0.30, blue: 0.75),
      ]
    }
  }
}

private enum DemoScreenshotDensity: String, CaseIterable, Identifiable {
  case compact
  case balanced
  case spacious

  var id: String { rawValue }
  var title: String { rawValue.capitalized }
}

@MainActor
struct ScreenshotStudioDemoView: View {
  @State private var settings = DemoScreenshotSettings()

  var body: some View {
    ScreenshotStudio(
      catalog: DemoScreenshotCatalog.make(settings: settings)
    ) { context in
      DemoSelectedScreenshotControls(settings: settings, context: context)
    } appConfigurationControls: { _ in
      DemoAppConfigurationControls(settings: settings)
    }
  }
}

@MainActor
private enum DemoScreenshotCatalog {
  static func make(settings: DemoScreenshotSettings) -> ScreenshotCatalog {
    ScreenshotCatalog(
      appName: "AppFoundation Demo",
      presets: [
        .iPhone69Portrait,
        .iPhone65Portrait,
      ],
      locales: [
        .english,
        ScreenshotStudioLocale(
          title: "Tiếng Việt",
          localeIdentifier: "vi-VN"
        ),
      ],
      defaultPresetID: ScreenshotDevicePreset.iPhone69Portrait.id,
      defaultLocaleID: ScreenshotStudioLocale.english.id,
      defaultScreenshotID: "hero"
    ) {
      ScreenshotDefinition(
        id: "hero",
        title: "Hero",
        filename: "Build the app"
      ) {
        DemoHeroScreenshot(settings: settings)
      }

      ScreenshotDefinition(
        id: "shared-systems",
        title: "Shared Systems",
        filename: "Shared production systems"
      ) {
        DemoLayeredScreenshot(settings: settings)
      }

      ScreenshotDefinition(
        id: "native-studio",
        title: "Native Screenshot Studio",
        filename: "Design screenshots in SwiftUI"
      ) {
        DemoSplitScreenshot(settings: settings)
      }

      ScreenshotDefinition(
        id: "template-kit",
        title: "Template Kit",
        filename: "Responsive screenshot templates"
      ) {
        DemoTemplateGalleryScreenshot(settings: settings)
      }
    }
  }
}

@MainActor
private struct DemoSelectedScreenshotControls: View {
  @Bindable var settings: DemoScreenshotSettings
  let context: ScreenshotStudioControlContext

  var body: some View {
    Section("Selected Screenshot") {
      switch context.selectedScreenshotID {
      case "hero":
        Picker("Content density", selection: $settings.density) {
          ForEach(DemoScreenshotDensity.allCases) { density in
            Text(density.title).tag(density)
          }
        }
      case "shared-systems":
        Toggle("Show supporting labels", isOn: $settings.showSupportingLabels)
      case "native-studio":
        Toggle("Highlight exact export", isOn: $settings.highlightExport)
      default:
        LabeledContent("Template", value: context.selectedScreenshotTitle)
      }
    }
  }
}

@MainActor
private struct DemoAppConfigurationControls: View {
  @Bindable var settings: DemoScreenshotSettings

  var body: some View {
    Section("Campaign Style") {
      Picker("Mood", selection: $settings.mood) {
        ForEach(DemoScreenshotMood.allCases) { mood in
          Text(mood.title).tag(mood)
        }
      }

      Picker("Background", selection: $settings.backgroundStyle) {
        ForEach(ScreenshotBackgroundStyle.allCases) { style in
          Text(style.title).tag(style)
        }
      }
    }
  }
}

@MainActor
private struct DemoHeroScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    HeroScreenshotTemplate {
      demoBackground(settings)
    } brand: {
      demoBrand(settings)
    } message: {
      ScreenshotTemplateMessage(
        title: isVietnamese ? "Xây app.\nBỏ qua boilerplate." : "Build the app.\nSkip the boilerplate.",
        subtitle: isVietnamese
          ? "Hạ tầng SwiftUI dùng chung cho mọi ứng dụng của bạn."
          : "Shared SwiftUI infrastructure for every app you ship.",
        foreground: .white,
        secondaryForeground: .white.opacity(0.72)
      )
    } visual: {
      DemoDashboardVisual(
        accent: settings.mood.accent,
        density: settings.density
      )
    } footer: {
      ScreenshotTemplateFooter(
        "Showcase",
        systemImage: "square.stack.3d.up.fill",
        tint: settings.mood.accent,
        foreground: .white
      )
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoLayeredScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    LayeredCardsScreenshotTemplate {
      demoBackground(settings)
    } brand: {
      demoBrand(settings)
    } message: {
      ScreenshotTemplateMessage(
        title: isVietnamese ? "Xây một lần.\nDùng ở mọi nơi." : "Build once.\nReuse everywhere.",
        subtitle: isVietnamese
          ? "Engine dùng chung, trải nghiệm vẫn thuộc về từng app."
          : "Share the engine while every app keeps its own experience.",
        foreground: .white,
        secondaryForeground: .white.opacity(0.72)
      )
    } primary: {
      DemoSystemCard(
        title: "Commerce",
        subtitle: settings.showSupportingLabels ? "StoreKit 2" : nil,
        systemImage: "cart.fill",
        accent: settings.mood.accent
      )
    } secondary: {
      DemoSystemCard(
        title: "Themes",
        subtitle: settings.showSupportingLabels ? "App-owned" : nil,
        systemImage: "paintpalette.fill",
        accent: settings.mood.accent
      )
    } tertiary: {
      DemoSystemCard(
        title: "Backups",
        subtitle: settings.showSupportingLabels ? "Versioned" : nil,
        systemImage: "externaldrive.fill",
        accent: settings.mood.accent
      )
    } footer: {
      ScreenshotTemplateFooter(
        "Shared Systems",
        systemImage: "shippingbox.fill",
        tint: settings.mood.accent,
        foreground: .white
      )
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoSplitScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    SplitFeatureScreenshotTemplate(side: .trailing) {
      demoBackground(settings)
    } brand: {
      demoBrand(settings)
    } message: {
      ScreenshotTemplateMessage(
        title: isVietnamese
          ? "Thiết kế screenshot\nbằng SwiftUI."
          : "Design screenshots\nin SwiftUI.",
        subtitle: isVietnamese
          ? "App đăng ký view. Engine preview và export."
          : "The app registers views. The engine previews and exports.",
        foreground: .white,
        secondaryForeground: .white.opacity(0.72)
      )
    } visual: {
      DemoStudioVisual(
        accent: settings.mood.accent,
        highlightExport: settings.highlightExport
      )
    } footer: {
      ScreenshotTemplateFooter(
        settings.highlightExport
          ? "1320 × 2868 • Opaque PNG"
          : "Native Screenshot Studio",
        systemImage: "checkmark.seal.fill",
        tint: settings.mood.accent,
        foreground: .white
      )
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoTemplateGalleryScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    ComparisonGridScreenshotTemplate(
      labels: ["Hero", "Layered", "Split", "Gallery"],
      labelColor: .white
    ) {
      demoBackground(settings)
    } brand: {
      demoBrand(settings)
    } message: {
      ScreenshotTemplateMessage(
        title: isVietnamese ? "Chọn template.\nĐăng ký nội dung." : "Choose a template.\nRegister your content.",
        subtitle: isVietnamese
          ? "AppFoundation xử lý toàn bộ vị trí và kích thước."
          : "AppFoundation owns every position, scale, and safe margin.",
        foreground: .white,
        secondaryForeground: .white.opacity(0.72)
      )
    } first: {
      DemoTemplateTile(systemImage: "rectangle.portrait.fill", accent: settings.mood.accent)
    } second: {
      DemoTemplateTile(systemImage: "square.3.layers.3d", accent: settings.mood.accent)
    } third: {
      DemoTemplateTile(systemImage: "rectangle.split.2x1.fill", accent: settings.mood.accent)
    } fourth: {
      DemoTemplateTile(systemImage: "square.grid.2x2.fill", accent: settings.mood.accent)
    } footer: {
      ScreenshotTemplateFooter(
        "Template Kit",
        systemImage: "rectangle.3.group.fill",
        tint: settings.mood.accent,
        foreground: .white
      )
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
@ViewBuilder
private func demoBackground(_ settings: DemoScreenshotSettings) -> some View {
  ScreenshotBackground(
    style: settings.backgroundStyle,
    colors: settings.mood.background
  )
}

@MainActor
private func demoBrand(_ settings: DemoScreenshotSettings) -> some View {
  ScreenshotTemplateBrand(
    appName: "AppFoundation Demo",
    foreground: .white
  ) {
    Image(systemName: "swift")
      .resizable()
      .scaledToFit()
      .padding(5)
      .foregroundStyle(.white)
      .background(settings.mood.accent.gradient)
  }
}

private struct DemoDashboardVisual: View {
  let accent: Color
  let density: DemoScreenshotDensity

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Production systems")
            .font(.system(size: 20, weight: .bold, design: .rounded))
          Text("Ready for every app")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.58))
        }
        Spacer()
        Image(systemName: "checkmark.seal.fill")
          .font(.title2)
          .foregroundStyle(accent)
      }

      ForEach(Array(features.prefix(featureCount)), id: \.0) { feature in
        HStack(spacing: 12) {
          Image(systemName: feature.0)
            .foregroundStyle(accent)
            .frame(width: 34, height: 34)
            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 2) {
            Text(feature.1)
              .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(feature.2)
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.white.opacity(0.55))
          }
          Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
      }

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        demoMetric("Swift 6.2", "Strict")
        demoMetric("iOS 26", "Native")
      }
    }
    .padding(20)
    .foregroundStyle(.white)
    .background(Color(red: 0.055, green: 0.06, blue: 0.095))
  }

  private var features: [(String, String, String)] {
    [
      ("cart.fill", "Commerce", "StoreKit 2"),
      ("paintpalette.fill", "Themes", "App-owned"),
      ("square.and.arrow.up.fill", "Exports", "Exact pixels"),
      ("externaldrive.fill", "Backups", "Versioned"),
    ]
  }

  private var featureCount: Int {
    switch density {
    case .compact: 2
    case .balanced: 3
    case .spacious: 4
    }
  }

  private var spacing: CGFloat {
    switch density {
    case .compact: 9
    case .balanced: 13
    case .spacious: 16
    }
  }

  private func demoMetric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(.system(size: 13, weight: .bold, design: .rounded))
      Text(label)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(11)
    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
  }
}

private struct DemoSystemCard: View {
  let title: String
  let subtitle: String?
  let systemImage: String
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 58, height: 58)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))

      Spacer()

      Text(title)
        .font(.system(size: 25, weight: .bold, design: .rounded))
      if let subtitle {
        Text(subtitle)
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.58))
      }
    }
    .padding(24)
    .foregroundStyle(.white)
    .background(Color(red: 0.055, green: 0.06, blue: 0.095))
  }
}

private struct DemoStudioVisual: View {
  let accent: Color
  let highlightExport: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Text("Screenshot Studio")
          .font(.system(size: 17, weight: .bold, design: .rounded))
        Spacer()
        Image(systemName: "rectangle.stack.fill")
          .foregroundStyle(accent)
      }

      Picker("Mode", selection: .constant(0)) {
        Text("Screenshot").tag(0)
        Text("App Config").tag(1)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [accent.opacity(0.62), accent.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          Image(systemName: "iphone.gen3")
            .font(.system(size: 74, weight: .thin))
            .foregroundStyle(.white.opacity(0.82))
        }

      HStack(spacing: 9) {
        studioPill("6.9-inch", active: true)
        studioPill("English", active: false)
        studioPill("Light", active: false)
      }

      if highlightExport {
        Label("Exact opaque PNG export", systemImage: "checkmark.seal.fill")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(accent)
      }
    }
    .padding(19)
    .foregroundStyle(.white)
    .background(Color(red: 0.055, green: 0.06, blue: 0.095))
  }

  private func studioPill(_ title: String, active: Bool) -> some View {
    Text(title)
      .font(.system(size: 10, weight: .bold, design: .rounded))
      .foregroundStyle(active ? Color.white : Color.white.opacity(0.58))
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      .background(active ? accent.opacity(0.34) : Color.white.opacity(0.07), in: Capsule())
  }
}

private struct DemoTemplateTile: View {
  let systemImage: String
  let accent: Color

  var body: some View {
    ZStack {
      Color(red: 0.055, green: 0.06, blue: 0.095)
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(accent)
    }
  }
}
