#if canImport(SwiftUI)
  import SwiftUI

  public struct ScreenshotTemplateBrand<Icon: View>: View {
    private let appName: String
    private let foreground: Color
    private let icon: Icon

    public init(
      appName: String,
      foreground: Color = .primary,
      @ViewBuilder icon: () -> Icon
    ) {
      self.appName = appName
      self.foreground = foreground
      self.icon = icon()
    }

    public var body: some View {
      HStack(spacing: 9) {
        icon
          .frame(width: 28, height: 28)
          .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

        Text(appName)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(foreground)
          .lineLimit(1)
      }
      .accessibilityElement(children: .combine)
    }
  }

  public struct ScreenshotTemplateMessage: View {
    private let title: String
    private let subtitle: String?
    private let foreground: Color
    private let secondaryForeground: Color
    private let alignment: TextAlignment

    public init(
      title: String,
      subtitle: String? = nil,
      foreground: Color = .primary,
      secondaryForeground: Color = .secondary,
      alignment: TextAlignment = .leading
    ) {
      self.title = title
      self.subtitle = subtitle
      self.foreground = foreground
      self.secondaryForeground = secondaryForeground
      self.alignment = alignment
    }

    public var body: some View {
      VStack(alignment: horizontalAlignment, spacing: 10) {
        Text(title)
          .font(.system(size: 46, weight: .bold, design: .rounded))
          .tracking(-1.5)
          .foregroundStyle(foreground)
          .multilineTextAlignment(alignment)
          .lineLimit(3)
          .minimumScaleFactor(0.72)
          .allowsTightening(true)

        if let subtitle {
          Text(subtitle)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(secondaryForeground)
            .multilineTextAlignment(alignment)
            .lineLimit(3)
            .minimumScaleFactor(0.78)
            .lineSpacing(3)
        }
      }
      .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var horizontalAlignment: HorizontalAlignment {
      switch alignment {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    }

    private var frameAlignment: Alignment {
      switch alignment {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    }
  }

  public struct ScreenshotTemplateFooter: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color
    private let foreground: Color

    public init(
      _ title: String,
      systemImage: String? = nil,
      tint: Color = .accentColor,
      foreground: Color = .primary
    ) {
      self.title = title
      self.systemImage = systemImage
      self.tint = tint
      self.foreground = foreground
    }

    public var body: some View {
      HStack(spacing: 7) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
        }

        Text(title)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(foreground)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(tint.opacity(0.12), in: Capsule())
      .overlay { Capsule().strokeBorder(tint.opacity(0.20)) }
    }
  }

  public enum ScreenshotTemplateSplitSide: String, CaseIterable, Identifiable, Sendable {
    case leading
    case trailing

    public var id: String { rawValue }
  }

  struct ScreenshotTemplateMetrics {
    let size: CGSize

    var horizontalMargin: CGFloat { max(26, size.width * 0.068) }
    var topMargin: CGFloat { max(30, size.height * 0.038) }
    var bottomMargin: CGFloat { max(24, size.height * 0.030) }
    var majorSpacing: CGFloat { max(18, size.height * 0.025) }
    var minorSpacing: CGFloat { max(10, size.height * 0.014) }
    var cornerRadius: CGFloat { max(20, size.width * 0.055) }
    var smallCornerRadius: CGFloat { max(14, size.width * 0.038) }
    var visualShadowRadius: CGFloat { max(14, size.width * 0.040) }
  }

  struct ScreenshotTemplateCanvas<Background: View, Content: View>: View {
    let background: Background
    let content: (ScreenshotTemplateMetrics) -> Content

    init(
      background: Background,
      @ViewBuilder content: @escaping (ScreenshotTemplateMetrics) -> Content
    ) {
      self.background = background
      self.content = content
    }

    var body: some View {
      GeometryReader { proxy in
        let metrics = ScreenshotTemplateMetrics(size: proxy.size)

        ZStack {
          background
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()

          content(metrics)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
      }
    }
  }

  extension View {
    func screenshotTemplateSurface(
      cornerRadius: CGFloat,
      shadowRadius: CGFloat,
      shadowOpacity: Double = 0.24
    ) -> some View {
      compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
          color: .black.opacity(shadowOpacity),
          radius: shadowRadius,
          y: shadowRadius * 0.45
        )
    }

    func screenshotTemplateFill() -> some View {
      frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
#endif
