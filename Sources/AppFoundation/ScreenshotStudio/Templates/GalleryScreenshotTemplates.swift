#if canImport(SwiftUI)
  import SwiftUI

  public struct WidgetGalleryScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Small: View,
    Medium: View,
    Large: View,
    Footer: View
  >: View {
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let small: Small
    private let medium: Medium
    private let large: Large
    private let footer: Footer

    public init(
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder small: () -> Small,
      @ViewBuilder medium: () -> Medium,
      @ViewBuilder large: () -> Large,
      @ViewBuilder footer: () -> Footer
    ) {
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.small = small()
      self.medium = medium()
      self.large = large()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          GeometryReader { proxy in
            ZStack {
              large
                .frame(width: proxy.size.width * 0.75, height: proxy.size.height * 0.62)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.visualShadowRadius,
                  shadowOpacity: 0.25
                )
                .offset(x: -proxy.size.width * 0.07, y: proxy.size.height * 0.12)

              medium
                .frame(width: proxy.size.width * 0.76, height: proxy.size.height * 0.29)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.smallCornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.72,
                  shadowOpacity: 0.21
                )
                .rotationEffect(.degrees(-3))
                .offset(x: proxy.size.width * 0.08, y: -proxy.size.height * 0.29)

              small
                .frame(width: proxy.size.width * 0.34, height: proxy.size.width * 0.34)
                .screenshotTemplateSurface(
                  cornerRadius: metrics.smallCornerRadius,
                  shadowRadius: metrics.visualShadowRadius * 0.72,
                  shadowOpacity: 0.22
                )
                .rotationEffect(.degrees(4))
                .offset(x: proxy.size.width * 0.30, y: proxy.size.height * 0.24)
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

  public struct ComparisonGridScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    First: View,
    Second: View,
    Third: View,
    Fourth: View,
    Footer: View
  >: View {
    private let labels: [String]
    private let labelColor: Color
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let first: First
    private let second: Second
    private let third: Third
    private let fourth: Fourth
    private let footer: Footer

    public init(
      labels: [String],
      labelColor: Color = .primary,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder first: () -> First,
      @ViewBuilder second: () -> Second,
      @ViewBuilder third: () -> Third,
      @ViewBuilder fourth: () -> Fourth,
      @ViewBuilder footer: () -> Footer
    ) {
      self.labels = Array((labels + ["One", "Two", "Three", "Four"]).prefix(4))
      self.labelColor = labelColor
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.first = first()
      self.second = second()
      self.third = third()
      self.fourth = fourth()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          Grid(horizontalSpacing: metrics.minorSpacing, verticalSpacing: metrics.minorSpacing) {
            GridRow {
              gridItem(label: labels[0], content: first, metrics: metrics)
              gridItem(label: labels[1], content: second, metrics: metrics)
            }
            GridRow {
              gridItem(label: labels[2], content: third, metrics: metrics)
              gridItem(label: labels[3], content: fourth, metrics: metrics)
            }
          }
          .frame(maxHeight: .infinity)

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }

    private func gridItem<Content: View>(
      label: String,
      content: Content,
      metrics: ScreenshotTemplateMetrics
    ) -> some View {
      VStack(alignment: .leading, spacing: 7) {
        content
          .screenshotTemplateFill()
          .screenshotTemplateSurface(
            cornerRadius: metrics.smallCornerRadius,
            shadowRadius: metrics.visualShadowRadius * 0.55,
            shadowOpacity: 0.17
          )

        Text(label)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(labelColor)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  public struct ContinuousCampaignScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View,
    Footer: View
  >: View {
    private let pageIndex: Int
    private let pageCount: Int
    private let accent: Color
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual
    private let footer: Footer

    public init(
      pageIndex: Int,
      pageCount: Int,
      accent: Color = .accentColor,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual,
      @ViewBuilder footer: () -> Footer
    ) {
      self.pageCount = max(pageCount, 1)
      self.pageIndex = min(max(pageIndex, 0), max(pageCount - 1, 0))
      self.accent = accent
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.visual = visual()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          HStack(alignment: .center) {
            brand
            Spacer(minLength: 12)
            ScreenshotPageIndicator(
              count: pageCount,
              selectedIndex: pageIndex,
              tint: accent
            )
          }

          message

          GeometryReader { proxy in
            let progress = pageCount <= 1
              ? 0.5
              : CGFloat(pageIndex) / CGFloat(pageCount - 1)
            let travel = proxy.size.width * 0.16

            visual
              .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.92)
              .screenshotTemplateSurface(
                cornerRadius: metrics.cornerRadius,
                shadowRadius: metrics.visualShadowRadius,
                shadowOpacity: 0.26
              )
              .offset(x: (progress - 0.5) * travel)
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
