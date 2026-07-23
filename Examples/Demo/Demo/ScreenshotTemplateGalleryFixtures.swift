import SwiftUI

struct TemplateDashboardFixture: View {
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Today")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.56))
          Text("Production overview")
            .font(.system(size: 21, weight: .bold, design: .rounded))
        }
        Spacer()
        Image(systemName: "checkmark.seal.fill")
          .font(.title2)
          .foregroundStyle(accent)
      }

      HStack(spacing: 10) {
        dashboardMetric("10", "Templates")
        dashboardMetric("2", "Presets")
        dashboardMetric("PNG", "Output")
      }

      VStack(spacing: 9) {
        dashboardRow("photo.stack.fill", "Screenshot Studio", "Ready")
        dashboardRow("paintpalette.fill", "Theme system", showsDetails ? "App-owned" : nil)
        dashboardRow("externaldrive.fill", "Backup engine", showsDetails ? "Versioned" : nil)
      }

      Spacer(minLength: 0)

      Label("All systems ready", systemImage: "bolt.fill")
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(accent)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }

  private func dashboardMetric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(.system(size: 18, weight: .bold, design: .rounded))
      Text(label)
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.52))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(11)
    .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
  }

  private func dashboardRow(_ symbol: String, _ title: String, _ detail: String?) -> some View {
    HStack(spacing: 11) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 34, height: 34)
        .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))

      Text(title)
        .font(.system(size: 12, weight: .bold, design: .rounded))

      Spacer(minLength: 8)

      if let detail {
        Text(detail)
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.54))
      }
    }
    .padding(11)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
  }
}

struct TemplateFeatureCardFixture: View {
  let title: String
  let subtitle: String?
  let value: String
  let systemImage: String
  let accent: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 26, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 54, height: 54)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17))

      Spacer(minLength: 0)

      Text(value)
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(accent)

      Text(title)
        .font(.system(size: 23, weight: .bold, design: .rounded))
        .lineLimit(2)
        .minimumScaleFactor(0.75)

      if let subtitle {
        Text(subtitle)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.55))
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }
}

struct TemplateEditorFixture: View {
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Text("Screenshot Editor")
          .font(.system(size: 17, weight: .bold, design: .rounded))
        Spacer()
        Image(systemName: "slider.horizontal.3")
          .foregroundStyle(accent)
      }

      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [accent.opacity(0.68), accent.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          VStack(spacing: 9) {
            Image(systemName: "iphone.gen3")
              .font(.system(size: 70, weight: .thin))
            if showsDetails {
              Text("Live SwiftUI preview")
                .font(.system(size: 11, weight: .bold, design: .rounded))
            }
          }
          .foregroundStyle(.white.opacity(0.86))
        }

      Picker("Editor Mode", selection: .constant(0)) {
        Text("Screenshot").tag(0)
        Text("App Config").tag(1)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      HStack(spacing: 8) {
        editorPill("6.9-inch", active: true)
        editorPill("English", active: false)
        editorPill("Light", active: false)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }

  private func editorPill(_ title: String, active: Bool) -> some View {
    Text(title)
      .font(.system(size: 9, weight: .bold, design: .rounded))
      .foregroundStyle(active ? .white : .white.opacity(0.55))
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(active ? accent.opacity(0.34) : .white.opacity(0.07), in: Capsule())
  }
}

struct TemplateMetricFixture: View {
  let value: String
  let label: String
  let systemImage: String
  let accent: Color

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: systemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 42, height: 42)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

      VStack(alignment: .leading, spacing: 3) {
        Text(value)
          .font(.system(size: 19, weight: .bold, design: .rounded))
        Text(label)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.54))
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }
}

enum TemplateWidgetFamily {
  case small
  case medium
  case large
}

struct TemplateWidgetFixture: View {
  let family: TemplateWidgetFamily
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [TemplateFixtureSurface.background, accent.opacity(0.34)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      content
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .small:
      VStack(alignment: .leading, spacing: 7) {
        Image(systemName: "sparkles")
          .foregroundStyle(accent)
        Spacer()
        Text("10")
          .font(.system(size: 28, weight: .bold, design: .rounded))
        if showsDetails {
          Text("Templates")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.56))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .medium:
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text("Screenshot Studio")
            .font(.system(size: 14, weight: .bold, design: .rounded))
          if showsDetails {
            Text("Exact output from SwiftUI")
              .font(.system(size: 9, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.56))
          }
        }
        Spacer()
        Image(systemName: "photo.stack.fill")
          .font(.system(size: 28))
          .foregroundStyle(accent)
      }

    case .large:
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Production toolkit")
            .font(.system(size: 16, weight: .bold, design: .rounded))
          Spacer()
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(accent)
        }
        widgetRow("cart.fill", "Commerce")
        widgetRow("paintpalette.fill", "Themes")
        widgetRow("square.and.arrow.up.fill", "Exports")
        Spacer(minLength: 0)
      }
    }
  }

  private func widgetRow(_ symbol: String, _ title: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(accent)
        .frame(width: 30, height: 30)
        .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
      Text(title)
        .font(.system(size: 11, weight: .bold, design: .rounded))
      Spacer()
      if showsDetails {
        Image(systemName: "checkmark")
          .font(.caption.bold())
          .foregroundStyle(.white.opacity(0.48))
      }
    }
  }
}

