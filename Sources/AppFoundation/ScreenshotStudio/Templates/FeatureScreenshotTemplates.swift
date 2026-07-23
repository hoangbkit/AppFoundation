#if canImport(SwiftUI)
  import SwiftUI

  public struct SplitFeatureScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View,
    Footer: View
  >: View {
    private let side: ScreenshotTemplateSplitSide
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual
    private let footer: Footer

    public init(
      side: ScreenshotTemplateSplitSide = .trailing,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual,
      @ViewBuilder footer: () -> Footer
    ) {
      self.side = side
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
          message

          GeometryReader { proxy in
            visual
              .frame(width: proxy.size.width * 0.88, height: proxy.size.height * 0.94)
              .screenshotTemplateSurface(
                cornerRadius: metrics.cornerRadius,
                shadowRadius: metrics.visualShadowRadius,
                shadowOpacity: 0.27
              )
              .rotationEffect(.degrees(side == .trailing ? -2.5 : 2.5))
              .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: side == .trailing ? .trailing : .leading
              )
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

  public struct BeforeAfterScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    Before: View,
    After: View,
    Footer: View
  >: View {
    private let beforeLabel: String
    private let afterLabel: String
    private let labelTint: Color
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let before: Before
    private let after: After
    private let footer: Footer

    public init(
      beforeLabel: String = "Before",
      afterLabel: String = "After",
      labelTint: Color = .accentColor,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder before: () -> Before,
      @ViewBuilder after: () -> After,
      @ViewBuilder footer: () -> Footer
    ) {
      self.beforeLabel = beforeLabel
      self.afterLabel = afterLabel
      self.labelTint = labelTint
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.before = before()
      self.after = after()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          HStack(spacing: metrics.minorSpacing) {
            comparisonColumn(
              label: beforeLabel,
              content: before,
              metrics: metrics
            )

            comparisonColumn(
              label: afterLabel,
              content: after,
              metrics: metrics
            )
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

    private func comparisonColumn<Content: View>(
      label: String,
      content: Content,
      metrics: ScreenshotTemplateMetrics
    ) -> some View {
      VStack(spacing: metrics.minorSpacing) {
        Text(label)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(labelTint)
          .padding(.horizontal, 11)
          .padding(.vertical, 7)
          .background(labelTint.opacity(0.13), in: Capsule())

        content
          .screenshotTemplateFill()
          .screenshotTemplateSurface(
            cornerRadius: metrics.smallCornerRadius,
            shadowRadius: metrics.visualShadowRadius * 0.72,
            shadowOpacity: 0.20
          )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  public struct FeatureStepsScreenshotTemplate<
    Background: View,
    Brand: View,
    Message: View,
    First: View,
    Second: View,
    Third: View,
    Footer: View
  >: View {
    private let firstTitle: String
    private let secondTitle: String
    private let thirdTitle: String
    private let accent: Color
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let first: First
    private let second: Second
    private let third: Third
    private let footer: Footer

    public init(
      firstTitle: String,
      secondTitle: String,
      thirdTitle: String,
      accent: Color = .accentColor,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder first: () -> First,
      @ViewBuilder second: () -> Second,
      @ViewBuilder third: () -> Third,
      @ViewBuilder footer: () -> Footer
    ) {
      self.firstTitle = firstTitle
      self.secondTitle = secondTitle
      self.thirdTitle = thirdTitle
      self.accent = accent
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.first = first()
      self.second = second()
      self.third = third()
      self.footer = footer()
    }

    public var body: some View {
      ScreenshotTemplateCanvas(background: background) { metrics in
        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
          message

          HStack(alignment: .top, spacing: metrics.minorSpacing) {
            stepColumn(index: 1, title: firstTitle, content: first, metrics: metrics)
            stepColumn(index: 2, title: secondTitle, content: second, metrics: metrics)
            stepColumn(index: 3, title: thirdTitle, content: third, metrics: metrics)
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

    private func stepColumn<Content: View>(
      index: Int,
      title: String,
      content: Content,
      metrics: ScreenshotTemplateMetrics
    ) -> some View {
      VStack(spacing: metrics.minorSpacing) {
        ZStack {
          Circle()
            .fill(accent)
          Text("\(index)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        }
        .frame(width: 27, height: 27)

        Text(title)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.75)

        content
          .screenshotTemplateFill()
          .screenshotTemplateSurface(
            cornerRadius: metrics.smallCornerRadius,
            shadowRadius: metrics.visualShadowRadius * 0.62,
            shadowOpacity: 0.19
          )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
#endif
