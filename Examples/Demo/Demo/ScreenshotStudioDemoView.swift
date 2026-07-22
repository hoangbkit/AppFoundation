import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
private final class DemoScreenshotSettings {
  var mood: DemoScreenshotMood = .indigo
  var showDeviceFrame = true
  var showTechnicalGrid = false
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
      [Color(red: 0.08, green: 0.07, blue: 0.20), Color(red: 0.22, green: 0.16, blue: 0.48)]
    case .rose:
      [Color(red: 0.23, green: 0.05, blue: 0.12), Color(red: 0.58, green: 0.13, blue: 0.30)]
    case .midnight:
      [Color(red: 0.02, green: 0.05, blue: 0.09), Color(red: 0.04, green: 0.20, blue: 0.26)]
    }
  }
}

@MainActor
struct ScreenshotStudioDemoView: View {
  @State private var settings = DemoScreenshotSettings()

  var body: some View {
    ScreenshotStudio(
      catalog: DemoScreenshotCatalog.make(settings: settings)
    ) {
      DemoScreenshotControls(settings: settings)
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
        DemoSystemsScreenshot(settings: settings)
      }

      ScreenshotDefinition(
        id: "native-studio",
        title: "Native Screenshot Studio",
        filename: "Design screenshots in SwiftUI"
      ) {
        DemoNativeStudioScreenshot(settings: settings)
      }
    }
  }
}

@MainActor
private struct DemoScreenshotControls: View {
  @Bindable var settings: DemoScreenshotSettings

  var body: some View {
    Picker("Demo mood", selection: $settings.mood) {
      ForEach(DemoScreenshotMood.allCases) { mood in
        Text(mood.title).tag(mood)
      }
    }

    Toggle("Show device frame", isOn: $settings.showDeviceFrame)
    Toggle("Show technical grid", isOn: $settings.showTechnicalGrid)
  }
}

@MainActor
private struct DemoHeroScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        DemoScreenshotBackground(settings: settings)

        VStack(alignment: .leading, spacing: 28) {
          DemoBrandBadge(accent: settings.mood.accent)

          VStack(alignment: .leading, spacing: 14) {
            Text(
              isVietnamese
                ? "Xây app.\nBỏ qua boilerplate." : "Build the app.\nSkip the boilerplate."
            )
            .font(.system(size: 47, weight: .bold, design: .rounded))
            .tracking(-1.8)
            .foregroundStyle(.white)

            Text(
              isVietnamese
                ? "Hạ tầng SwiftUI dùng chung cho mọi ứng dụng của bạn."
                : "Shared SwiftUI infrastructure for every app you ship."
            )
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
            .lineSpacing(4)
          }

          Spacer(minLength: 6)

          DemoPhonePreview(
            accent: settings.mood.accent,
            framed: settings.showDeviceFrame
          )
          .frame(height: proxy.size.height * 0.51)
          .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .padding(.top, 38)
        .padding(.bottom, 28)
      }
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoSystemsScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  private let features: [(String, String, String)] = [
    ("cart.fill", "Commerce", "StoreKit 2"),
    ("paintpalette.fill", "Themes", "App-owned"),
    ("square.and.arrow.up.fill", "Exports", "Exact pixels"),
    ("externaldrive.fill", "Backups", "Versioned"),
  ]

  var body: some View {
    ZStack {
      DemoScreenshotBackground(settings: settings)

      VStack(alignment: .leading, spacing: 26) {
        DemoBrandBadge(accent: settings.mood.accent)

        VStack(alignment: .leading, spacing: 12) {
          Text(isVietnamese ? "Xây một lần.\nDùng ở mọi nơi." : "Build once.\nReuse everywhere.")
            .font(.system(size: 45, weight: .bold, design: .rounded))
            .tracking(-1.6)
            .foregroundStyle(.white)

          Text(
            isVietnamese
              ? "Engine dùng chung, trải nghiệm vẫn thuộc về từng app."
              : "Share the engine while every app keeps its own experience."
          )
          .font(.system(size: 18, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.7))
        }

        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: 14
        ) {
          ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
            DemoFeatureCard(
              systemImage: feature.0,
              title: feature.1,
              subtitle: feature.2,
              accent: settings.mood.accent
            )
          }
        }

        Spacer()

        HStack(spacing: 10) {
          DemoMetric(value: "Swift 6.2", label: "Strict")
          DemoMetric(value: "iOS 26", label: "Native")
          DemoMetric(value: "1 package", label: "Shared")
        }
      }
      .padding(.horizontal, 30)
      .padding(.vertical, 38)
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoNativeStudioScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        DemoScreenshotBackground(settings: settings)

        VStack(alignment: .leading, spacing: 24) {
          DemoBrandBadge(accent: settings.mood.accent)

          VStack(alignment: .leading, spacing: 12) {
            Text(
              isVietnamese
                ? "Thiết kế screenshot\nbằng SwiftUI."
                : "Design screenshots\nin SwiftUI."
            )
            .font(.system(size: 43, weight: .bold, design: .rounded))
            .tracking(-1.5)
            .foregroundStyle(.white)

            Text(
              isVietnamese
                ? "App đăng ký view. Engine preview và export."
                : "The app registers views. The engine previews and exports."
            )
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
          }

          ZStack {
            DemoScreenshotSheet(
              title: "03 — Widgets",
              symbol: "square.grid.2x2.fill",
              accent: settings.mood.accent
            )
            .rotationEffect(.degrees(6))
            .offset(x: 42, y: 12)

            DemoScreenshotSheet(
              title: "02 — Themes",
              symbol: "paintpalette.fill",
              accent: settings.mood.accent
            )
            .rotationEffect(.degrees(-4))
            .offset(x: -34, y: 3)

            DemoScreenshotSheet(
              title: "01 — Hero",
              symbol: "sparkles.rectangle.stack.fill",
              accent: settings.mood.accent
            )
          }
          .frame(maxWidth: .infinity)
          .frame(height: proxy.size.height * 0.43)

          Spacer()

          Label("1320 × 2868 • Opaque PNG • Batch export", systemImage: "checkmark.seal.fill")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 38)
      }
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

