#if canImport(SwiftUI)
  import SwiftUI

  public enum ScreenshotDevice: String, CaseIterable, Identifiable, Sendable {
    case iPhonePortrait
    case iPhoneLandscape
    case iPadPortrait

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .iPhonePortrait: "iPhone Portrait"
      case .iPhoneLandscape: "iPhone Landscape"
      case .iPadPortrait: "iPad Portrait"
      }
    }

    public var aspectRatio: CGFloat {
      switch self {
      case .iPhonePortrait: 9 / 19.5
      case .iPhoneLandscape: 19.5 / 9
      case .iPadPortrait: 3 / 4
      }
    }

    fileprivate var cornerRatio: CGFloat {
      switch self {
      case .iPhonePortrait, .iPhoneLandscape: 0.105
      case .iPadPortrait: 0.055
      }
    }
  }

  public enum ScreenshotDeviceFrameStyle: String, CaseIterable, Identifiable, Sendable {
    case frameless
    case floating
    case minimal
    case realistic
    case clay

    public var id: String { rawValue }

    public var title: String {
      switch self {
      case .frameless: "Frameless"
      case .floating: "Floating"
      case .minimal: "Minimal"
      case .realistic: "Realistic"
      case .clay: "Clay"
      }
    }
  }

  public struct ScreenshotDeviceFrame<Content: View>: View {
    private let style: ScreenshotDeviceFrameStyle
    private let device: ScreenshotDevice
    private let frameColor: Color
    private let bezelColor: Color
    private let rotation: Angle
    private let showsCameraCutout: Bool
    private let content: Content

    public init(
      style: ScreenshotDeviceFrameStyle = .clay,
      device: ScreenshotDevice = .iPhonePortrait,
      frameColor: Color = .white,
      bezelColor: Color = .black,
      rotation: Angle = .zero,
      showsCameraCutout: Bool = true,
      @ViewBuilder content: () -> Content
    ) {
      self.style = style
      self.device = device
      self.frameColor = frameColor
      self.bezelColor = bezelColor
      self.rotation = rotation
      self.showsCameraCutout = showsCameraCutout
      self.content = content()
    }

    public var body: some View {
      GeometryReader { proxy in
        let fittedSize = fittedSize(in: proxy.size)
        let frameWidth = fittedSize.width
        let frameHeight = fittedSize.height
        let shortestSide = min(frameWidth, frameHeight)
        let outerRadius = shortestSide * device.cornerRatio
        let inset = frameInset(for: shortestSide)
        let innerRadius = max(outerRadius - inset * 0.72, 8)

        deviceBody(
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          outerRadius: outerRadius,
          innerRadius: innerRadius,
          inset: inset
        )
        .frame(width: frameWidth, height: frameHeight)
        .rotationEffect(rotation)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .aspectRatio(device.aspectRatio, contentMode: .fit)
    }

    @ViewBuilder
    private func deviceBody(
      frameWidth: CGFloat,
      frameHeight: CGFloat,
      outerRadius: CGFloat,
      innerRadius: CGFloat,
      inset: CGFloat
    ) -> some View {
      switch style {
      case .frameless:
        screen(innerRadius: outerRadius)
      case .floating:
        screen(innerRadius: outerRadius)
          .screenshotShadow(.soft)
      case .minimal:
        framedScreen(
          outerRadius: outerRadius,
          innerRadius: innerRadius,
          inset: inset,
          background: frameColor,
          border: frameColor.opacity(0.42)
        )
        .screenshotShadow(.soft)
      case .realistic:
        framedScreen(
          outerRadius: outerRadius,
          innerRadius: innerRadius,
          inset: inset,
          background: bezelColor,
          border: Color.white.opacity(0.18)
        )
        .overlay(alignment: .trailing) {
          deviceButtons(frameHeight: frameHeight)
        }
        .overlay {
          cameraCutout(frameWidth: frameWidth)
        }
        .screenshotShadow(.strong)
      case .clay:
        framedScreen(
          outerRadius: outerRadius,
          innerRadius: innerRadius,
          inset: inset,
          background: frameColor,
          border: Color.white.opacity(0.55)
        )
        .overlay {
          RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
            .strokeBorder(frameColor.opacity(0.36), lineWidth: max(inset * 0.25, 1))
            .blur(radius: max(inset * 0.12, 0.5))
        }
        .overlay(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.55), lineWidth: max(inset * 0.17, 1))
            .padding(max(inset * 0.22, 1))
        }
        .screenshotShadow(.clay, color: frameColor)
      }
    }

    private func framedScreen(
      outerRadius: CGFloat,
      innerRadius: CGFloat,
      inset: CGFloat,
      background: Color,
      border: Color
    ) -> some View {
      ZStack {
        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
          .fill(background)
          .overlay {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
              .strokeBorder(border, lineWidth: max(inset * 0.14, 0.8))
          }

        screen(innerRadius: innerRadius)
          .padding(inset)
      }
    }

    private func screen(innerRadius: CGFloat) -> some View {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
    }

    @ViewBuilder
    private func cameraCutout(frameWidth: CGFloat) -> some View {
      if showsCameraCutout {
        switch device {
        case .iPhonePortrait:
          Capsule()
            .fill(bezelColor)
            .frame(width: frameWidth * 0.28, height: frameWidth * 0.076)
            .padding(.top, frameWidth * 0.035)
            .frame(maxHeight: .infinity, alignment: .top)
        case .iPhoneLandscape:
          Capsule()
            .fill(bezelColor)
            .frame(width: frameWidth * 0.075, height: frameWidth * 0.025)
            .padding(.leading, frameWidth * 0.022)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .iPadPortrait:
          Circle()
            .fill(bezelColor.opacity(0.78))
            .frame(width: frameWidth * 0.018, height: frameWidth * 0.018)
            .padding(.top, frameWidth * 0.018)
            .frame(maxHeight: .infinity, alignment: .top)
        }
      }
    }

    @ViewBuilder
    private func deviceButtons(frameHeight: CGFloat) -> some View {
      if device != .iPadPortrait {
        VStack(spacing: frameHeight * 0.035) {
          Capsule()
            .fill(bezelColor.opacity(0.92))
            .frame(width: 3, height: frameHeight * 0.09)
          Capsule()
            .fill(bezelColor.opacity(0.92))
            .frame(width: 3, height: frameHeight * 0.15)
        }
        .offset(x: 2)
      }
    }

    private func frameInset(for shortestSide: CGFloat) -> CGFloat {
      switch style {
      case .frameless, .floating: 0
      case .minimal: shortestSide * 0.018
      case .realistic: shortestSide * 0.028
      case .clay: shortestSide * 0.045
      }
    }

    private func fittedSize(in available: CGSize) -> CGSize {
      guard available.width > 0, available.height > 0 else { return .zero }

      let availableRatio = available.width / available.height
      if availableRatio > device.aspectRatio {
        let height = available.height
        return CGSize(width: height * device.aspectRatio, height: height)
      }

      let width = available.width
      return CGSize(width: width, height: width / device.aspectRatio)
    }
  }
#endif
