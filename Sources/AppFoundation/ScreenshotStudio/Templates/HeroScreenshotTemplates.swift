#if canImport(SwiftUI)
  import SwiftUI

  public struct HeroScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View,
    Footer: View
  >: View {
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual
    private let footer: Footer

    public init(
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual,
      @ViewBuilder footer: () -> Footer
    ) {
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.visual = visual()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
            .frame(maxWidth: .infinity, alignment: .leading)

          message

          visual
            .screenshotTemplateFill()
            .screenshotTemplateSurface(
              cornerRadius: metrics.cornerRadius,
              shadowRadius: metrics.visualShadowRadius
            )

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }

  public struct DeviceFocusScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View,
    Footer: View
  >: View {
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual
    private let footer: Footer

    public init(
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual,
      @ViewBuilder footer: () -> Footer
    ) {
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.visual = visual()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.minorSpacing) {
          brand
            .frame(maxWidth: .infinity, alignment: .leading)

          message
            .padding(.bottom, metrics.minorSpacing)

          visual
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .screenshotTemplateSurface(
              cornerRadius: metrics.cornerRadius,
              shadowRadius: metrics.visualShadowRadius * 1.15,
              shadowOpacity: 0.28
            )

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, metrics.minorSpacing)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }
#endif
