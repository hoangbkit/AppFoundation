import AppFoundationPromoVideoStudio
import AppFoundationScreenshotStudio
import SwiftUI

@MainActor
struct MacScreenshotStudioDemoView: View {
  @State private var accent = Color.indigo
  @State private var showsDetails = true

  var body: some View {
    ScreenshotStudio(
      catalog: MacScreenshotCatalog.make(accent: accent, showsDetails: showsDetails),
      style: ScreenshotStudioStyle(accentColor: accent)
    ) { context in
      Section("Composition") {
        Toggle("Show supporting details", isOn: $showsDetails)
        LabeledContent("Selected", value: context.selectedScreenshotTitle)
      }
    } appConfigurationControls: { _ in
      Section("Campaign") {
        ColorPicker("Accent", selection: $accent, supportsOpacity: false)
      }
    }
  }
}

@MainActor
private enum MacScreenshotCatalog {
  static func make(accent: Color, showsDetails: Bool) -> ScreenshotCatalog {
    ScreenshotCatalog(
      appName: "AppFoundation Mac Demo",
      presets: [.mac16x10],
      defaultPresetID: ScreenshotDevicePreset.mac16x10.id,
      defaultScreenshotID: "overview"
    ) {
      ScreenshotDefinition(
        id: "overview",
        title: "Studio Overview",
        filename: "Native developer studios for Mac"
      ) {
        MacScreenshotCanvas(
          eyebrow: "APPFOUNDATION FOR MAC",
          title: "Build once.\nShow it beautifully.",
          subtitle:
            "Native screenshot and promo-video production, rendered from deterministic SwiftUI.",
          accent: accent,
          showsDetails: showsDetails
        )
      }

      ScreenshotDefinition(
        id: "workflow",
        title: "Export Workflow",
        filename: "Preview and export exact media"
      ) {
        MacScreenshotCanvas(
          eyebrow: "EXACT OUTPUT",
          title: "Preview. Refine.\nExport at full size.",
          subtitle: "The live canvas and final renderer share the same registered SwiftUI content.",
          accent: accent,
          showsDetails: showsDetails
        )
      }
    }
  }
}

private struct MacScreenshotCanvas: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.black, accent.opacity(0.78), Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      HStack(spacing: 72) {
        VStack(alignment: .leading, spacing: 24) {
          Label("AppFoundation", systemImage: "swift")
            .font(.title2.bold())
          Text(eyebrow)
            .font(.headline)
            .tracking(2)
            .foregroundStyle(accent)
          Text(title)
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .tracking(-2)
          Text(subtitle)
            .font(.title2)
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: 620, alignment: .leading)
          Spacer()
          if showsDetails {
            Label("2880 × 1800 opaque PNG", systemImage: "checkmark.seal.fill")
              .font(.headline)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 22) {
          MacMetricCard(title: "Screenshot Studio", value: "PNG", systemImage: "photo")
          MacMetricCard(title: "Promo Video Studio", value: "MP4", systemImage: "film")
          MacMetricCard(
            title: "Shared SwiftUI", value: "1×", systemImage: "square.stack.3d.up.fill")
        }
        .frame(width: 430)
      }
      .padding(92)
      .foregroundStyle(.white)
    }
  }
}

@MainActor
struct MacPromoVideoStudioDemoView: View {
  @State private var accent = Color.indigo
  @State private var showsDetails = true

  var body: some View {
    PromoVideoStudio(
      videos: MacPromoProjects.makeAll(accent: accent, showsDetails: showsDetails),
      style: PromoVideoStudioStyle(accentColor: accent)
    ) { context in
      Section("Scene Controls") {
        Toggle("Show supporting details", isOn: $showsDetails)
        LabeledContent("Scene", value: "\(context.selectedSceneIndex + 1) of \(context.sceneCount)")
      }
    } videoConfigurationControls: { _ in
      Section("Campaign") {
        ColorPicker("Accent", selection: $accent, supportsOpacity: false)
      }
    }
  }
}

@MainActor
private enum MacPromoProjects {
  static func makeAll(accent: Color, showsDetails: Bool) -> [PromoVideoProject] {
    [studioStory(accent: accent, showsDetails: showsDetails), exportStory(accent: accent)]
  }

