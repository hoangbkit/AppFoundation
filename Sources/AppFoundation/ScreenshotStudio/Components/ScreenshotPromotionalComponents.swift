#if canImport(SwiftUI)
  import SwiftUI

  public enum ScreenshotTextAlignment: String, CaseIterable, Identifiable, Sendable {
    case leading
    case center
    case trailing

    public var id: String { rawValue }

    fileprivate var horizontalAlignment: HorizontalAlignment {
      switch self {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    }

    fileprivate var textAlignment: TextAlignment {
      switch self {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    }

    fileprivate var frameAlignment: Alignment {
      switch self {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    }
  }

  public struct ScreenshotHeadline: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let alignment: ScreenshotTextAlignment
    private let foreground: Color
    private let secondaryForeground: Color
    private let accent: Color
    private let titleSize: CGFloat

    public init(
      eyebrow: String? = nil,
      title: String,
      subtitle: String? = nil,
      alignment: ScreenshotTextAlignment = .leading,
      foreground: Color = .primary,
      secondaryForeground: Color = .secondary,
      accent: Color = .accentColor,
      titleSize: CGFloat = 46
    ) {
      self.eyebrow = eyebrow
      self.title = title
      self.subtitle = subtitle
      self.alignment = alignment
      self.foreground = foreground
      self.secondaryForeground = secondaryForeground
      self.accent = accent
      self.titleSize = titleSize
    }

    public var body: some View {
      VStack(alignment: alignment.horizontalAlignment, spacing: 12) {
        if let eyebrow {
          Text(eyebrow.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(accent)
        }

        Text(title)
          .font(.system(size: titleSize, weight: .bold, design: .rounded))
          .tracking(-titleSize * 0.035)
          .foregroundStyle(foreground)
          .multilineTextAlignment(alignment.textAlignment)

        if let subtitle {
          Text(subtitle)
            .font(.system(size: max(titleSize * 0.40, 15), weight: .medium, design: .rounded))
            .foregroundStyle(secondaryForeground)
            .lineSpacing(4)
            .multilineTextAlignment(alignment.textAlignment)
        }
      }
      .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }
  }

  public struct ScreenshotFeatureBadge: View {
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
        }
        Text(title)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(foreground)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(tint.opacity(0.12), in: Capsule())
      .overlay {
        Capsule().strokeBorder(tint.opacity(0.20))
      }
    }
  }

  public struct ScreenshotIconBadge: View {
    private let systemImage: String
    private let title: String?
    private let tint: Color
    private let foreground: Color
    private let size: CGFloat

    public init(
      systemImage: String,
      title: String? = nil,
      tint: Color = .accentColor,
      foreground: Color = .primary,
      size: CGFloat = 50
    ) {
      self.systemImage = systemImage
      self.title = title
      self.tint = tint
      self.foreground = foreground
      self.size = size
    }

    public var body: some View {
      HStack(spacing: 10) {
        Image(systemName: systemImage)
          .font(.system(size: size * 0.42, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: size, height: size)
          .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.30))

        if let title {
          Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
        }
      }
    }
  }

  public struct ScreenshotMetric: View {
    private let value: String
    private let label: String
    private let tint: Color
    private let foreground: Color
    private let secondaryForeground: Color

    public init(
      value: String,
      label: String,
      tint: Color = .accentColor,
      foreground: Color = .primary,
      secondaryForeground: Color = .secondary
    ) {
      self.value = value
      self.label = label
      self.tint = tint
      self.foreground = foreground
      self.secondaryForeground = secondaryForeground
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(value)
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(foreground)
        Text(label)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(secondaryForeground)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
          .strokeBorder(tint.opacity(0.18))
      }
    }
  }

  public struct ScreenshotCallout: View {
    private let title: String
    private let message: String?
    private let systemImage: String
    private let tint: Color
    private let foreground: Color
    private let secondaryForeground: Color

    public init(
      title: String,
      message: String? = nil,
      systemImage: String = "sparkles",
      tint: Color = .accentColor,
      foreground: Color = .primary,
      secondaryForeground: Color = .secondary
    ) {
      self.title = title
      self.message = message
      self.systemImage = systemImage
      self.tint = tint
      self.foreground = foreground
      self.secondaryForeground = secondaryForeground
    }

    public var body: some View {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 36, height: 36)
          .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
          if let message {
            Text(message)
              .font(.system(size: 12, weight: .medium, design: .rounded))
              .foregroundStyle(secondaryForeground)
              .lineSpacing(2)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(15)
      .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(tint.opacity(0.18))
      }
    }
  }

  public struct ScreenshotPageIndicator: View {
    private let count: Int
    private let selectedIndex: Int
    private let tint: Color

    public init(
      count: Int,
      selectedIndex: Int,
      tint: Color = .accentColor
    ) {
      self.count = max(count, 0)
      self.selectedIndex = min(max(selectedIndex, 0), max(count - 1, 0))
      self.tint = tint
    }

    public var body: some View {
      HStack(spacing: 6) {
        ForEach(0..<count, id: \.self) { index in
          Capsule()
            .fill(index == selectedIndex ? tint : tint.opacity(0.24))
            .frame(width: index == selectedIndex ? 20 : 6, height: 6)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: selectedIndex)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page \(selectedIndex + 1) of \(count)")
    }
  }
#endif