struct TemplateCleanupFixture: View {
  let isOrganized: Bool
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(isOrganized ? "Library" : "Camera Roll")
          .font(.system(size: 14, weight: .bold, design: .rounded))
        Spacer()
        Image(systemName: isOrganized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
          .foregroundStyle(isOrganized ? accent : .orange)
      }

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(0..<6, id: \.self) { index in
          RoundedRectangle(cornerRadius: 9)
            .fill(tileColor(index))
            .overlay {
              Image(systemName: isOrganized ? organizedSymbol(index) : "photo")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
            }
            .aspectRatio(1, contentMode: .fit)
        }
      }

      if showsDetails {
        Text(isOrganized ? "Grouped by project and feature" : "Screenshots mixed with every photo")
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.54))
          .lineLimit(2)
      }

      Spacer(minLength: 0)
    }
    .padding(15)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }

  private func tileColor(_ index: Int) -> Color {
    if isOrganized {
      return index.isMultiple(of: 2) ? accent.opacity(0.54) : accent.opacity(0.28)
    }
    return index.isMultiple(of: 3) ? .orange.opacity(0.42) : .white.opacity(0.10)
  }

  private func organizedSymbol(_ index: Int) -> String {
    ["iphone", "paintpalette.fill", "textformat", "widget.small", "photo.stack", "checkmark.seal"][index]
  }
}

struct TemplateStepFixture: View {
  let systemImage: String
  let title: String?
  let accent: Color

  var body: some View {
    VStack(spacing: 13) {
      Spacer(minLength: 0)
      Image(systemName: systemImage)
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 64, height: 64)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))

      if let title {
        Text(title)
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.64))
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }
}

struct TemplatePhoneScreenFixture: View {
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("9:41")
          .font(.system(size: 10, weight: .bold, design: .rounded))
        Spacer()
        Image(systemName: "wifi")
        Image(systemName: "battery.100percent")
      }
      .font(.system(size: 9, weight: .semibold))
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("AppFoundation")
            .font(.system(size: 20, weight: .bold, design: .rounded))
          if showsDetails {
            Text("Reusable production systems")
              .font(.system(size: 9, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.54))
          }
        }
        Spacer()
        Image(systemName: "gearshape.fill")
          .foregroundStyle(accent)
      }
      .padding(16)

      ScrollView {
        VStack(spacing: 11) {
          phoneCard("cart.fill", "Verified commerce", "StoreKit 2")
          phoneCard("paintpalette.fill", "Theme management", "App-owned")
          phoneCard("photo.stack.fill", "Screenshot Studio", "Exact output")
          phoneCard("externaldrive.fill", "Backup packages", "Versioned")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
      }

      HStack {
        phoneTab("square.stack.3d.up.fill", active: true)
        phoneTab("crown.fill", active: false)
        phoneTab("gearshape.fill", active: false)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
      .background(.white.opacity(0.05))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }

  private func phoneCard(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
    HStack(spacing: 11) {
      Image(systemName: symbol)
        .foregroundStyle(accent)
        .frame(width: 38, height: 38)
        .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 11, weight: .bold, design: .rounded))
        Text(subtitle)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.52))
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption2.bold())
        .foregroundStyle(.white.opacity(0.38))
    }
    .padding(12)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
  }

  private func phoneTab(_ symbol: String, active: Bool) -> some View {
    Image(systemName: symbol)
      .foregroundStyle(active ? accent : .white.opacity(0.38))
      .frame(maxWidth: .infinity)
  }
}

enum TemplateThemeStyle {
  case paper
  case midnight
  case aurora
  case minimal
}

struct TemplateThemeFixture: View {
  let style: TemplateThemeStyle
  let accent: Color

  var body: some View {
    ZStack {
      background
      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
          .fill(foreground.opacity(0.16))
          .frame(height: 12)
        RoundedRectangle(cornerRadius: 8)
          .fill(accent.opacity(0.68))
          .frame(width: 54, height: 54)
        Spacer(minLength: 0)
        RoundedRectangle(cornerRadius: 6)
          .fill(foreground.opacity(0.72))
          .frame(height: 8)
        RoundedRectangle(cornerRadius: 6)
          .fill(foreground.opacity(0.28))
          .frame(width: 74, height: 7)
      }
      .padding(13)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var background: some View {
    switch style {
    case .paper:
      Color(red: 0.96, green: 0.93, blue: 0.86)
    case .midnight:
      Color(red: 0.03, green: 0.04, blue: 0.08)
    case .aurora:
      LinearGradient(
        colors: [accent.opacity(0.92), Color.purple.opacity(0.68)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .minimal:
      Color.white
    }
  }

  private var foreground: Color {
    switch style {
    case .paper, .minimal: .black
    case .midnight, .aurora: .white
    }
  }
}

struct TemplateCampaignFixture: View {
  let pageIndex: Int
  let accent: Color
  let showsDetails: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Campaign page \(pageIndex + 1)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accent)
          Text(pageTitle)
            .font(.system(size: 22, weight: .bold, design: .rounded))
        }
        Spacer()
        Image(systemName: pageSymbol)
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(accent)
      }

      RoundedRectangle(cornerRadius: 20)
        .fill(
          LinearGradient(
            colors: [accent.opacity(0.56), accent.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          Image(systemName: pageSymbol)
            .font(.system(size: 72, weight: .thin))
            .foregroundStyle(.white.opacity(0.78))
        }

      if showsDetails {
        HStack(spacing: 8) {
          ForEach(0..<5, id: \.self) { index in
            Capsule()
              .fill(index == pageIndex ? accent : .white.opacity(0.12))
              .frame(height: 7)
          }
        }
      }
    }
    .padding(19)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.white)
    .background(TemplateFixtureSurface.background)
  }

  private var pageTitle: String {
    ["Discover", "Customize", "Preview", "Export", "Ship"][pageIndex]
  }

  private var pageSymbol: String {
    ["sparkles", "slider.horizontal.3", "eye.fill", "square.and.arrow.up.fill", "paperplane.fill"][pageIndex]
  }
}

private enum TemplateFixtureSurface {
  static let background = Color(red: 0.045, green: 0.050, blue: 0.082)
}