@MainActor
private struct DemoScreenshotBackground: View {
  let settings: DemoScreenshotSettings

  var body: some View {
    ZStack {
      LinearGradient(
        colors: settings.mood.background,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(settings.mood.accent.opacity(0.34))
        .frame(width: 320, height: 320)
        .blur(radius: 70)
        .offset(x: 170, y: -330)

      if settings.showTechnicalGrid {
        Canvas { context, size in
          let spacing: CGFloat = 28
          var path = Path()
          for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
          }
          for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
          }
          context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
        }
      }
    }
    .ignoresSafeArea()
  }
}

private struct DemoBrandBadge: View {
  let accent: Color

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: "swift")
        .font(.system(size: 14, weight: .bold))
      Text("APPFOUNDATION")
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .tracking(1.5)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(accent.opacity(0.42), in: Capsule())
    .overlay {
      Capsule().strokeBorder(.white.opacity(0.16))
    }
  }
}

private struct DemoPhonePreview: View {
  let accent: Color
  let framed: Bool

  var body: some View {
    VStack(spacing: 14) {
      Capsule()
        .fill(.black.opacity(0.75))
        .frame(width: 92, height: 25)
        .padding(.top, 9)

      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Good evening")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("Your app, accelerated")
              .font(.title3.bold())
          }
          Spacer()
          Image(systemName: "crown.fill")
            .foregroundStyle(accent)
        }

        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(
            LinearGradient(
              colors: [accent, accent.opacity(0.55)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 5) {
              Text("Shared infrastructure")
                .font(.headline)
              Text("Commerce • Themes • Export")
                .font(.caption)
                .opacity(0.78)
            }
            .foregroundStyle(.white)
            .padding(18)
          }
          .frame(height: 170)

        ForEach(["PurchaseManager", "ThemeManager", "ScreenshotStudio"], id: \.self) { item in
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(accent)
            Text(item)
              .font(.subheadline.weight(.semibold))
            Spacer()
          }
          .padding(13)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
      }
      .padding(.horizontal, 18)
      .padding(.bottom, 18)
    }
    .foregroundStyle(.primary)
    .background(Color(uiColor: .systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: framed ? 46 : 28, style: .continuous))
    .overlay {
      if framed {
        RoundedRectangle(cornerRadius: 46, style: .continuous)
          .strokeBorder(.black.opacity(0.72), lineWidth: 8)
      }
    }
    .shadow(color: .black.opacity(0.28), radius: 24, y: 18)
    .padding(.horizontal, framed ? 18 : 0)
  }
}

private struct DemoFeatureCard: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Image(systemName: systemImage)
        .font(.system(size: 23, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 48, height: 48)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 19, weight: .bold, design: .rounded))
        Text(subtitle)
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.58))
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    .padding(18)
    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .strokeBorder(.white.opacity(0.11))
    }
  }
}

private struct DemoMetric: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value)
        .font(.system(size: 15, weight: .bold, design: .rounded))
      Text(label)
        .font(.caption)
        .foregroundStyle(.white.opacity(0.55))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 17))
  }
}

private struct DemoScreenshotSheet: View {
  let title: String
  let symbol: String
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(title)
          .font(.caption.bold())
          .foregroundStyle(.secondary)
        Spacer()
        Image(systemName: symbol)
          .foregroundStyle(accent)
      }

      Text("Native SwiftUI")
        .font(.system(size: 27, weight: .bold, design: .rounded))

      RoundedRectangle(cornerRadius: 20)
        .fill(
          LinearGradient(
            colors: [accent, accent.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(height: 155)
        .overlay {
          Image(systemName: symbol)
            .font(.system(size: 45, weight: .semibold))
            .foregroundStyle(.white)
        }

      Text("Deterministic fixtures and exact output dimensions.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(width: 290, height: 360)
    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 30))
    .overlay {
      RoundedRectangle(cornerRadius: 30)
        .strokeBorder(.white.opacity(0.18))
    }
    .shadow(color: .black.opacity(0.24), radius: 20, y: 14)
  }
}