  private static func studioStory(accent: Color, showsDetails: Bool) -> PromoVideoProject {
    PromoVideoProject(
      name: "Mac Studio Story",
      presets: [.verticalFullHD, .socialPortrait, .square, .landscapeFullHD],
      defaultPresetID: PromoVideoOutputPreset.landscapeFullHD.id,
      defaultMotionIntensity: .balanced
    ) {
      PromoVideoSceneDefinition(
        id: "intro",
        title: "Native Mac Intro",
        duration: 2.8,
        transition: .crossfade
      ) { context in
        HeroIntroPromoVideoScene(context: context) {
          MacPromoBackground(accent: accent)
        } brand: {
          MacPromoBrand(accent: accent)
        } message: {
          PromoVideoTemplateMessage(
            eyebrow: "MACOS PARITY",
            title: "The same Studio workflow,\nnative on Mac.",
            subtitle: "Three-column editing, exact preview, and deterministic export.",
            accent: accent
          )
        } visual: {
          MacDashboardFixture(accent: accent, showsDetails: showsDetails)
        }
      }

      PromoVideoSceneDefinition(
        id: "workflow",
        title: "Editor Workflow",
        duration: 3.0,
        transition: .slide
      ) { context in
        AppFlowPromoVideoScene(
          context: context,
          stepTitles: ["Register", "Preview", "Export"],
          accent: accent
        ) {
          MacPromoBackground(accent: accent)
        } brand: {
          MacPromoBrand(accent: accent)
        } message: {
          PromoVideoTemplateMessage(
            eyebrow: "DEVELOPER WORKFLOW",
            title: "Move from SwiftUI\nto finished media.",
            subtitle:
              "The app supplies deterministic content. AppFoundation owns timing and output.",
            accent: accent
          )
        } first: {
          MacFlowFixture(
            title: "Register scenes", systemImage: "plus.rectangle.on.rectangle", accent: accent)
        } second: {
          MacFlowFixture(
            title: "Scrub the timeline", systemImage: "slider.horizontal.3", accent: accent)
        } third: {
          MacFlowFixture(title: "Export H.264", systemImage: "square.and.arrow.up", accent: accent)
        }
      }

      PromoVideoSceneDefinition(
        id: "outro",
        title: "Call to Action",
        duration: 2.6,
        transition: .zoom
      ) { context in
        OutroCallToActionPromoVideoScene(context: context) {
          MacPromoBackground(accent: accent)
        } icon: {
          Image(systemName: "desktopcomputer")
            .resizable()
            .scaledToFit()
            .padding(28)
            .foregroundStyle(.white)
            .background(accent.gradient)
        } message: {
          PromoVideoTemplateMessage(
            eyebrow: "READY ON MAC",
            title: "Design it. Preview it. Export it.",
            subtitle: "Screenshot Studio and Promo Video Studio now share a complete Mac workflow.",
            accent: accent,
            alignment: .center
          )
        } callToAction: {
          PromoVideoTemplateCTA("Export from Mac", systemImage: "apple.logo", tint: accent)
        } footer: {
          Text("AppFoundation")
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
        }
      }
    }
  }

  private static func exportStory(accent: Color) -> PromoVideoProject {
    PromoVideoProject(
      name: "Exact Export",
      presets: [.landscapeFullHD, .square],
      defaultPresetID: PromoVideoOutputPreset.landscapeFullHD.id,
      defaultMotionIntensity: .cinematic
    ) {
      PromoVideoSceneDefinition(
        id: "export",
        title: "Exact MP4 Export",
        duration: 3.2,
        transition: .crossfade
      ) { context in
        FeatureFocusPromoVideoScene(context: context) {
          MacPromoBackground(accent: accent)
        } brand: {
          MacPromoBrand(accent: accent)
        } message: {
          PromoVideoTemplateMessage(
            eyebrow: "FRAME BY FRAME",
            title: "Live preview and final video stay aligned.",
            subtitle: "SwiftUI frames are evaluated deterministically at 30 or 60 fps.",
            accent: accent
          )
        } visual: {
          MacDashboardFixture(accent: accent, showsDetails: true)
        } callout: {
          MacMetricCard(title: "H.264 MP4", value: "1080p", systemImage: "film.fill")
            .frame(width: 220, height: 110)
        }
      }
    }
  }
}

private struct MacPromoBackground: View {
  let accent: Color

  var body: some View {
    LinearGradient(
      colors: [Color.black, accent.opacity(0.72), Color.black],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private struct MacPromoBrand: View {
  let accent: Color

  var body: some View {
    PromoVideoTemplateBrand(appName: "AppFoundation", foreground: .white) {
      Image(systemName: "desktopcomputer")
        .resizable()
        .scaledToFit()
        .padding(7)
        .foregroundStyle(.white)
        .background(accent.gradient)
    }
  }
}

private struct MacDashboardFixture: View {
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 14) {
        Label("Scenes", systemImage: "rectangle.stack")
          .font(.headline)
        ForEach(["Intro", "Workflow", "Export"], id: \.self) { title in
          HStack {
            RoundedRectangle(cornerRadius: 8)
              .fill(accent.opacity(0.24))
              .frame(width: 48, height: 68)
            Text(title)
              .font(.headline)
            Spacer()
          }
          .padding(10)
          .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 14) {
        Image(systemName: "play.rectangle.fill")
          .font(.system(size: 54))
          .foregroundStyle(accent)
        Text("Live Preview")
          .font(.title2.bold())
        if showsDetails {
          Text("Safe areas, scrubber, scene playback, and exact output presets.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(24)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }
    .padding(24)
    .foregroundStyle(.white)
    .background(Color.black.opacity(0.82))
  }
}

private struct MacFlowFixture: View {
  let title: String
  let systemImage: String
  let accent: Color

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: systemImage)
        .font(.system(size: 56, weight: .semibold))
        .foregroundStyle(accent)
      Text(title)
        .font(.title.bold())
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(Color.black.opacity(0.86))
  }
}

private struct MacMetricCard: View {
  let title: String
  let value: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.title)
        .frame(width: 52, height: 52)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(value)
          .font(.title.bold())
      }
      Spacer()
    }
    .padding(20)
    .foregroundStyle(.white)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(.white.opacity(0.12))
    }
  }
}
