import AppFoundation
import Observation
import SwiftUI

@MainActor
@Observable
private final class DemoScreenshotSettings {
  var mood: DemoScreenshotMood = .indigo
  var backgroundStyle: ScreenshotBackgroundStyle = .aurora
  var frameStyle: ScreenshotDeviceFrameStyle = .clay
  var showDeviceFrame = true
  var showSystemChrome = true
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

  var clayFrame: Color {
    switch self {
    case .indigo: Color(red: 0.76, green: 0.73, blue: 0.96)
    case .rose: Color(red: 0.98, green: 0.72, blue: 0.80)
    case .midnight: Color(red: 0.44, green: 0.78, blue: 0.82)
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

      ScreenshotDefinition(
        id: "component-kit",
        title: "Reusable Components",
        filename: "Reusable screenshot components"
      ) {
        DemoComponentsScreenshot(settings: settings)
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

    Picker("Background", selection: $settings.backgroundStyle) {
      ForEach(ScreenshotBackgroundStyle.allCases) { style in
        Text(style.title).tag(style)
      }
    }

    Picker("Device frame", selection: $settings.frameStyle) {
      ForEach(ScreenshotDeviceFrameStyle.allCases) { style in
        Text(style.title).tag(style)
      }
    }

    Toggle("Show device frame", isOn: $settings.showDeviceFrame)
    Toggle("Show mock system chrome", isOn: $settings.showSystemChrome)
  }
}

@MainActor
private struct DemoHeroScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    GeometryReader { proxy in
      ScreenshotBackground(
        style: settings.backgroundStyle,
        colors: settings.mood.background
      ) {
        VStack(alignment: .leading, spacing: 28) {
          ScreenshotFeatureBadge(
            "APPFOUNDATION",
            systemImage: "swift",
            tint: settings.mood.accent,
            foreground: .white
          )

          ScreenshotHeadline(
            title: isVietnamese ? "Xây app.\nBỏ qua boilerplate." : "Build the app.\nSkip the boilerplate.",
            subtitle: isVietnamese
              ? "Hạ tầng SwiftUI dùng chung cho mọi ứng dụng của bạn."
              : "Shared SwiftUI infrastructure for every app you ship.",
            foreground: .white,
            secondaryForeground: .white.opacity(0.72),
            accent: settings.mood.accent,
            titleSize: 47
          )

          Spacer(minLength: 6)

          DemoPhonePreview(settings: settings)
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
    ScreenshotBackground(
      style: settings.backgroundStyle,
      colors: settings.mood.background
    ) {
      VStack(alignment: .leading, spacing: 26) {
        ScreenshotFeatureBadge(
          "APPFOUNDATION",
          systemImage: "swift",
          tint: settings.mood.accent,
          foreground: .white
        )

        ScreenshotHeadline(
          title: isVietnamese ? "Xây một lần.\nDùng ở mọi nơi." : "Build once.\nReuse everywhere.",
          subtitle: isVietnamese
            ? "Engine dùng chung, trải nghiệm vẫn thuộc về từng app."
            : "Share the engine while every app keeps its own experience.",
          foreground: .white,
          secondaryForeground: .white.opacity(0.70),
          accent: settings.mood.accent,
          titleSize: 45
        )

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
          ScreenshotMetric(
            value: "Swift 6.2",
            label: "Strict",
            tint: settings.mood.accent,
            foreground: .white,
            secondaryForeground: .white.opacity(0.58)
          )
          ScreenshotMetric(
            value: "iOS 26",
            label: "Native",
            tint: settings.mood.accent,
            foreground: .white,
            secondaryForeground: .white.opacity(0.58)
          )
          ScreenshotMetric(
            value: "1 package",
            label: "Shared",
            tint: settings.mood.accent,
            foreground: .white,
            secondaryForeground: .white.opacity(0.58)
          )
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
      ScreenshotBackground(
        style: settings.backgroundStyle,
        colors: settings.mood.background
      ) {
        VStack(alignment: .leading, spacing: 24) {
          ScreenshotFeatureBadge(
            "APPFOUNDATION",
            systemImage: "swift",
            tint: settings.mood.accent,
            foreground: .white
          )

          ScreenshotHeadline(
            title: isVietnamese
              ? "Thiết kế screenshot\nbằng SwiftUI."
              : "Design screenshots\nin SwiftUI.",
            subtitle: isVietnamese
              ? "App đăng ký view. Engine preview và export."
              : "The app registers views. The engine previews and exports.",
            foreground: .white,
            secondaryForeground: .white.opacity(0.72),
            accent: settings.mood.accent,
            titleSize: 43
          )

          ZStack {
            DemoScreenshotSheet(
              title: "03 — Widgets",
              symbol: "square.grid.2x2.fill",
              accent: settings.mood.accent
            )
            .screenshotTilt(.degrees(6))
            .offset(x: 42, y: 12)

            DemoScreenshotSheet(
              title: "02 — Themes",
              symbol: "paintpalette.fill",
              accent: settings.mood.accent
            )
            .screenshotTilt(.degrees(-4))
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

          ScreenshotFeatureBadge(
            "1320 × 2868 • Opaque PNG • Batch export",
            systemImage: "checkmark.seal.fill",
            tint: settings.mood.accent,
            foreground: .white.opacity(0.86)
          )
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
private struct DemoComponentsScreenshot: View {
  @Environment(\.locale) private var locale
  let settings: DemoScreenshotSettings

  var body: some View {
    GeometryReader { proxy in
      ScreenshotBackground(
        style: settings.backgroundStyle,
        colors: settings.mood.background
      ) {
        VStack(alignment: .leading, spacing: 22) {
          ScreenshotFeatureBadge(
            "SCREENSHOT COMPONENTS",
            systemImage: "square.3.layers.3d",
            tint: settings.mood.accent,
            foreground: .white
          )

          ScreenshotHeadline(
            title: isVietnamese
              ? "Lắp ghép nhanh.\nVẫn hoàn toàn riêng biệt."
              : "Compose faster.\nStay completely custom.",
            subtitle: isVietnamese
              ? "Device frame, chrome, nền và hiệu ứng có thể tái sử dụng."
              : "Reusable device frames, chrome, backgrounds, and visual effects.",
            foreground: .white,
            secondaryForeground: .white.opacity(0.72),
            accent: settings.mood.accent,
            titleSize: 39
          )

          ZStack {
            DemoMiniDevice(settings: settings, selectedTab: "Home")
              .frame(height: proxy.size.height * 0.42)
              .screenshotTilt(.degrees(-7))
              .offset(x: -62, y: 18)

            DemoMiniDevice(settings: settings, selectedTab: "Themes")
              .frame(height: proxy.size.height * 0.47)
              .screenshotTilt(.degrees(5))
              .offset(x: 58, y: -4)
          }
          .frame(maxWidth: .infinity)
          .frame(height: proxy.size.height * 0.48)

          HStack(spacing: 8) {
            ScreenshotFeatureBadge(
              "Clay",
              systemImage: "cube.fill",
              tint: settings.mood.accent,
              foreground: .white
            )
            ScreenshotFeatureBadge(
              "Mock UI",
              systemImage: "rectangle.topthird.inset.filled",
              tint: settings.mood.accent,
              foreground: .white
            )
            ScreenshotFeatureBadge(
              "Visuals",
              systemImage: "sparkles",
              tint: settings.mood.accent,
              foreground: .white
            )
          }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
      }
    }
  }

  private var isVietnamese: Bool {
    locale.language.languageCode?.identifier == "vi"
  }
}

private struct DemoPhonePreview: View {
  let settings: DemoScreenshotSettings

  var body: some View {
    ScreenshotDeviceFrame(
      style: settings.showDeviceFrame ? settings.frameStyle : .frameless,
      device: .iPhonePortrait,
      frameColor: settings.mood.clayFrame,
      rotation: .degrees(-1.5),
      showsCameraCutout: settings.showDeviceFrame
    ) {
      DemoPhoneScreen(
        accent: settings.mood.accent,
        showsSystemChrome: settings.showSystemChrome,
        selectedTab: "Home"
      )
    }
  }
}

private struct DemoMiniDevice: View {
  let settings: DemoScreenshotSettings
  let selectedTab: String

  var body: some View {
    ScreenshotDeviceFrame(
      style: settings.showDeviceFrame ? settings.frameStyle : .floating,
      device: .iPhonePortrait,
      frameColor: settings.mood.clayFrame,
      showsCameraCutout: settings.showDeviceFrame
    ) {
      DemoPhoneScreen(
        accent: settings.mood.accent,
        showsSystemChrome: settings.showSystemChrome,
        selectedTab: selectedTab
      )
    }
  }
}

private struct DemoPhoneScreen: View {
  let accent: Color
  let showsSystemChrome: Bool
  let selectedTab: String

  private let tabs = [
    ScreenshotTabBarItem(title: "Home", systemImage: "house.fill"),
    ScreenshotTabBarItem(title: "Themes", systemImage: "paintpalette.fill"),
    ScreenshotTabBarItem(title: "Settings", systemImage: "gearshape.fill"),
  ]

  var body: some View {
    VStack(spacing: 0) {
      if showsSystemChrome {
        ScreenshotStatusBar()
        ScreenshotNavigationBar(
          title: "Good evening",
          subtitle: "Your app, accelerated",
          trailingItems: [
            ScreenshotToolbarItem(
              title: "Pro",
              systemImage: "crown.fill",
              isProminent: true
            )
          ],
          tint: accent
        )
      }

      VStack(alignment: .leading, spacing: 13) {
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
          .frame(height: 156)

        ForEach(["PurchaseManager", "ThemeManager", "ScreenshotStudio"], id: \.self) { item in
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(accent)
            Text(item)
              .font(.subheadline.weight(.semibold))
            Spacer()
          }
          .padding(12)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }

        Spacer(minLength: 4)

        if showsSystemChrome {
          ScreenshotTabBar(
            items: tabs,
            selectedID: selectedTab,
            tint: accent
          )
          ScreenshotHomeIndicator()
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    }
    .foregroundStyle(.primary)
    .background(Color(uiColor: .systemBackground))
  }
}

private struct DemoFeatureCard: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      ScreenshotIconBadge(
        systemImage: systemImage,
        tint: accent,
        foreground: .white,
        size: 48
      )

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
    .screenshotGlass(cornerRadius: 24, borderColor: .white.opacity(0.11))
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
    .screenshotShadow(.strong)
  }
}
