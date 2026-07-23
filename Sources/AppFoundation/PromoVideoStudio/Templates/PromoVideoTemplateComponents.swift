#if os(iOS) && canImport(SwiftUI)
  import SwiftUI

  public struct PromoVideoTemplateBrand<Icon: View>: View {
    private let appName: String
    private let foreground: Color
    private let icon: Icon

    public init(
      appName: String,
      foreground: Color = .white,
      @ViewBuilder icon: () -> Icon
    ) {
      self.appName = appName
      self.foreground = foreground
      self.icon = icon()
    }

    public var body: some View {
      HStack(spacing: 10) {
        icon
          .frame(width: 34, height: 34)
          .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

        Text(appName)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(foreground)
          .lineLimit(1)
      }
      .accessibilityElement(children: .combine)
    }
  }

  public struct PromoVideoTemplateMessage: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let foreground: Color
    private let secondaryForeground: Color
    private let accent: Color
    private let alignment: TextAlignment

    public init(
      eyebrow: String? = nil,
      title: String,
      subtitle: String? = nil,
      foreground: Color = .white,
      secondaryForeground: Color = .white.opacity(0.72),
      accent: Color = .accentColor,
      alignment: TextAlignment = .leading
    ) {
      self.eyebrow = eyebrow
      self.title = title
      self.subtitle = subtitle
      self.foreground = foreground
      self.secondaryForeground = secondaryForeground
      self.accent = accent
      self.alignment = alignment
    }

    public var body: some View {
      VStack(alignment: horizontalAlignment, spacing: 10) {
        if let eyebrow {
          Text(eyebrow.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(accent)
        }

        Text(title)
          .font(.system(size: 46, weight: .bold, design: .rounded))
          .tracking(-1.4)
          .foregroundStyle(foreground)
          .multilineTextAlignment(alignment)
          .lineLimit(3)
          .minimumScaleFactor(0.66)
          .allowsTightening(true)

        if let subtitle {
          Text(subtitle)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(secondaryForeground)
            .multilineTextAlignment(alignment)
            .lineLimit(3)
            .minimumScaleFactor(0.72)
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

  public struct PromoVideoTemplateCTA: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color
    private let foreground: Color

    public init(
      _ title: String,
      systemImage: String? = nil,
      tint: Color = .accentColor,
      foreground: Color = .white
    ) {
      self.title = title
      self.systemImage = systemImage
      self.tint = tint
      self.foreground = foreground
    }

    public var body: some View {
      HStack(spacing: 9) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))
        }

        Text(title)
          .font(.system(size: 14, weight: .bold, design: .rounded))
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, 17)
      .padding(.vertical, 12)
      .background(tint, in: Capsule())
      .overlay {
        Capsule()
          .strokeBorder(Color.white.opacity(0.16))
      }
    }
  }

  struct PromoVideoTemplateMetrics {
    let size: CGSize

    var horizontalMargin: CGFloat { max(28, size.width * 0.072) }
    var topMargin: CGFloat { max(34, size.height * 0.045) }
    var bottomMargin: CGFloat { max(30, size.height * 0.038) }
    var majorSpacing: CGFloat { max(22, size.height * 0.028) }
    var minorSpacing: CGFloat { max(12, size.height * 0.016) }
    var cornerRadius: CGFloat { max(22, size.width * 0.058) }
    var smallCornerRadius: CGFloat { max(16, size.width * 0.042) }
    var shadowRadius: CGFloat { max(16, size.width * 0.042) }
  }

  struct PromoVideoTemplateCanvas<Background: View, Content: View>: View {
    let background: Background
    let content: (PromoVideoTemplateMetrics) -> Content

    init(
      background: Background,
      @ViewBuilder content: @escaping (PromoVideoTemplateMetrics) -> Content
    ) {
      self.background = background
      self.content = content
    }

    var body: some View {
      GeometryReader { proxy in
        let metrics = PromoVideoTemplateMetrics(size: proxy.size)

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
    func promoVideoTemplateSurface(
      cornerRadius: CGFloat,
      shadowRadius: CGFloat,
      shadowOpacity: Double = 0.26
    ) -> some View {
      compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
          color: .black.opacity(shadowOpacity),
          radius: shadowRadius,
          y: shadowRadius * 0.42
        )
    }
  }

  func promoVideoEntrance(
    context: PromoVideoSceneContext,
    start: Double,
    end: Double,
    distance: CGFloat = 40
  ) -> (opacity: Double, offset: CGFloat, scale: CGFloat) {
    let phase = context.phase(from: start, to: end, curve: .easeOut)
    let intensity = context.motionIntensity.scale
    return (
      opacity: phase,
      offset: distance * CGFloat((1 - phase) * intensity),
      scale: 0.94 + CGFloat(phase) * 0.06
    )
  }
#endif
