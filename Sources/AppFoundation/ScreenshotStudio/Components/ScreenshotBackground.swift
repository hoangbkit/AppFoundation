#if canImport(SwiftUI)
  import SwiftUI

  public enum ScreenshotBackgroundStyle: String, CaseIterable, Identifiable, Sendable {
    case solid
    case gradient
    case aurora
    case spotlight
    case paper
    case technicalGrid
    case rings
    case floatingShapes

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .solid: "Solid"
      case .gradient: "Gradient"
      case .aurora: "Aurora"
      case .spotlight: "Spotlight"
      case .paper: "Paper"
      case .technicalGrid: "Technical Grid"
      case .rings: "Rings"
      case .floatingShapes: "Floating Shapes"
      }
    }
  }

  public struct ScreenshotBackground<Content: View>: View {
    private let style: ScreenshotBackgroundStyle
    private let colors: [Color]
    private let intensity: Double
    private let content: Content

    public init(
      style: ScreenshotBackgroundStyle = .aurora,
      colors: [Color],
      intensity: Double = 1,
      @ViewBuilder content: () -> Content
    ) {
      self.style = style
      self.colors = colors.isEmpty ? [.black, .gray] : colors
      self.intensity = min(max(intensity, 0), 2)
      self.content = content()
    }

    public var body: some View {
      ZStack {
        background
        content
      }
      .clipped()
    }

    @ViewBuilder
    private var background: some View {
      switch style {
      case .solid:
        color(0)
      case .gradient:
        LinearGradient(
          colors: normalizedColors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .aurora:
        aurora
      case .spotlight:
        spotlight
      case .paper:
        paper
      case .technicalGrid:
        technicalGrid
      case .rings:
        rings
      case .floatingShapes:
        floatingShapes
      }
    }

    private var normalizedColors: [Color] {
      colors.count == 1 ? [colors[0], colors[0]] : colors
    }

    private var aurora: some View {
      GeometryReader { proxy in
        ZStack {
          LinearGradient(
            colors: [color(0), color(1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          Ellipse()
            .fill(color(2).opacity(0.56 * intensity))
            .frame(width: proxy.size.width * 0.92, height: proxy.size.height * 0.46)
            .blur(radius: proxy.size.width * 0.16)
            .rotationEffect(.degrees(-24))
            .offset(x: proxy.size.width * 0.27, y: -proxy.size.height * 0.31)

          Circle()
            .fill(color(3).opacity(0.42 * intensity))
            .frame(width: proxy.size.width * 0.78)
            .blur(radius: proxy.size.width * 0.19)
            .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.29)

          Circle()
            .fill(color(1).opacity(0.30 * intensity))
            .frame(width: proxy.size.width * 0.62)
            .blur(radius: proxy.size.width * 0.14)
            .offset(x: proxy.size.width * 0.40, y: proxy.size.height * 0.34)
        }
      }
    }

    private var spotlight: some View {
      GeometryReader { proxy in
        ZStack {
          color(0)

          RadialGradient(
            colors: [color(1).opacity(0.92 * intensity), color(0).opacity(0)],
            center: .topTrailing,
            startRadius: 0,
            endRadius: max(proxy.size.width, proxy.size.height) * 0.78
          )

          RadialGradient(
            colors: [color(2).opacity(0.48 * intensity), color(0).opacity(0)],
            center: .bottomLeading,
            startRadius: 0,
            endRadius: max(proxy.size.width, proxy.size.height) * 0.62
          )
        }
      }
    }

    private var paper: some View {
      ZStack {
        color(0)

        Canvas { context, size in
          let lineColor = color(1).opacity(0.10 * intensity)
          let dotColor = color(2).opacity(0.13 * intensity)

          var horizontalLines = Path()
          for y in stride(from: CGFloat(26), through: size.height, by: 34) {
            horizontalLines.move(to: CGPoint(x: 0, y: y))
            horizontalLines.addLine(to: CGPoint(x: size.width, y: y))
          }
          context.stroke(horizontalLines, with: .color(lineColor), lineWidth: 0.65)

          for index in 0..<70 {
            let x = CGFloat((index * 47) % 101) / 101 * size.width
            let y = CGFloat((index * 73) % 103) / 103 * size.height
            let diameter = CGFloat(1 + (index % 3))
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
              with: .color(dotColor)
            )
          }
        }
      }
    }

    private var technicalGrid: some View {
      ZStack {
        LinearGradient(
          colors: [color(0), color(1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        Canvas { context, size in
          let spacing = max(min(size.width, size.height) / 18, 20)
          var minor = Path()
          var major = Path()

          var column = 0
          for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
            let target = column.isMultiple(of: 4) ? major : minor
            var path = target
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            if column.isMultiple(of: 4) {
              major = path
            } else {
              minor = path
            }
            column += 1
          }

          var row = 0
          for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
            let target = row.isMultiple(of: 4) ? major : minor
            var path = target
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            if row.isMultiple(of: 4) {
              major = path
            } else {
              minor = path
            }
            row += 1
          }

          context.stroke(minor, with: .color(color(2).opacity(0.09 * intensity)), lineWidth: 0.55)
          context.stroke(major, with: .color(color(2).opacity(0.16 * intensity)), lineWidth: 0.8)
        }
      }
    }

    private var rings: some View {
      GeometryReader { proxy in
        ZStack {
          LinearGradient(
            colors: [color(0), color(1)],
            startPoint: .top,
            endPoint: .bottom
          )

          ForEach(0..<8, id: \.self) { index in
            Circle()
              .stroke(color(2).opacity((0.18 - Double(index) * 0.014) * intensity), lineWidth: 1.2)
              .frame(width: proxy.size.width * (0.42 + CGFloat(index) * 0.18))
          }
          .offset(x: proxy.size.width * 0.28, y: -proxy.size.height * 0.23)
        }
      }
    }

    private var floatingShapes: some View {
      GeometryReader { proxy in
        ZStack {
          LinearGradient(
            colors: [color(0), color(1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )

          RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(color(2).opacity(0.20 * intensity))
            .frame(width: proxy.size.width * 0.52, height: proxy.size.width * 0.52)
            .rotationEffect(.degrees(22))
            .offset(x: proxy.size.width * 0.40, y: -proxy.size.height * 0.30)

          Circle()
            .fill(color(3).opacity(0.24 * intensity))
            .frame(width: proxy.size.width * 0.36)
            .offset(x: -proxy.size.width * 0.38, y: proxy.size.height * 0.26)

          Capsule()
            .fill(color(2).opacity(0.16 * intensity))
            .frame(width: proxy.size.width * 0.52, height: proxy.size.width * 0.14)
            .rotationEffect(.degrees(-30))
            .offset(x: proxy.size.width * 0.31, y: proxy.size.height * 0.36)
        }
      }
    }

    private func color(_ index: Int) -> Color {
      colors[index % colors.count]
    }
  }

  public extension ScreenshotBackground where Content == EmptyView {
    init(
      style: ScreenshotBackgroundStyle = .aurora,
      colors: [Color],
      intensity: Double = 1
    ) {
      self.init(style: style, colors: colors, intensity: intensity) {
        EmptyView()
      }
    }
  }
#endif
