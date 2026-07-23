import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class DemoPromoVideoSettings {
  var mood: DemoPromoVideoMood = .indigo
  var backgroundStyle: ScreenshotBackgroundStyle = .aurora
  var showDetails = true
  var emphasizeExport = true
}

enum DemoPromoVideoMood: String, CaseIterable, Identifiable {
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
        Color(red: 0.05, green: 0.04, blue: 0.15),
        Color(red: 0.18, green: 0.11, blue: 0.42),
        Color(red: 0.43, green: 0.21, blue: 0.82),
        Color(red: 0.18, green: 0.46, blue: 0.92),
      ]
    case .rose:
      [
        Color(red: 0.22, green: 0.04, blue: 0.11),
        Color(red: 0.57, green: 0.10, blue: 0.28),
        Color(red: 0.96, green: 0.31, blue: 0.56),
        Color(red: 0.96, green: 0.56, blue: 0.33),
      ]
    case .ocean:
      [
        Color(red: 0.02, green: 0.07, blue: 0.12),
        Color(red: 0.03, green: 0.23, blue: 0.30),
        Color(red: 0.05, green: 0.56, blue: 0.64),
        Color(red: 0.18, green: 0.34, blue: 0.76),
      ]
    }
  }
}

@MainActor
struct PromoVideoStudioDemoView: View {
  @State private var settings = DemoPromoVideoSettings()

  var body: some View {
    PromoVideoStudio(
      project: DemoPromoVideoProject.make(settings: settings)
    ) { context in
      DemoPromoVideoSceneControls(settings: settings, context: context)
    } videoConfigurationControls: { _ in
      DemoPromoVideoConfigurationControls(settings: settings)
    }
  }
}

@MainActor
enum DemoPromoVideoProject {
  static let sceneIDs = [
    "hero-intro",
    "device-reveal",
    "feature-focus",
    "layered-screens",
    "app-flow",
    "outro",
  ]

  static func make(settings: DemoPromoVideoSettings) -> PromoVideoProject {
    PromoVideoProject(
      name: "Promo Video Studio",
      presets: [
        .verticalFullHD,
        .socialPortrait,
        .square,
      ],
      defaultPresetID: PromoVideoOutputPreset.verticalFullHD.id,
      defaultFrameRate: .fps30,
      defaultMotionIntensity: .balanced
    ) {
      PromoVideoSceneDefinition(
        id: "hero-intro",
        title: "Hero Intro",
        duration: 2.8,
        transition: .crossfade
      ) { context in
        HeroIntroPromoVideoScene(context: context) {
          demoPromoBackground(settings)
        } brand: {
          demoPromoBrand(settings)
        } message: {
          demoPromoMessage(
            eyebrow: "PROMO VIDEO STUDIO",
            title: "Turn real SwiftUI\ninto a beautiful story.",
            subtitle: "Register the scenes. AppFoundation owns the motion and export.",
            accent: settings.mood.accent
          )
        } visual: {
          TemplateDashboardFixture(
            accent: settings.mood.accent,
            showsDetails: settings.showDetails
          )
        }
      }

      PromoVideoSceneDefinition(
        id: "device-reveal",
        title: "Device Reveal",
        duration: 2.6,
        transition: .slide
      ) { context in
        DeviceRevealPromoVideoScene(context: context) {
          demoPromoBackground(settings)
        } brand: {
          demoPromoBrand(settings)
        } message: {
          demoPromoMessage(
            eyebrow: "REAL APP VIEWS",
            title: "Let the interface\ndo the selling.",
            subtitle: "The preview and final MP4 use the same deterministic scene.",
            accent: settings.mood.accent
          )
        } device: {
          TemplatePhoneScreenFixture(
            accent: settings.mood.accent,
            showsDetails: settings.showDetails
          )
        } footer: {
          Label("Exact SwiftUI rendering", systemImage: "checkmark.seal.fill")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        }
      }

      PromoVideoSceneDefinition(
        id: "feature-focus",
        title: "Feature Focus",
        duration: 2.7,
        transition: .zoom
      ) { context in
        FeatureFocusPromoVideoScene(context: context) {
          demoPromoBackground(settings)
        } brand: {
          demoPromoBrand(settings)
        } message: {
          demoPromoMessage(
            eyebrow: "EDITOR WORKFLOW",
            title: "Scene controls\nand video controls.",
            subtitle: "The AppReel editor flow, adapted for registered developer scenes.",
            accent: settings.mood.accent
          )
        } visual: {
          TemplateEditorFixture(
            accent: settings.mood.accent,
            showsDetails: settings.showDetails
          )
        } callout: {
          TemplateMetricFixture(
            value: settings.emphasizeExport ? "1080p" : "30 fps",
            label: settings.emphasizeExport ? "Exact MP4 export" : "Smooth preview",
            systemImage: settings.emphasizeExport ? "square.and.arrow.up.fill" : "play.fill",
            accent: settings.mood.accent
          )
          .frame(width: 190, height: 86)
        }
      }

      PromoVideoSceneDefinition(
        id: "layered-screens",
        title: "Layered Screens",
        duration: 2.8,
        transition: .crossfade
      ) { context in
        LayeredScreensPromoVideoScene(context: context) {
          demoPromoBackground(settings)
        } brand: {
          demoPromoBrand(settings)
        } message: {
          demoPromoMessage(
            eyebrow: "TEMPLATE MOTION",
            title: "Depth, timing,\nand hierarchy included.",
            subtitle: "Apps provide content without manually positioning every frame.",
            accent: settings.mood.accent
          )
        } primary: {
          promoFeatureCard(
            "Studio",
            value: "Scene + Video",
            systemImage: "slider.horizontal.3",
            settings: settings
          )
        } secondary: {
          promoFeatureCard(
            "Templates",
            value: "6 included",
            systemImage: "rectangle.3.group.fill",
            settings: settings
          )
        } tertiary: {
          promoFeatureCard(
            "Export",
            value: "Silent MP4",
            systemImage: "film.stack.fill",
            settings: settings
          )
        }
      }

      PromoVideoSceneDefinition(
        id: "app-flow",
        title: "App Flow",
        duration: 3.3,
        transition: .slide
      ) { context in
        AppFlowPromoVideoScene(
          context: context,
          stepTitles: ["Register", "Preview", "Export"],
          accent: settings.mood.accent
        ) {
          demoPromoBackground(settings)
        } brand: {
          demoPromoBrand(settings)
        } message: {
          demoPromoMessage(
            eyebrow: "GUIDED STORY",
            title: "Show the correct flow\nscene by scene.",
            subtitle: "A focused sequence communicates the app faster than random motion.",
            accent: settings.mood.accent
          )
        } first: {
          promoFlowCard(
            title: "Register views",
            subtitle: "Use deterministic fixtures",
            systemImage: "plus.rectangle.on.rectangle",
            settings: settings
          )
        } second: {
          promoFlowCard(
            title: "Preview motion",
            subtitle: "Scrub the exact timeline",
            systemImage: "play.rectangle.fill",
            settings: settings
          )
        } third: {
          promoFlowCard(
            title: "Export MP4",
            subtitle: "Render every frame precisely",
            systemImage: "square.and.arrow.up.fill",
            settings: settings
          )
        }
      }

      PromoVideoSceneDefinition(
        id: "outro",
        title: "Outro CTA",
        duration: 2.5,
        transition: .none
      ) { context in
        OutroCallToActionPromoVideoScene(context: context) {
          demoPromoBackground(settings)
        } icon: {
          Image(systemName: "swift")
            .resizable()
            .scaledToFit()
            .padding(32)
            .foregroundStyle(.white)
            .background(settings.mood.accent.gradient)
        } message: {
          demoPromoMessage(
            eyebrow: nil,
            title: "Build the app.\nShow it beautifully.",
            subtitle: "Promo Video Studio is now part of AppFoundation.",
            accent: settings.mood.accent,
            alignment: .center
          )
        } callToAction: {
          PromoVideoTemplateCTA(
            "Preview the full story",
            systemImage: "play.fill",
            tint: settings.mood.accent
          )
        } footer: {
          Text("AppFoundation Demo")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.58))
        }
      }
    }
  }
}

