#if canImport(SwiftUI)
  import SwiftUI

  public enum ScreenshotShadowStyle: String, CaseIterable, Identifiable, Sendable {
    case none
    case soft
    case strong
    case clay

    public var id: String { rawValue }
  }

  public extension View {
    @ViewBuilder
    func screenshotShadow(
      _ style: ScreenshotShadowStyle,
      color: Color = .black
    ) -> some View {
      switch style {
      case .none:
        self
      case .soft:
        shadow(color: color.opacity(0.20), radius: 22, x: 0, y: 14)
      case .strong:
        shadow(color: color.opacity(0.34), radius: 30, x: 0, y: 22)
      case .clay:
        shadow(color: Color.white.opacity(0.28), radius: 10, x: -7, y: -7)
          .shadow(color: color.opacity(0.30), radius: 22, x: 10, y: 16)
      }
    }

    func screenshotTilt(_ angle: Angle) -> some View {
      rotationEffect(angle)
    }

    func screenshotPerspective(
      x: Double = 0,
      y: Double = 0,
      perspective: CGFloat = 0.72
    ) -> some View {
      rotation3DEffect(
        .degrees(x),
        axis: (x: 1, y: 0, z: 0),
        perspective: perspective
      )
      .rotation3DEffect(
        .degrees(y),
        axis: (x: 0, y: 1, z: 0),
        perspective: perspective
      )
    }

    func screenshotGlow(
      color: Color,
      radius: CGFloat = 30,
      intensity: Double = 0.42
    ) -> some View {
      shadow(color: color.opacity(intensity), radius: radius)
    }

    func screenshotGlass(
      cornerRadius: CGFloat = 24,
      borderColor: Color = .white.opacity(0.20)
    ) -> some View {
      background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor)
        }
    }

    func screenshotClay(
      color: Color,
      cornerRadius: CGFloat = 24
    ) -> some View {
      background(color, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
        }
        .screenshotShadow(.clay, color: color)
    }
  }
#endif
