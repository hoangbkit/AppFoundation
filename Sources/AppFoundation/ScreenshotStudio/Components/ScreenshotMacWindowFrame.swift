#if canImport(SwiftUI)
  import SwiftUI

  public enum ScreenshotMacWindowFrameStyle: String, CaseIterable, Identifiable, Sendable {
    case standard
    case floating
    case minimal

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .standard: "Standard"
      case .floating: "Floating"
      case .minimal: "Minimal"
      }
    }
  }

  public struct ScreenshotMacWindowFrame<Content: View>: View {
    private let title: String
    private let style: ScreenshotMacWindowFrameStyle
    private let cornerRadius: CGFloat
    private let titleBarHeight: CGFloat
    private let content: Content

    public init(
      title: String = "",
      style: ScreenshotMacWindowFrameStyle = .standard,
      cornerRadius: CGFloat = 18,
      titleBarHeight: CGFloat = 44,
      @ViewBuilder content: () -> Content
    ) {
      self.title = title
      self.style = style
      self.cornerRadius = max(cornerRadius, 0)
      self.titleBarHeight = max(titleBarHeight, 24)
      self.content = content()
    }

    public var body: some View {
      VStack(spacing: 0) {
        if style != .minimal {
          titleBar
            .frame(height: titleBarHeight)
        }

        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      }
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.black.opacity(style == .minimal ? 0.08 : 0.12), lineWidth: 1)
      }
      .shadow(
        color: Color.black.opacity(style == .floating ? 0.28 : 0.16),
        radius: style == .floating ? 28 : 16,
        x: 0,
        y: style == .floating ? 18 : 10
      )
    }

    private var titleBar: some View {
      ZStack {
        Rectangle()
          .fill(Color(red: 0.95, green: 0.95, blue: 0.96))

        HStack(spacing: 8) {
          Circle().fill(Color(red: 1.00, green: 0.37, blue: 0.34))
          Circle().fill(Color(red: 1.00, green: 0.74, blue: 0.18))
          Circle().fill(Color(red: 0.17, green: 0.78, blue: 0.35))
        }
        .frame(width: 52, alignment: .leading)
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)

        if !title.isEmpty {
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.72))
            .lineLimit(1)
            .padding(.horizontal, 76)
        }
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color.black.opacity(0.08))
          .frame(height: 1)
      }
    }
  }
#endif