@MainActor
private struct DemoPromoVideoSceneControls: View {
  @Bindable var settings: DemoPromoVideoSettings
  let context: PromoVideoStudioControlContext

  var body: some View {
    Section("App Scene Controls") {
      switch context.selectedSceneID {
      case "feature-focus":
        Toggle("Emphasize exact export", isOn: $settings.emphasizeExport)
      default:
        Toggle("Show fixture details", isOn: $settings.showDetails)
      }

      LabeledContent(
        "Scene position",
        value: "\(context.selectedSceneIndex + 1) of \(context.sceneCount)"
      )
    }
  }
}

@MainActor
private struct DemoPromoVideoConfigurationControls: View {
  @Bindable var settings: DemoPromoVideoSettings

  var body: some View {
    Section("Campaign Style") {
      Picker("Mood", selection: $settings.mood) {
        ForEach(DemoPromoVideoMood.allCases) { mood in
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
private func demoPromoBackground(_ settings: DemoPromoVideoSettings) -> some View {
  ScreenshotBackground(
    style: settings.backgroundStyle,
    colors: settings.mood.colors
  )
}

@MainActor
private func demoPromoBrand(_ settings: DemoPromoVideoSettings) -> some View {
  PromoVideoTemplateBrand(
    appName: "AppFoundation",
    foreground: .white
  ) {
    Image(systemName: "swift")
      .resizable()
      .scaledToFit()
      .padding(6)
      .foregroundStyle(.white)
      .background(settings.mood.accent.gradient)
  }
}

@MainActor
private func demoPromoMessage(
  eyebrow: String?,
  title: String,
  subtitle: String,
  accent: Color,
  alignment: TextAlignment = .leading
) -> some View {
  PromoVideoTemplateMessage(
    eyebrow: eyebrow,
    title: title,
    subtitle: subtitle,
    foreground: .white,
    secondaryForeground: .white.opacity(0.72),
    accent: accent,
    alignment: alignment
  )
}

@MainActor
private func promoFeatureCard(
  _ title: String,
  value: String,
  systemImage: String,
  settings: DemoPromoVideoSettings
) -> some View {
  TemplateFeatureCardFixture(
    title: title,
    subtitle: settings.showDetails ? "AppFoundation-owned motion" : nil,
    value: value,
    systemImage: systemImage,
    accent: settings.mood.accent
  )
}

@MainActor
private func promoFlowCard(
  title: String,
  subtitle: String,
  systemImage: String,
  settings: DemoPromoVideoSettings
) -> some View {
  VStack(spacing: 18) {
    Spacer(minLength: 0)

    Image(systemName: systemImage)
      .font(.system(size: 54, weight: .semibold))
      .foregroundStyle(settings.mood.accent)
      .frame(width: 104, height: 104)
      .background(
        settings.mood.accent.opacity(0.15),
        in: RoundedRectangle(cornerRadius: 30, style: .continuous)
      )

    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: 24, weight: .bold, design: .rounded))
      if settings.showDetails {
        Text(subtitle)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.58))
      }
    }
    .multilineTextAlignment(.center)

    Spacer(minLength: 0)
  }
  .padding(24)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .foregroundStyle(.white)
  .background(Color(red: 0.045, green: 0.05, blue: 0.082))
}
