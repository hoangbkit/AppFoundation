import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ScreenshotTemplateDemoSettings {
  var mood: ScreenshotTemplateDemoMood = .indigo
  var backgroundStyle: ScreenshotBackgroundStyle = .aurora
  var showDetails = true
  var splitSide: ScreenshotTemplateSplitSide = .trailing
  var continuousPage = 2
}

enum ScreenshotTemplateDemoMood: String, CaseIterable, Identifiable {
  case indigo
  case rose
  case ocean

  var id: String { rawValue }
  var title: String { rawValue.capitalized }

  var accent: Color {
    switch self {
    case .indigo: .indigo
    case .rose: .pink
    case .ocean: .cyan
    }
  }

  var colors: [Color] {
    switch self {
    case .indigo:
      [
        Color(red: 0.06, green: 0.05, blue: 0.16),
        Color(red: 0.19, green: 0.12, blue: 0.42),
        Color(red: 0.43, green: 0.22, blue: 0.82),
        Color(red: 0.19, green: 0.47, blue: 0.92),
      ]
    case .rose:
      [
        Color(red: 0.21, green: 0.04, blue: 0.11),
        Color(red: 0.55, green: 0.11, blue: 0.29),
        Color(red: 0.95, green: 0.31, blue: 0.58),
        Color(red: 0.96, green: 0.57, blue: 0.34),
      ]
    case .ocean:
      [
        Color(red: 0.02, green: 0.07, blue: 0.12),
        Color(red: 0.03, green: 0.24, blue: 0.30),
        Color(red: 0.06, green: 0.57, blue: 0.64),
        Color(red: 0.19, green: 0.34, blue: 0.76),
      ]
    }
  }
}

@MainActor
struct ScreenshotTemplateGalleryView: View {
  @State private var settings = ScreenshotTemplateDemoSettings()

  var body: some View {
    ScreenshotStudio(
      catalog: ScreenshotTemplateDemoCatalog.make(settings: settings)
    ) { context in
      ScreenshotTemplateSelectedControls(settings: settings, context: context)
    } appConfigurationControls: { _ in
      ScreenshotTemplateAppControls(settings: settings)
    }
  }
}

@MainActor
enum ScreenshotTemplateDemoCatalog {
  static let templateIDs = [
    "hero",
    "layered-cards",
    "split-feature",
    "floating-cards",
    "widget-gallery",
    "before-after",
    "feature-steps",
    "device-focus",
    "comparison-grid",
    "continuous-campaign",
  ]

  static func make(settings: ScreenshotTemplateDemoSettings) -> ScreenshotCatalog {
    ScreenshotCatalog(
      appName: "Template Gallery",
      presets: [
        .iPhone69Portrait,
        .iPhone65Portrait,
      ],
      locales: [.english],
      defaultPresetID: ScreenshotDevicePreset.iPhone69Portrait.id,
      defaultLocaleID: ScreenshotStudioLocale.english.id,
      defaultScreenshotID: templateIDs.first
    ) {
      ScreenshotDefinition(id: "hero", title: "Hero", filename: "Hero template") {
        HeroTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "layered-cards",
        title: "Layered Cards",
        filename: "Layered cards template"
      ) {
        LayeredCardsTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "split-feature",
        title: "Split Feature",
        filename: "Split feature template"
      ) {
        SplitFeatureTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "floating-cards",
        title: "Floating Cards",
        filename: "Floating cards template"
      ) {
        FloatingCardsTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "widget-gallery",
        title: "Widget Gallery",
        filename: "Widget gallery template"
      ) {
        WidgetGalleryTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "before-after",
        title: "Before & After",
        filename: "Before and after template"
      ) {
        BeforeAfterTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "feature-steps",
        title: "Feature Steps",
        filename: "Feature steps template"
      ) {
        FeatureStepsTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "device-focus",
        title: "Device Focus",
        filename: "Device focus template"
      ) {
        DeviceFocusTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "comparison-grid",
        title: "Comparison Grid",
        filename: "Comparison grid template"
      ) {
        ComparisonGridTemplateDemo(settings: settings)
      }

      ScreenshotDefinition(
        id: "continuous-campaign",
        title: "Continuous Campaign",
        filename: "Continuous campaign template"
      ) {
        ContinuousCampaignTemplateDemo(settings: settings)
      }
    }
  }
}

@MainActor
private struct ScreenshotTemplateSelectedControls: View {
  @Bindable var settings: ScreenshotTemplateDemoSettings
  let context: ScreenshotStudioControlContext

  var body: some View {
    Section("Selected Template") {
      LabeledContent("View type", value: context.selectedScreenshotTitle)

      switch context.selectedScreenshotID {
      case "split-feature":
        Picker("Visual side", selection: $settings.splitSide) {
          ForEach(ScreenshotTemplateSplitSide.allCases) { side in
            Text(side.rawValue.capitalized).tag(side)
          }
        }
      case "continuous-campaign":
        Stepper(
          "Campaign page \(settings.continuousPage + 1) of 5",
          value: $settings.continuousPage,
          in: 0...4
        )
      default:
        Toggle("Show fixture details", isOn: $settings.showDetails)
      }
    }
  }
}

@MainActor
private struct ScreenshotTemplateAppControls: View {
  @Bindable var settings: ScreenshotTemplateDemoSettings

  var body: some View {
    Section("Gallery Style") {
      Picker("Mood", selection: $settings.mood) {
        ForEach(ScreenshotTemplateDemoMood.allCases) { mood in
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
@ViewBuilder
func screenshotTemplateDemoBackground(_ settings: ScreenshotTemplateDemoSettings) -> some View {
  ScreenshotBackground(
    style: settings.backgroundStyle,
    colors: settings.mood.colors
  )
}

@MainActor
func screenshotTemplateDemoBrand(_ settings: ScreenshotTemplateDemoSettings) -> some View {
  ScreenshotTemplateBrand(
    appName: "Template Gallery",
    foreground: .white
  ) {
    Image(systemName: "rectangle.3.group.fill")
      .resizable()
      .scaledToFit()
      .padding(5)
      .foregroundStyle(.white)
      .background(settings.mood.accent.gradient)
  }
}

@MainActor
func screenshotTemplateDemoMessage(
  _ title: String,
  subtitle: String
) -> some View {
  ScreenshotTemplateMessage(
    title: title,
    subtitle: subtitle,
    foreground: .white,
    secondaryForeground: .white.opacity(0.72)
  )
}

@MainActor
func screenshotTemplateDemoFooter(
  _ title: String,
  systemImage: String,
  settings: ScreenshotTemplateDemoSettings
) -> some View {
  ScreenshotTemplateFooter(
    title,
    systemImage: systemImage,
    tint: settings.mood.accent,
    foreground: .white
  )
}
