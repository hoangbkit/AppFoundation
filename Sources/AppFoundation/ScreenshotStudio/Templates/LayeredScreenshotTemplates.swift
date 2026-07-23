#if canImport(SwiftUI)
  import SwiftUI

  public struct LayeredCardsScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Primary: View,
    Secondary: View,
    Tertiary: View,
    Footer: View
  >: View {
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let primary: Primary
    private let secondary: Secondary
    private let tertiary: Tertiary
    private let footer: Footer

    public init(
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder primary: () -> Primary,
      @ViewBuilder secondary: () -> Secondary,
      @ViewBuilder tertiary: () -> Tertiary,
      @ViewBuilder footer: () -> Footer
    ) {
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.primary = primary()
      self.secondary = secondary()
      self.tertiary = tertiary()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          GeometryReader { proxy in
            ZStack {
              tertiary
                .frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.82)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.72,
                  shadowOpacity: 0.18
                )
                .rotationEffect(.degrees(7))
                .offset(x: proxy.size.width * 0.13, y: proxy.size.height * 0.035)

              secondary
                .frame(width: proxy.size.width * 0.76, height: proxy.size.height * 0.86)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.88,
                  shadowOpacity: 0.21
                )
                .rotationEffect(.degrees(-5))
                .offset(x: -proxy.size.width * 0.105, y: proxy.size.height * 0.025)

              primary
                .frame(width: proxy.size.width * 0.78, height: proxy.size.height * 0.90)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 1.1,
                  shadowOpacity: 0.28
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }

  public struct FloatingCardsScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Primary: View,
    LeadingSupporting: View,
    TrailingSupporting: View,
    Footer: View
  >: View {
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let primary: Primary
    private let leadingSupporting: LeadingSupporting
    private let trailingSupporting: TrailingSupporting
    private let footer: Footer

    public init(
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder primary: () -> Primary,
      @ViewBuilder leadingSupporting: () -> LeadingSupporting,
      @ViewBuilder trailingSupporting: () -> TrailingSupporting,
      @ViewBuilder footer: () -> Footer
    ) {
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.primary = primary()
      self.leadingSupporting = leadingSupporting()
      self.trailingSupporting = trailingSupporting()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          GeometryReader { proxy in
            ZStack {
              primary
                .frame(width: proxy.size.width * 0.78, height: proxy.size.height * 0.78)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.visualShadowRadius,
                  shadowOpacity: 0.27
                )

              leadingSupporting
                .frame(width: proxy.size.width * 0.40, height: proxy.size.height * 0.30)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.smallCornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.65,
                  shadowOpacity: 0.22
                )
                .rotationEffect(.degrees(-5))
                .offset(x: -proxy.size.width * 0.28, y: -proxy.size.height * 0.26)

              trailingSupporting
                .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.31)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.smallCornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.65,
                  shadowOpacity: 0.22
                )
                .rotationEffect(.degrees(5))
                .offset(x: proxy.size.width * 0.27, y: proxy.size.height * 0.27)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }
#endif
