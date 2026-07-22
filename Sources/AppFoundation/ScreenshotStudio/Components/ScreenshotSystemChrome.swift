#if canImport(SwiftUI)
  import SwiftUI

  public struct ScreenshotToolbarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var systemImage: String
    public var isProminent: Bool

    public init(
      id: String? = nil,
      title: String,
      systemImage: String,
      isProminent: Bool = false
    ) {
      self.id = id ?? title
      self.title = title
      self.systemImage = systemImage
      self.isProminent = isProminent
    }
  }

  public struct ScreenshotTabBarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var systemImage: String

    public init(
      id: String? = nil,
      title: String,
      systemImage: String
    ) {
      self.id = id ?? title
      self.title = title
      self.systemImage = systemImage
    }
  }

  public struct ScreenshotToolbarIcon: View {
    private let systemImage: String
    private let tint: Color
    private let background: Color
    private let size: CGFloat

    public init(
      systemImage: String,
      tint: Color = .primary,
      background: Color = .secondary.opacity(0.10),
      size: CGFloat = 36
    ) {
      self.systemImage = systemImage
      self.tint = tint
      self.background = background
      self.size = size
    }

    public var body: some View {
      Image(systemName: systemImage)
        .font(.system(size: size * 0.40, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background(background, in: Circle())
    }
  }

  public struct ScreenshotStatusBar: View {
    private let time: String
    private let foreground: Color
    private let showsCellular: Bool
    private let showsBatteryPercentage: Bool

    public init(
      time: String = "9:41",
      foreground: Color = .primary,
      showsCellular: Bool = true,
      showsBatteryPercentage: Bool = false
    ) {
      self.time = time
      self.foreground = foreground
      self.showsCellular = showsCellular
      self.showsBatteryPercentage = showsBatteryPercentage
    }

    public var body: some View {
      HStack(spacing: 7) {
        Text(time)
          .font(.system(size: 13, weight: .semibold, design: .rounded))

        Spacer()

        if showsCellular {
          Image(systemName: "cellularbars")
        }
        Image(systemName: "wifi")
        if showsBatteryPercentage {
          Text("100")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        Image(systemName: "battery.100percent")
      }
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(foreground)
      .padding(.horizontal, 16)
      .frame(height: 28)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Status bar, \(time)")
    }
  }

  public struct ScreenshotNavigationBar: View {
    private let title: String
    private let subtitle: String?
    private let leadingItem: ScreenshotToolbarItem?
    private let trailingItems: [ScreenshotToolbarItem]
    private let tint: Color

    public init(
      title: String,
      subtitle: String? = nil,
      leadingItem: ScreenshotToolbarItem? = nil,
      trailingItems: [ScreenshotToolbarItem] = [],
      tint: Color = .accentColor
    ) {
      self.title = title
      self.subtitle = subtitle
      self.leadingItem = leadingItem
      self.trailingItems = trailingItems
      self.tint = tint
    }

    public var body: some View {
      HStack(spacing: 12) {
        if let leadingItem {
          ScreenshotToolbarIcon(
            systemImage: leadingItem.systemImage,
            tint: leadingItem.isProminent ? .white : tint,
            background: leadingItem.isProminent ? tint : tint.opacity(0.12)
          )
          .accessibilityLabel(leadingItem.title)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 8)

        HStack(spacing: 8) {
          ForEach(trailingItems) { item in
            ScreenshotToolbarIcon(
              systemImage: item.systemImage,
              tint: item.isProminent ? .white : tint,
              background: item.isProminent ? tint : tint.opacity(0.12)
            )
            .accessibilityLabel(item.title)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 9)
    }
  }

  public struct ScreenshotToolbar: View {
    private let items: [ScreenshotToolbarItem]
    private let tint: Color
    private let background: Color

    public init(
      items: [ScreenshotToolbarItem],
      tint: Color = .accentColor,
      background: Color = .secondary.opacity(0.08)
    ) {
      self.items = items
      self.tint = tint
      self.background = background
    }

    public var body: some View {
      HStack(spacing: 10) {
        ForEach(items) { item in
          VStack(spacing: 5) {
            ScreenshotToolbarIcon(
              systemImage: item.systemImage,
              tint: item.isProminent ? .white : tint,
              background: item.isProminent ? tint : tint.opacity(0.12),
              size: 38
            )
            Text(item.title)
              .font(.system(size: 9, weight: .medium, design: .rounded))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
  }

  public struct ScreenshotTabBar: View {
    private let items: [ScreenshotTabBarItem]
    private let selectedID: String
    private let tint: Color
    private let background: Color
    private let showsLabels: Bool

    public init(
      items: [ScreenshotTabBarItem],
      selectedID: String,
      tint: Color = .accentColor,
      background: Color = .secondary.opacity(0.08),
      showsLabels: Bool = true
    ) {
      self.items = items
      self.selectedID = selectedID
      self.tint = tint
      self.background = background
      self.showsLabels = showsLabels
    }

    public var body: some View {
      HStack(spacing: 6) {
        ForEach(items) { item in
          let isSelected = item.id == selectedID

          VStack(spacing: 4) {
            Image(systemName: item.systemImage)
              .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
            if showsLabels {
              Text(item.title)
                .font(.system(size: 9, weight: isSelected ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
            }
          }
          .foregroundStyle(isSelected ? tint : Color.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 7)
          .background(
            isSelected ? tint.opacity(0.11) : Color.clear,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
          )
        }
      }
      .padding(7)
      .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
  }

  public struct ScreenshotHomeIndicator: View {
    private let color: Color

    public init(color: Color = .primary) {
      self.color = color
    }

    public var body: some View {
      Capsule()
        .fill(color.opacity(0.78))
        .frame(width: 112, height: 4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .accessibilityHidden(true)
    }
  }
#endif
